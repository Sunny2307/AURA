import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/friendship.dart';
import '../../auth/data/user_repository.dart';
import '../../friends/data/friendship_repository.dart';

/// Why a safety action failed, in terms a screen can write copy for.
enum SafetyProblem {
  /// You tried to block or report yourself.
  cannotActOnYourself,

  permissionDenied,
  network,
  unknown,
}

final class SafetyFailure implements Exception {
  const SafetyFailure(this.problem, {this.code});

  final SafetyProblem problem;
  final String? code;

  @override
  String toString() => 'SafetyFailure($problem, code: $code)';
}

/// Blocking and reporting.
///
/// These are **one** repository rather than two, which departs from the slice 9
/// plan on purpose. The security rules require a report and its matching block
/// to land in the same commit — nothing reviews the report queue yet, so the
/// block is the only thing that actually protects the reporter, and coupling
/// them in the rules is what stops the UI drifting into a report button that
/// quietly does nothing. Two repositories would mean one of them reaching into
/// the other's collection to assemble that batch, which is worse than admitting
/// they are one concern.
abstract interface class SafetyRepository {
  /// Blocks someone, and severs any friendship with them in the same commit.
  ///
  /// Both halves together, because a block that left the friendship standing
  /// would leave the blocked person on your friend list — visible, countable,
  /// and still there.
  Future<void> block({required String viewerUid, required String blockedUid});

  Future<void> unblock({
    required String viewerUid,
    required String blockedUid,
  });

  /// Files a report, blocks the reported user, and severs the friendship — all
  /// in one commit, because the rules will not accept the report without the
  /// block.
  Future<void> report({
    required String viewerUid,
    required String reportedUid,
    required String reason,
  });

  /// The uids you have blocked, newest first.
  Stream<List<String>> watchBlocked(String viewerUid);
}

final class FirestoreSafetyRepository implements SafetyRepository {
  FirestoreSafetyRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String blocksSubcollection = 'blocks';
  static const String reportsCollection = 'reports';

  static const String fieldCreatedAt = 'createdAt';
  static const String fieldReporterUid = 'reporterUid';
  static const String fieldReportedUid = 'reportedUid';
  static const String fieldReason = 'reason';

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> _blocksOf(String uid) {
    return _db
        .collection(FirestoreUserRepository.usersCollection)
        .doc(uid)
        .collection(blocksSubcollection);
  }

  @override
  Future<void> block({
    required String viewerUid,
    required String blockedUid,
  }) {
    return _guard(() async {
      if (viewerUid == blockedUid) {
        throw const SafetyFailure(SafetyProblem.cannotActOnYourself);
      }
      final batch = _db.batch();
      _addBlock(batch, viewerUid: viewerUid, blockedUid: blockedUid);
      await batch.commit();
    });
  }

  @override
  Future<void> unblock({
    required String viewerUid,
    required String blockedUid,
  }) {
    return _guard(() async {
      await _blocksOf(viewerUid).doc(blockedUid).delete();
    });
  }

  @override
  Future<void> report({
    required String viewerUid,
    required String reportedUid,
    required String reason,
  }) {
    return _guard(() async {
      if (viewerUid == reportedUid) {
        throw const SafetyFailure(SafetyProblem.cannotActOnYourself);
      }

      final batch = _db.batch();
      _addBlock(batch, viewerUid: viewerUid, blockedUid: reportedUid);
      // A fresh id rather than a derived one: the same person may legitimately
      // be reported more than once, by different people or for different
      // things, and each is its own record.
      batch.set(_db.collection(reportsCollection).doc(), {
        fieldReporterUid: viewerUid,
        fieldReportedUid: reportedUid,
        fieldReason: reason,
        fieldCreatedAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
    });
  }

  /// Writes the block document and removes the friendship, into [batch].
  ///
  /// Deleting a friendship that does not exist is a no-op in Firestore rather
  /// than an error, so there is no need to read first — which also means there
  /// is no window between checking and writing.
  void _addBlock(
    WriteBatch batch, {
    required String viewerUid,
    required String blockedUid,
  }) {
    batch.set(_blocksOf(viewerUid).doc(blockedUid), {
      fieldCreatedAt: FieldValue.serverTimestamp(),
    });
    batch.delete(
      _db
          .collection(FirestoreFriendshipRepository.friendshipsCollection)
          .doc(Friendship.pairIdFor(viewerUid, blockedUid)),
    );
  }

  @override
  Stream<List<String>> watchBlocked(String viewerUid) {
    return _blocksOf(viewerUid)
        .orderBy(fieldCreatedAt, descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc.id).toList(growable: false),
        );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SafetyFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw SafetyFailure(switch (error.code) {
        'permission-denied' => SafetyProblem.permissionDenied,
        'unavailable' || 'deadline-exceeded' => SafetyProblem.network,
        _ => SafetyProblem.unknown,
      }, code: error.code);
    }
  }
}
