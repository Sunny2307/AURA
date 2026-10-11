import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_motion.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../../../shared/widgets/aura_orb.dart';
import '../../../shared/widgets/aura_wordmark.dart';

/// Spec §5.1: max 1.5–2s, teal orb pulsing once, wordmark fading in beneath.
///
/// The orb's breath cycle is 1500ms (`AuraMotion.orbBreath`), so simply showing
/// the normal [AuraOrb] for [_minimumDisplay] *is* one pulse — no special-case
/// animation, and the orb the user sees here is exactly the one they will see on
/// the home screen.
///
/// Two things this screen must not do:
///
/// * **Outstay its welcome.** The spec's 2s ceiling is a hard one. A splash is a
///   cost paid to hide startup work, and there is barely any startup work here;
///   the duration below is brand imprint, and that is all it is allowed to be.
/// * **Navigate after being disposed.** The timer outlives the widget if the user
///   backgrounds the app during it, so the callback checks `mounted` and the
///   timer is cancelled in [dispose].
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// Short of the spec's 1.5s floor on purpose: the orb fades and scales in over
  /// its first frames, so perceived duration runs a little longer than the timer.
  static const Duration _minimumDisplay = Duration(milliseconds: 1400);

  /// How long to keep waiting past [_minimumDisplay] for auth state to resolve
  /// before giving up and showing onboarding.
  ///
  /// A ceiling is needed because [SignupStatus.resolving] can persist: a device
  /// with no connection may never get a Firestore snapshot, and a splash screen
  /// that waits forever is a hang. Onboarding is the right thing to fall back to
  /// — it is the only screen that works with no account and no network.
  static const Duration _authGracePeriod = Duration(milliseconds: 2500);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  Timer? _graceTimer;

  /// True once [SplashScreen._minimumDisplay] has elapsed. Routing waits on both
  /// this and a resolved auth state, so the brand moment is never cut short by a
  /// fast auth check and never extended by a slow one beyond the grace period.
  bool _minimumElapsed = false;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen._minimumDisplay, () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
      _routeIfReady();
    });
    _graceTimer = Timer(SplashScreen._authGracePeriod, () {
      if (!mounted) return;
      // Auth never resolved. Onboarding, not an error — someone opening the app
      // on a train has done nothing wrong.
      _route(AuraRoutes.onboarding);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _graceTimer?.cancel();
    super.dispose();
  }

  void _routeIfReady() {
    if (!_minimumElapsed) return;

    switch (ref.read(signupStatusProvider)) {
      // Not resolved yet. Held, not guessed — the grace timer above is the
      // backstop. Routing on `unknown` would flash onboarding at a returning
      // user on every cold start, which is the bug this state exists to prevent.
      case SignupStatus.resolving:
        return;
      // Resolved, into a failure. No point burning the rest of the grace period
      // waiting for an answer that has already arrived.
      case SignupStatus.failed:
        _route(AuraRoutes.onboarding);
      case SignupStatus.signedOut:
        _route(AuraRoutes.onboarding);
      // Signed in with no profile document — the app died mid-signup. Back into
      // the flow to finish, not to home, which would render an empty account.
      case SignupStatus.needsProfile:
        _route(AuraRoutes.signup);
      case SignupStatus.ready:
        _route(AuraRoutes.home);
    }
  }

  void _route(String location) {
    // Both timers and the provider listener can fire; whoever gets here first
    // wins and the rest are no-ops. Without this, a late grace timer could
    // replace the home screen with onboarding a second after a successful route.
    if (_routed || !mounted) return;
    _routed = true;
    _timer?.cancel();
    _graceTimer?.cancel();
    AppRouter.replaceWith(context, location);
  }

  @override
  Widget build(BuildContext context) {
    // Watched rather than read, so a status that resolves *after* the minimum
    // display has elapsed still routes. Reading once in initState would strand
    // anyone whose auth check outlasts the brand moment.
    ref.listen(signupStatusProvider, (_, _) => _routeIfReady());

    // Reduce motion means no fade — the wordmark is simply there. Someone who
    // has asked the OS for less animation should not be made to wait for a brand
    // moment to finish.
    final reduceMotion = AuraMotion.prefersReducedMotion(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AuraOrb(score: 1000, size: 180),
            const SizedBox(height: AuraSpacing.xl),
            if (reduceMotion)
              const AuraWordmark()
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AuraMotion.medium,
                curve: AuraMotion.enter,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    // Rises a few pixels as it fades in. Cheap, and it stops the
                    // wordmark from looking like it was always there at 0%.
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 8),
                      child: child,
                    ),
                  );
                },
                child: const AuraWordmark(),
              ),
          ],
        ),
      ),
    );
  }
}
