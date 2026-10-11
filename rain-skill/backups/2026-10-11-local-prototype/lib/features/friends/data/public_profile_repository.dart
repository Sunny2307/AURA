import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/public_profile.dart';
import '../../auth/data/user_repository.dart';

/// Reads `publicProfiles/{uid}` — the handle-and-photo view of someone you are
/// not friends with yet.
///
/// Lookup is by **exact handle only**. There is no partial match, no "people you
/// may know", no browsing. That is a product decision carried over from the
/// slice 2 brainstorm, and it is also what the security rules permit: `list` on
/// both `usernames` and `publicProfiles` is denied, so nothing here can
/// enumerate the user base even if a future screen tried to.
abstract interface class PublicProfileRepository {
  /// The profile behind a handle, or null if nobody holds it.
  ///
  /// Two reads, not one: `usernames/{name}` gives the uid, then
  /// `publicProfiles/{uid}` gives the profile. A single query over
  /// `publicProfiles` filtered by username would be one round trip, but it would
  /// require `list` access to the collection, which is exactly the enumeration
  /// hole the rules close.
  Future<PublicProfile?> findByUsername(String username);

  Future<PublicProfile?> fetch(String uid);

  Stream<PublicProfile?> watch(String uid);
}

final class FirestorePublicProfileRepository
    implements PublicProfileRepository {
  FirestorePublicProfileRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String publicProfilesCollection = 'publicProfiles';

  final FirebaseFirestore _db;

  @override
  Future<PublicProfile?> findByUsername(String username) {
    return _guard(() async {
      final claim = await _db
          .collection(FirestoreUserRepository.usernamesCollection)
          .doc(username)
          .get();

      final uid = claim.data()?[FirestoreUserRepository.usernameOwnerField];
      if (uid is! String || uid.isEmpty) return null;

      // A claimed handle whose public profile is missing is not an error worth
      // throwing: the rules make the pair atomic, so this can only be a document
      // read mid-signup. Treating it as "not found" means the searcher sees
      // "no such user" rather than a crash, and a retry a second later works.
      return fetch(uid);
    });
  }

  @override
  Future<PublicProfile?> fetch(String uid) {
    return _guard(() async {
      final snapshot = await _db
          .collection(publicProfilesCollection)
          .doc(uid)
          .get();
      return _toProfileOrNull(snapshot);
    });
  }

  @override
  Stream<PublicProfile?> watch(String uid) {
    return _db
        .collection(publicProfilesCollection)
        .doc(uid)
        .snapshots()
        .map(_toProfileOrNull);
  }

  PublicProfile? _toProfileOrNull(
    DocumentSnapshot<Map<String, Object?>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return PublicProfile.fromMap(snapshot.id, data);
  }

  /// Same failure vocabulary as [UserRepository], so a screen that already knows
  /// how to render an [AccountFailure] does not need a second error type.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AccountFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AccountFailure(switch (error.code) {
        'permission-denied' => AccountProblem.permissionDenied,
        'unavailable' || 'deadline-exceeded' => AccountProblem.network,
        _ => AccountProblem.unknown,
      }, code: error.code);
    }
  }
}
