import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/friendship.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/user_repository.dart';
import '../../friends/data/friendship_repository.dart';
import '../../send/data/aura_api.dart';
import 'safety_repository.dart';

/// Deletes an account, permanently.
///
/// ### What goes, and what deliberately does not
///
/// Goes: every friendship, your own block list, `publicProfiles/{uid}`,
/// `users/{uid}`, and finally the Firebase Auth account.
///
/// Stays: `usernames/{name}`. The handle is never reissued. Freeing it would
/// let someone squat a churned friend's name the moment they left, and every
/// old mention of `@sam` would silently start pointing at a different person.
/// The claim document is left holding a uid that no longer resolves — a
/// tombstone, which is exactly what it is for. The deletion copy says so.
///
/// Also stays: blocks that *other* people hold against this uid. Those are
/// their documents, owner-writable only, and someone who blocked you should not
/// have that undone by your leaving.
///
/// ### Why the order is what it is
///
/// Friendships first, then the profile pair, then auth. The auth account is
/// last because deleting it first would leave a signed-out caller holding
/// Firestore documents only *they* were allowed to remove — unreachable
/// forever. Failing partway through this order leaves someone signed in with a
/// recoverable account, which is the right direction to fail in.
///
/// On the Spark plan the client removes its rules-authorized documents after
/// the Node.js API purges aura records it could not remove itself.
abstract interface class AccountDeletionService {
  /// Removes everything personal and then the sign-in itself.
  Future<void> deleteAccount(String uid);
}

final class FirestoreAccountDeletionService implements AccountDeletionService {
  FirestoreAccountDeletionService(this._auth, this._auraApi, {FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Firestore caps a batch at 500 writes. Chunked well under it so the final
  /// batch always has room for the two profile documents.
  static const int _batchLimit = 400;

  final AuthRepository _auth;
  final AuraApi _auraApi;
  final FirebaseFirestore _db;

  @override
  Future<void> deleteAccount(String uid) async {
    try {
      // The privileged server first stops new sends and removes records in
      // other users' feeds, which this client is not allowed to delete.
      await _auraApi.purgeForDeletion();
      await _deleteFriendships(uid);
      await _deleteOwnBlocks(uid);
      await _deleteProfilePair(uid);
      // A second sweep, and it is not belt-and-braces.
      //
      // The first sweep works from a `.get()` snapshot, and three round trips
      // pass before the public profile is gone. Throughout that window
      // `targetExists()` still passes, so somebody watching can land a fresh
      // friend request against an account that is mid-deletion — leaving a
      // document naming a uid with no profile behind it, and making the
      // deletion screen's "every friendship is removed" quietly untrue.
      //
      // This pass is terminal rather than another race: by now the public
      // profile is gone, so no new friendship can be created at all.
      await _deleteFriendships(uid);
      // Last. See the class comment.
      await _auth.deleteCurrentUser();
    } on AuraApiFailure catch (error) {
      if (error.code == 'RECENT_LOGIN_REQUIRED') {
        throw const SafetyFailure(SafetyProblem.unknown, code: 'recent-login-required');
      }
      throw const SafetyFailure(SafetyProblem.network);
    } on SafetyFailure {
      rethrow;
    } on AuthFailure catch (error) {
      // The Firestore side already succeeded. Surfaced rather than swallowed:
      // the account documents are gone but the credential is not, and the user
      // needs to know to try again rather than assume they are done.
      throw SafetyFailure(SafetyProblem.unknown, code: error.code);
    } on FirebaseException catch (error) {
      throw SafetyFailure(switch (error.code) {
        'permission-denied' => SafetyProblem.permissionDenied,
        'unavailable' || 'deadline-exceeded' => SafetyProblem.network,
        _ => SafetyProblem.unknown,
      }, code: error.code);
    }
  }

  /// Both directions at once: the query is `members array-contains me`, which
  /// is the only shape the rules accept, and it returns friendships regardless
  /// of who requested them or whether they were accepted.
  Future<void> _deleteFriendships(String uid) async {
    final snapshot = await _db
        .collection(FirestoreFriendshipRepository.friendshipsCollection)
        .where(Friendship.fieldMembers, arrayContains: uid)
        .get();

    await _deleteInChunks(snapshot.docs.map((doc) => doc.reference));
  }

  /// Subcollections are **not** removed when their parent document is deleted
  /// in Firestore — a detail that would otherwise leave this list behind as
  /// unreachable garbage under a uid nobody owns any more.
  Future<void> _deleteOwnBlocks(String uid) async {
    final snapshot = await _db
        .collection(FirestoreUserRepository.usersCollection)
        .doc(uid)
        .collection(FirestoreSafetyRepository.blocksSubcollection)
        .get();

    await _deleteInChunks(snapshot.docs.map((doc) => doc.reference));
  }

  /// The two halves of an identity, in one commit. The rules require it: each
  /// document's delete rule asserts the other is absent afterwards, so neither
  /// can be removed on its own and a half-deleted account cannot exist.
  Future<void> _deleteProfilePair(String uid) async {
    final batch = _db.batch();
    batch.delete(
      _db.collection(FirestoreUserRepository.usersCollection).doc(uid),
    );
    batch.delete(
      _db
          .collection(FirestoreUserRepository.publicProfilesCollection)
          .doc(uid),
    );
    await batch.commit();
  }

  Future<void> _deleteInChunks(Iterable<DocumentReference> refs) async {
    final all = refs.toList(growable: false);
    for (var start = 0; start < all.length; start += _batchLimit) {
      final end = (start + _batchLimit).clamp(0, all.length);
      final batch = _db.batch();
      for (final ref in all.sublist(start, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
