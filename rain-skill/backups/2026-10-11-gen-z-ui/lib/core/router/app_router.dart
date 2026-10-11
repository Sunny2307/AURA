import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import 'aura_routes.dart';
import '../../features/dev/design_check_screen.dart';
import '../../features/friends/presentation/add_friend_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/friends/presentation/profile_preview_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/signup_flow_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/settings/presentation/blocked_list_screen.dart';
import '../../features/settings/presentation/delete_account_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/send/presentation/send_aura_screen.dart';
import '../../features/profile/presentation/photo_step.dart';
import '../../prototype/local_photo_step.dart';
import '../../prototype/prototype_runtime.dart';

/// Re-exported so every `import 'core/router/app_router.dart'` in the app keeps
/// resolving [AuraRoutes] unchanged after the split.
export 'aura_routes.dart';

/// Per-route guard for the screens that genuinely need a finished account.
///
/// [SignupStatus.resolving] is allowed through, and that is deliberate: on a
/// cold start from an invite link the auth stream has not emitted yet, and
/// redirecting away at that moment would throw the link away and land the user
/// on home with no idea why they opened the app. Every screen behind this guard
/// holds a loading state until auth settles, and Firestore denies all of their
/// reads in the meantime, so nothing is exposed by waiting.
///
/// [SignupStatus.failed] is **not** allowed through. Those used to be the same
/// `unknown` case, which meant a revoked token or a disabled account read as
/// "give it a moment" and sailed past the guard — a guard that fails open on
/// error. See [SignupStatus] for the split.
String? _requireAccount(BuildContext context, GoRouterState state) {
  return switch (ProviderScope.containerOf(
    context,
    listen: false,
  ).read(signupStatusProvider)) {
    SignupStatus.ready || SignupStatus.resolving => null,
    SignupStatus.signedOut || SignupStatus.failed => AuraRoutes.onboarding,
    SignupStatus.needsProfile => AuraRoutes.signup,
  };
}

final class AppRouter {
  const AppRouter._();

  static void replaceWith(BuildContext context, String location) {
    unawaited(GoRouter.of(context).replace<void>(location));
  }

  /// Pushes rather than replaces, so the system back gesture returns to where
  /// the user came from. Used for the slice-2 screens, which are a stack on top
  /// of home rather than a destination the app resets to.
  static void pushTo(BuildContext context, String location) {
    unawaited(GoRouter.of(context).push<void>(location));
  }

  static GoRouter build() => GoRouter(
    initialLocation: AuraRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AuraRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AuraRoutes.onboarding,
        builder: (context, state) =>
            const OnboardingScreen(showPrototype: prototypeMode),
      ),
      GoRoute(
        path: AuraRoutes.signup,
        builder: (context, state) => const SignupFlowScreen(),
      ),
      GoRoute(
        path: AuraRoutes.home,
        // Guarded as of slice 2. Any `aura://` URI resolves to its path, so
        // every route here is reachable from outside the app — an unguarded
        // /home would render an empty account to a signed-out caller.
        redirect: _requireAccount,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AuraRoutes.sendAura,
        redirect: _requireAccount,
        builder: (context, state) => const SendAuraScreen(),
      ),
      GoRoute(
        path: AuraRoutes.photo,
        redirect: _requireAccount,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final account = ref.watch(currentUserProvider).value;
            return Scaffold(
              appBar: AppBar(title: const Text('profile photo')),
              body: SafeArea(
                child: account == null
                    ? const Center(child: CircularProgressIndicator())
                    : ref.watch(prototypeEnabledProvider)
                    ? LocalPhotoStep(
                        onContinue: () =>
                            AppRouter.replaceWith(context, AuraRoutes.home),
                      )
                    : PhotoStep(
                        username: account.username,
                        score: account.score,
                        onSkip: () =>
                            AppRouter.replaceWith(context, AuraRoutes.home),
                      ),
              ),
            );
          },
        ),
      ),
      // Slice 2. These are the screens the comment above predicted would need a
      // guard: unlike signup, there is no legitimate way to be on a friends
      // screen without a finished account, and an unguarded one would run
      // Firestore queries scoped to a uid that does not exist.
      //
      // The guard is per-route, not global, for the reason given above — a
      // global redirect would have to know that mid-signup is allowed to be
      // signed in without a profile.
      GoRoute(
        path: AuraRoutes.friends,
        redirect: _requireAccount,
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: AuraRoutes.addFriend,
        redirect: _requireAccount,
        builder: (context, state) => const AddFriendScreen(),
      ),
      GoRoute(
        path: AuraRoutes.profileByUsername,
        // Deliberately guarded too. An invite link opened by someone with no
        // account sends them to onboarding rather than to a profile they cannot
        // act on — and `publicProfiles` denies signed-out reads anyway, so the
        // alternative is a screen that can only ever show an error.
        redirect: _requireAccount,
        builder: (context, state) => ProfilePreviewScreen(
          username: state.pathParameters['username'] ?? '',
        ),
      ),
      // Slice 9. Guarded for the same reason the friends screens are: these
      // read and write the signed-in account, and deletion in particular must
      // never be reachable without one.
      GoRoute(
        path: AuraRoutes.settings,
        redirect: _requireAccount,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AuraRoutes.blockedList,
        redirect: _requireAccount,
        builder: (context, state) => const BlockedListScreen(),
      ),
      GoRoute(
        path: AuraRoutes.deleteAccount,
        redirect: _requireAccount,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      // Debug builds only. This is a developer surface, and it used to ship in
      // release unguarded — which the custom-scheme deep link made externally
      // reachable by anyone who could get `aura://x/_design` in front of the
      // user. Compiling it out is simpler and more certain than guarding it.
      if (kDebugMode)
        GoRoute(
          path: AuraRoutes.designCheck,
          builder: (context, state) => const DesignCheckScreen(),
        ),
    ],
    // Deliberately does NOT echo `state.uri`. A deep link is attacker-supplied
    // text, and reflecting it into trusted chrome lets a crafted link render
    // chosen glyphs (RTL overrides, zero-width characters) inside the app's own
    // UI. There is no HTML sink in Flutter so this is spoofing rather than XSS,
    // but there is also no reason to show it.
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('that link did not go anywhere.')),
    ),
  );
}
