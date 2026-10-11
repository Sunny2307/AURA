import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/friendship.dart';
import '../../auth/data/user_repository.dart';

/// Why a friendship operation failed, in terms a screen can write copy for.
enum FriendshipProblem {
  /// A friendship document already exists for this pair — pending or accepted.
  /// Expected and recoverable: the UI shows "requested" or "already friends"
  /// rather than an error.
  alreadyExists,

  /// The friendship was gone by the time the write landed. The other side
  /// cancelled, declined, or unfriended in between.
  noLongerExists,

  /// You tried to accept a request you sent yourself. The rules reject it; this
  /// case exists so the failure is named rather than surfacing as a bare
  /// permission error that looks like a bug.
  notYoursToAccept,

  cannotBefriendYourself,

  permissionDenied,
  network,
  unknown,
}

final class FriendshipFailure implements Exception {
  const FriendshipFailure(this.problem, {this.code});

  final FriendshipProblem problem;
  final String? code;

  @override
  String toString() => 'FriendshipFailure($problem, code: $code)';
}

/// Reads and writes `friendships/{pairId}`.
///
/// Every method here is scoped to one signed-in person. There is no
/// "friendships of arbitrary uid" read, because the security rules will not
/// serve one — the only list query they accept is
/// `members array-contains <you>`.
abstract interface class FriendshipRepository {
  /// Sends a friend request from [fromUid] to [toUid].
  Future<void> request({required String fromUid, required String toUid});

  /// Accepts a pending request. [viewerUid] must be the recipient.
  Future<void> accept({required String viewerUid, required String otherUid});

  /// Removes the friendship document.
  ///
  /// Decline, cancel and unfriend are deliberately the same call. They differ
  /// only in who is calling and what the status was, and modelling them apart
  /// would mean storing a `declined` state that nobody reads and that tells a
  /// sender they were rejected.
  Future<void> remove({required String viewerUid, required String otherUid});

  /// Accepted friendships, live. Newest first.
  Stream<List<Friendship>> watchFriends(String viewerUid);

  /// Pending friendships, live — both directions.
  ///
  /// One listener rather than two, split client-side on `requestedBy`. The
  /// incoming/outgoing distinction is a comparison the client can already make,
  /// and one listener over a handful of documents costs less than two.
  Stream<List<Friendship>> watchPending(String viewerUid);

  /// The friendship with one specific person, live. Null when there is none —
  /// which is the normal state, not an error.
  Stream<Friendship?> watchWith({
    required String viewerUid,
    required String otherUid,
  });
}

final class FirestoreFriendshipRepository implements FriendshipRepository {
  FirestoreFriendshipRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String friendshipsCollection = 'friendships';

  final FirebaseFirestore _db;

  @override
  Future<void> request({
    required String fromUid,
    required String toUid,
  }) {
    return _guard(() async {
      if (fromUid == toUid) {
        throw const FriendshipFailure(
          FriendshipProblem.cannotBefriendYourself,
        );
      }

      final members = [fromUid, toUid]..sort();
      final ref = _db
          .collection(friendshipsCollection)
          .doc(Friendship.pairIdFor(fromUid, toUid));

      // `set` with no merge would silently overwrite an existing friendship,
      // including an accepted one — a way to reset someone back to pending
      // without their knowledge. The rules forbid it, but relying on the backend
      // to catch a mistake the client should not make turns a logic error into a
      // confusing permission error. So: a transaction that checks first.
      await _db.runTransaction((transaction) async {
        final existing = await transaction.get(ref);
        if (existing.exists) {
          throw const FriendshipFailure(FriendshipProblem.alreadyExists);
        }

        transaction.set(ref, {
          Friendship.fieldMembers: members,
          Friendship.fieldRequestedBy: fromUid,
          Friendship.fieldStatus: FriendshipStatus.pending.wireValue,
          // The server's clock. The rules require this to equal `request.time`,
          // so a device with a wrong date cannot write at all — which is the
          // right failure direction for a value that orders a request list.
          Friendship.fieldCreatedAt: FieldValue.serverTimestamp(),
          Friendship.fieldRespondedAt: null,
        });
      });
    });
  }

  @override
  Future<void> accept({
    required String viewerUid,
    required String otherUid,
  }) {
    return _guard(() async {
      final ref = _db
          .collection(friendshipsCollection)
          .doc(Friendship.pairIdFor(viewerUid, otherUid));

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const FriendshipFailure(FriendshipProblem.noLongerExists);
        }

        // Named here as well as enforced in the rules. Without this the caller
        // gets `permission-denied`, which is indistinguishable from a rules bug
        // and impossible to write honest copy for.
        if (data[Friendship.fieldRequestedBy] == viewerUid) {
          throw const FriendshipFailure(FriendshipProblem.notYoursToAccept);
        }

        transaction.update(ref, {
          Friendship.fieldStatus: FriendshipStatus.accepted.wireValue,
          Friendship.fieldRespondedAt: FieldValue.serverTimestamp(),
        });
      });
    });
  }

  @override
  Future<void> remove({
    required String viewerUid,
    required String otherUid,
  }) {
    return _guard(() async {
      await _db
          .collection(friendshipsCollection)
          .doc(Friendship.pairIdFor(viewerUid, otherUid))
          .delete();
    });
  }

  @override
  Stream<List<Friendship>> watchFriends(String viewerUid) {
    return _watchByStatus(viewerUid, FriendshipStatus.accepted);
  }

  @override
  Stream<List<Friendship>> watchPending(String viewerUid) {
    return _watchByStatus(viewerUid, FriendshipStatus.pending);
  }

  @override
  Stream<Friendship?> watchWith({
    required String viewerUid,
    required String otherUid,
  }) {
    return _db
        .collection(friendshipsCollection)
        .doc(Friendship.pairIdFor(viewerUid, otherUid))
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          return Friendship.fromMap(
            snapshot.id,
            data,
            parseTimestamp: _parseTimestamp,
          );
        });
  }

  /// The one query shape the security rules accept: scoped to the caller by
  /// `array-contains`, then filtered by status. The composite index backing it
  /// is declared in `firestore.indexes.json`.
  Stream<List<Friendship>> _watchByStatus(
    String viewerUid,
    FriendshipStatus status,
  ) {
    return _db
        .collection(friendshipsCollection)
        .where(Friendship.fieldMembers, arrayContains: viewerUid)
        .where(Friendship.fieldStatus, isEqualTo: status.wireValue)
        .orderBy(Friendship.fieldCreatedAt, descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Friendship.fromMap(
                  doc.id,
                  doc.data(),
                  parseTimestamp: _parseTimestamp,
                ),
              )
              .toList(growable: false),
        );
  }

  /// A locally-written document arrives first with its server timestamps still
  /// null, then again a moment later with the real values. Crashing on the first
  /// frame would make every freshly sent request throw on a screen that is about
  /// to be correct.
  static DateTime _parseTimestamp(Object? value) {
    return switch (value) {
      final Timestamp v => v.toDate(),
      final DateTime v => v,
      final int v => DateTime.fromMillisecondsSinceEpoch(v),
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FriendshipFailure {
      rethrow;
    } on AccountFailure catch (error) {
      // Surfaced by a shared helper; translated rather than leaked, so callers
      // only ever handle one error type.
      throw FriendshipFailure(switch (error.problem) {
        AccountProblem.permissionDenied => FriendshipProblem.permissionDenied,
        AccountProblem.network => FriendshipProblem.network,
        _ => FriendshipProblem.unknown,
      }, code: error.code);
    } on FirebaseException catch (error) {
      throw FriendshipFailure(switch (error.code) {
        'permission-denied' => FriendshipProblem.permissionDenied,
        'already-exists' => FriendshipProblem.alreadyExists,
        'not-found' => FriendshipProblem.noLongerExists,
        'unavailable' || 'deadline-exceeded' => FriendshipProblem.network,
        _ => FriendshipProblem.unknown,
      }, code: error.code);
    }
  }
}
