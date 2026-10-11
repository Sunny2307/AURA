import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Who is signed in, as far as the app is concerned.
///
/// Deliberately not `firebase_auth`'s [User]. Two reasons:
///
/// 1. The rest of the app should not import `firebase_auth` to know a uid. That
///    keeps the swap to a fake in tests to one override rather than a mock of a
///    third-party class with forty members.
/// 2. [User] carries a lot the app must not act on — `displayName`, `photoURL`,
///    `phoneNumber` — which are Firebase's copies, not ours. Aura's username and
///    photo live in `users/{uid}`, and reading them from the auth object would
///    quietly give two sources of truth for the same fact.
final class AuthUser {
  const AuthUser({required this.uid, required this.email});

  final String uid;

  /// Nullable because it is not guaranteed by the type — an anonymous or
  /// phone-based account has none. With email/password sign-in it is always
  /// present, but hard-coding that assumption would break the day phone login
  /// arrives.
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}

/// Why a sign-up or sign-in failed, in terms the UI can write copy for.
///
/// A closed set rather than Firebase's string codes, so a screen cannot
/// accidentally show a raw `firebase_auth/...` code to a user, and so an
/// unhandled code becomes [unknown] rather than a crash.
enum AuthProblem {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  wrongPassword,
  userNotFound,
  userDisabled,
  tooManyRequests,

  /// The Email/Password provider is switched off in the Firebase console.
  /// Its own case because it is a *configuration* fault, not a user mistake —
  /// telling someone "wrong password" when the provider is disabled would send
  /// them round in circles.
  operationNotAllowed,

  network,
  unknown,
}

/// Thrown by [AuthRepository]. Carries the [AuthProblem] plus the original code
/// for logs, never for display.
final class AuthFailure implements Exception {
  const AuthFailure(this.problem, {this.code});

  final AuthProblem problem;
  final String? code;

  @override
  String toString() => 'AuthFailure($problem, code: $code)';
}

/// The app's view of authentication.
///
/// An interface, not a class wrapping Firebase directly, so widget tests can
/// drive the signup flow — including its failure paths, which are the ones worth
/// testing — without a network or an emulator.
abstract interface class AuthRepository {
  /// Emits on every sign-in, sign-out, and token refresh, starting with the
  /// current state.
  ///
  /// A stream rather than a one-off getter because auth state changes without the
  /// app asking: a token can be revoked, an account disabled, a password changed
  /// on another device. Anything that reads the current user from a snapshot
  /// taken at startup will eventually be wrong.
  Stream<AuthUser?> authStateChanges();

  /// The user right now, or null. For the rare synchronous case — mostly
  /// deciding what to do inside a repository call already in flight.
  AuthUser? get currentUser;

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Deletes the auth account. Used to unwind a half-finished signup: if the
  /// Firestore write fails after the account was created, leaving the account
  /// behind means the email is taken by a user who does not exist and cannot be
  /// signed up again.
  Future<void> deleteCurrentUser();
}

/// The real implementation.
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        // Trimmed, because a trailing space from an autofill or a paste is the
        // single most common way a valid email gets rejected.
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential.user);
    });
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential.user);
    });
  }

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> deleteCurrentUser() {
    return _guard(() async {
      final user = _auth.currentUser;
      // Not an error: nothing to delete is the desired end state either way.
      if (user == null) return;
      await user.delete();
    });
  }

  AuthUser? _toAuthUser(User? user) =>
      user == null ? null : AuthUser(uid: user.uid, email: user.email);

  AuthUser _requireUser(User? user) {
    // Firebase types `credential.user` as nullable, but a successful create or
    // sign-in always has one. Treating null as an unknown failure rather than
    // force-unwrapping means the impossible case surfaces as a handled error
    // instead of a null-check crash in release.
    if (user == null) throw const AuthFailure(AuthProblem.unknown);
    return AuthUser(uid: user.uid, email: user.email);
  }

  /// Runs [action], translating Firebase's exceptions into [AuthFailure].
  ///
  /// Everything goes through here so no call site can leak a raw
  /// [FirebaseAuthException] into the UI layer.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_problemFor(error.code), code: error.code);
    }
  }

  AuthProblem _problemFor(String code) {
    return switch (code) {
      'email-already-in-use' => AuthProblem.emailAlreadyInUse,
      'invalid-email' => AuthProblem.invalidEmail,
      'weak-password' => AuthProblem.weakPassword,
      // Modern Firebase projects return `invalid-credential` for both a wrong
      // password and an unknown email — deliberately, so the API cannot be used
      // to enumerate which addresses have accounts. Mapped to wrongPassword
      // because that is the actionable reading for someone who does have an
      // account; the copy for it must stay vague for the same reason.
      'wrong-password' || 'invalid-credential' => AuthProblem.wrongPassword,
      'user-not-found' => AuthProblem.userNotFound,
      'user-disabled' => AuthProblem.userDisabled,
      'too-many-requests' => AuthProblem.tooManyRequests,
      'operation-not-allowed' => AuthProblem.operationNotAllowed,
      'network-request-failed' => AuthProblem.network,
      _ => AuthProblem.unknown,
    };
  }
}
