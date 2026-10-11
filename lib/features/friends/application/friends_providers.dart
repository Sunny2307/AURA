import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/friendship.dart';
import '../../../core/models/public_profile.dart';
import '../../../core/validation/username_rules.dart';
import '../../auth/application/auth_providers.dart';
import '../data/friendship_repository.dart';
import '../data/public_profile_repository.dart';

/// Overridden with fakes in tests — the reason both are interfaces.
final publicProfileRepositoryProvider = Provider<PublicProfileRepository>((
  ref,
) {
  return FirestorePublicProfileRepository();
});

final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  return FirestoreFriendshipRepository();
});

/// Accepted friendships for the signed-in user, live.
///
/// Emits an empty list rather than erroring when signed out. A signed-out user
/// has no friends in the literal sense the screen needs, and treating it as an
/// error would make every sign-out flash a failure state on the way to
/// onboarding.
final friendshipsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendshipRepositoryProvider).watchFriends(uid);
});

/// Pending friendships in both directions, live.
final pendingFriendshipsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendshipRepositoryProvider).watchPending(uid);
});

/// Requests waiting on *you*. Split from [pendingFriendshipsProvider] here
/// rather than with a second Firestore listener — the distinction is
/// `requestedBy != me`, which is a comparison the client can already make.
final incomingRequestsProvider = Provider<AsyncValue<List<Friendship>>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return ref
      .watch(pendingFriendshipsProvider)
      .whenData(
        (all) => uid == null
            ? const <Friendship>[]
            : all.where((f) => f.isIncomingFor(uid)).toList(growable: false),
      );
});

/// Requests you sent that nobody has answered yet.
final outgoingRequestsProvider = Provider<AsyncValue<List<Friendship>>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return ref
      .watch(pendingFriendshipsProvider)
      .whenData(
        (all) => uid == null
            ? const <Friendship>[]
            : all.where((f) => f.isOutgoingFor(uid)).toList(growable: false),
      );
});

/// How many friends you have.
///
/// Derived, not stored. `users/{uid}` used to carry a `friendCount` field that
/// only a Cloud Function could legally move — which, on the Spark plan, meant
/// nothing ever moved it and the value was permanently 0. Counting the list
/// cannot drift and cannot be inflated by a tampered client.
final friendCountProvider = Provider<int>((ref) {
  return ref.watch(friendshipsProvider).value?.length ?? 0;
});

/// The public profile behind a uid, live. Keyed by uid so each friend row
/// subscribes to its own document and one friend changing their photo does not
/// rebuild the whole list.
final publicProfileProvider = StreamProvider.family<PublicProfile?, String>((
  ref,
  uid,
) {
  return ref.watch(publicProfileRepositoryProvider).watch(uid);
});

/// One person, looked up by handle. Backs the invite-link screen.
///
/// The `await` on auth is load-bearing rather than defensive. This provider's
/// whole reason to exist is a cold start from a shared link: the app launches,
/// the auth stream has not emitted yet, and a lookup fired at that instant is a
/// signed-out read, which `publicProfiles` denies. Awaiting the first emission
/// turns that race into a spinner that resolves, instead of a "nobody has that
/// handle" on a handle that exists.
final profileByUsernameProvider =
    FutureProvider.family<PublicProfile?, String>((ref, username) async {
      await ref.watch(authStateProvider.future);

      // A handle that cannot be valid never reaches Firestore. Links get
      // truncated and mistyped constantly, and `usernames/{name}` is readable
      // without auth by design — so every avoidable read of it is one fewer
      // probe of that collection.
      final check = UsernameRules.check(username);
      if (check is! UsernameValid) return null;

      return ref
          .read(publicProfileRepositoryProvider)
          .findByUsername(check.normalised);
    });

/// The friendship between you and one other person, live. Drives the button
/// state on a profile: add, requested, accept, or already friends.
final friendshipWithProvider = StreamProvider.family<Friendship?, String>((
  ref,
  otherUid,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(friendshipRepositoryProvider)
      .watchWith(viewerUid: uid, otherUid: otherUid);
});
