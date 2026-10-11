import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';

/// The auth repository. Overridden in tests with a fake — that override is the
/// entire reason [AuthRepository] is an interface.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository();
});

/// Who is signed in, live.
///
/// A [StreamProvider] rather than a stored value, because auth state changes
/// without the app asking — a revoked token, a disabled account, a password
/// changed on another device. Anything holding a snapshot from startup goes
/// stale silently, which for an auth check means showing a signed-in UI to
/// someone who is not.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The signed-in user's `users/{uid}` document, live. Null when signed out, and
/// also null for a signed-in user who has not finished signup — see
/// [SignupStatus] for why those two need telling apart.
final currentUserProvider = StreamProvider<AuraUser?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(auth.uid);
});

/// Where a person stands, for the splash screen and the route guards.
enum SignupStatus {
  /// Still resolving. The splash screen holds here rather than guessing.
  resolving,

  /// Auth or the profile read **failed** — a revoked token, a disabled account,
  /// a denied read, no network.
  ///
  /// Split out from [resolving] after the slice 2 security review. They used to
  /// share one `unknown` case, which meant a *permanent* failure was
  /// indistinguishable from "give it another moment" — and the route guard,
  /// quite reasonably, lets "another moment" through. That is a guard that fails
  /// open on error. Separating them lets each caller choose: the splash screen
  /// waits on [resolving] and gives up immediately on [failed], while the guards
  /// treat [failed] as signed out.
  failed,

  signedOut,

  /// Signed in with an auth account but no `users/{uid}` document.
  ///
  /// This is a real state, not a bug: creating the auth account and writing the
  /// profile are two operations, and an app killed between them lands here. It
  /// must route back into signup to finish, *not* to the home screen — a home
  /// screen with no user document would render an empty profile and a score of
  /// nothing.
  needsProfile,

  ready,
}

final signupStatusProvider = Provider<SignupStatus>((ref) {
  final auth = ref.watch(authStateProvider);
  // A stream that has not emitted yet is genuinely unresolved. Treating that as
  // signed-out would flash onboarding at a returning user on every cold start.
  if (auth.isLoading) return SignupStatus.resolving;
  if (auth.hasError) return SignupStatus.failed;
  if (auth.value == null) return SignupStatus.signedOut;

  final user = ref.watch(currentUserProvider);
  if (user.isLoading) return SignupStatus.resolving;
  // An error reading the profile is still not "no profile" — sending someone
  // back through signup because their network dropped would try to re-claim a
  // handle they already own. But it is not "keep waiting" either, so it is
  // [SignupStatus.failed] and each caller decides.
  if (user.hasError) return SignupStatus.failed;
  return user.value == null
      ? SignupStatus.needsProfile
      : SignupStatus.ready;
});
