import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/models/public_profile.dart';

/// Why a Firestore-side account operation failed.
enum AccountProblem {
  /// Someone else holds the handle. Expected and recoverable — the UI offers
  /// alternates rather than treating it as an error.
  usernameTaken,

  /// This uid already has a `users/{uid}` document. Means signup ran twice.
  accountAlreadyExists,

  permissionDenied,
  network,
  unknown,
}

final class AccountFailure implements Exception {
  const AccountFailure(this.problem, {this.code});

  final AccountProblem problem;
  final String? code;

  @override
  String toString() => 'AccountFailure($problem, code: $code)';
}

/// Reads and writes `users/{uid}` and `usernames/{username}`.
abstract interface class UserRepository {
  /// Whether a *well-formed* handle is free.
  ///
  /// Shape is not checked here — [UsernameRules.check] does that offline and
  /// instantly. This is the one cheap document read that shape checking cannot
  /// answer, and callers should only reach it once a name already passes.
  Future<bool> isUsernameAvailable(String username);

  /// Claims the handle and creates the account, atomically.
  Future<AuraUser> createAccount({
    required String uid,
    required String username,
    required int birthYear,
    required bool isMinor,
  });

  /// The live user document. Null while it does not exist yet — which is a real
  /// state, not an error: between creating an auth account and finishing signup,
  /// a signed-in user genuinely has no profile.
  Stream<AuraUser?> watchUser(String uid);

  Future<AuraUser?> fetchUser(String uid);

  /// Saves the privacy settings.
  ///
  /// Added in slice 9. The rules have allowed this write since slice 1 — the
  /// update rule's writable set is `['photoUrl', 'privacy']` — but no client
  /// method existed, so the settings screen had nothing to call and the fields
  /// could only ever hold their signup defaults.
  ///
  /// A minor cannot switch leaderboards on, and that is enforced server-side
  /// against the *stored* `isMinor` rather than anything sent with the write.
  /// The settings screen locks the control too, but the rule is what makes it
  /// true.
  Future<void> updatePrivacy({
    required String uid,
    required AuraPrivacy privacy,
  });
}

final class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String usersCollection = 'users';
  static const String usernamesCollection = 'usernames';
  static const String publicProfilesCollection = 'publicProfiles';

  /// The only field in a `usernames/{name}` document. The rules reject anything
  /// else, so this name is load-bearing rather than decorative.
  static const String usernameOwnerField = 'uid';

  final FirebaseFirestore _db;

  @override
  Future<bool> isUsernameAvailable(String username) {
    return _guard(() async {
      final snapshot = await _db
          .collection(usernamesCollection)
          .doc(username)
          .get();
      return !snapshot.exists;
    });
  }

  /// Claims `usernames/{username}`, writes `users/{uid}`, and publishes
  /// `publicProfiles/{uid}` — all in one transaction.
  ///
  /// Slice 2 added the third document. It is in here rather than written
  /// afterwards because the security rules make all three mutually required: a
  /// user document without a matching public profile is rejected, and so is a
  /// public profile without a matching user. That is what stops someone
  /// publishing a discovery profile under a handle they do not own.
  ///
  /// The transaction is the point of this method. Two separate writes have two
  /// bad orderings and no good one:
  ///
  /// * Claim first, then create the user — a crash in between leaves a handle
  ///   held by an account that does not exist. Nobody can ever take that name,
  ///   and the user retries into "username taken" on the handle they just chose.
  /// * Create the user first, then claim — two people signing up at the same
  ///   moment both pass the availability check and both create accounts, and the
  ///   loser ends up with a profile whose handle points at someone else.
  ///
  /// Inside a transaction, the read of the username document is part of the
  /// commit: if another signup claims it in the meantime, Firestore retries this
  /// callback, the read now finds the document, and we throw [usernameTaken]
  /// honestly. That is why the existence check happens *in here* and not by
  /// calling [isUsernameAvailable] first — that earlier check is for live UI
  /// feedback, and treating it as authoritative would be exactly the race above.
  @override
  Future<AuraUser> createAccount({
    required String uid,
    required String username,
    required int birthYear,
    required bool isMinor,
  }) {
    return _guard(() async {
      final userRef = _db.collection(usersCollection).doc(uid);
      final usernameRef = _db.collection(usernamesCollection).doc(username);
      final publicRef = _db.collection(publicProfilesCollection).doc(uid);

      final user = AuraUser.newAccount(
        uid: uid,
        username: username,
        birthYear: birthYear,
        isMinor: isMinor,
        // Overwritten below by the server timestamp. Present only because the
        // model requires a value; nothing reads this one.
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      await _db.runTransaction((transaction) async {
        final claim = await transaction.get(usernameRef);
        if (claim.exists) {
          // Not the same person re-running signup — the rules make a claim
          // permanent, so an existing document means someone holds it. Even if
          // that someone is this uid, the account below would then already exist.
          throw const AccountFailure(AccountProblem.usernameTaken);
        }

        final existing = await transaction.get(userRef);
        if (existing.exists) {
          throw const AccountFailure(AccountProblem.accountAlreadyExists);
        }

        transaction.set(usernameRef, {usernameOwnerField: uid});
        transaction.set(
          publicRef,
          PublicProfile(
            uid: uid,
            username: username,
            photoUrl: user.photoUrl,
          ).toCreateMap(),
        );
        transaction.set(userRef, {
          ...user.toCreateMap(),
          // The server's clock, not the device's. A phone with a wrong date
          // would otherwise order itself incorrectly forever, and the security
          // rules require this field to equal `request.time`.
          AuraUser.fieldCreatedAt: FieldValue.serverTimestamp(),
        });
      });

      // Read back rather than returning the local object, so the caller gets the
      // resolved server timestamp instead of the epoch placeholder above.
      final created = await fetchUser(uid);
      if (created != null) return created;

      // A successful commit whose document cannot be read back. Should not
      // happen; surfaced rather than papered over with the local copy, because
      // silently returning a user with a 1970 createdAt would be worse.
      throw const AccountFailure(AccountProblem.unknown);
    });
  }

  @override
  Stream<AuraUser?> watchUser(String uid) {
    return _db
        .collection(usersCollection)
        .doc(uid)
        .snapshots()
        .map(_toUserOrNull);
  }

  @override
  Future<AuraUser?> fetchUser(String uid) {
    return _guard(() async {
      final snapshot = await _db.collection(usersCollection).doc(uid).get();
      return _toUserOrNull(snapshot);
    });
  }

  @override
  Future<void> updatePrivacy({
    required String uid,
    required AuraPrivacy privacy,
  }) {
    return _guard(() async {
      // A narrow update rather than a set. The rules reject any write touching
      // keys outside `['photoUrl', 'privacy']`, so sending the whole document
      // would be refused wholesale — see the note on [AuraUser] about why the
      // model has no general `toMap`.
      await _db.collection(usersCollection).doc(uid).update({
        AuraUser.fieldPrivacy: privacy.toMap(),
      });
    });
  }

  AuraUser? _toUserOrNull(DocumentSnapshot<Map<String, Object?>> snapshot) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return AuraUser.fromMap(snapshot.id, data, parseTimestamp: _parseTimestamp);
  }

  /// Firestore hands back a [Timestamp], but not always.
  ///
  /// With `snapshots()` a document written locally arrives first with
  /// `createdAt: null` — the server timestamp has not resolved yet — and again a
  /// moment later with the real value. Crashing on the first of those two frames
  /// would make every fresh signup throw on a screen that is about to be correct.
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
    } on AccountFailure {
      // Already ours — thrown from inside the transaction callback. Rethrown
      // unchanged so it does not get flattened into `unknown` below.
      rethrow;
    } on FirebaseException catch (error) {
      throw AccountFailure(switch (error.code) {
        // What a client sees when it tries to claim a taken handle without a
        // transaction, or when the rules reject the write for any other reason.
        // Mapped honestly to permissionDenied rather than guessed at as
        // "taken" — a rules bug and a taken name must not look the same.
        'permission-denied' => AccountProblem.permissionDenied,
        'already-exists' => AccountProblem.accountAlreadyExists,
        'unavailable' || 'deadline-exceeded' => AccountProblem.network,
        _ => AccountProblem.unknown,
      }, code: error.code);
    }
  }
}
