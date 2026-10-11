/// The illustration shown above the headline on each onboarding page.
///
/// Every one is built from the real design-system primitives — the same
/// `AuraOrb`, `AuraCard` and `AuraPoints` the app uses. That is deliberate:
/// onboarding art drawn separately drifts from the product, and then the app
/// looks like a different app than the one that was pitched thirty seconds
/// earlier. Spec §5.2 asks for previews of real screens, not decoration.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_motion.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../shared/widgets/aura_card.dart';
import '../../../shared/widgets/aura_orb.dart';
import '../../../shared/widgets/aura_points.dart';

/// Page 1 — "orb visual with a wobbling score number" (§5.2).
class OnboardingOrbArt extends StatefulWidget {
  const OnboardingOrbArt({super.key});

  @override
  State<OnboardingOrbArt> createState() => _OnboardingOrbArtState();
}

class _OnboardingOrbArtState extends State<OnboardingOrbArt> {
  /// The numbers the score cycles through. Chosen to sit either side of the 1000
  /// baseline so the wobble reads as "this goes up *and* down" — which is the
  /// whole point of the mechanic, communicated before a single word is read.
  static const _scores = [1000, 1240, 980, 1180];

  /// The count animation plus a beat to read the result on.
  static const _cycle = Duration(milliseconds: 2200);

  Timer? _timer;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is unavailable in initState, so the motion preference is read
    // here — and re-read if the user changes it while the app is open.
    //
    // A plain Timer rather than an AnimationController: the actual animating is
    // done by the TweenAnimationBuilder below, so a controller would tick every
    // frame purely to act as a clock.
    if (AuraMotion.prefersReducedMotion(context)) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(_cycle, _next);
    }
  }

  void _next(Timer _) {
    if (!mounted) return;
    setState(() => _index = (_index + 1) % _scores.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _scores[_index];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuraOrb(score: score, size: 150),
        const SizedBox(height: AuraSpacing.lg),
        // Counts to the new value rather than cutting — spec §6.5 is explicit
        // that a score must never hard-cut, and that rule starts here.
        //
        // `begin` is deliberately left null: TweenAnimationBuilder then lerps
        // from whatever is currently on screen, which is what makes this a
        // count-up. Setting begin to the same value would freeze it.
        TweenAnimationBuilder<double>(
          tween: Tween(end: score.toDouble()),
          duration: AuraMotion.respecting(context, AuraMotion.scoreCount),
          curve: AuraMotion.scoreCurve,
          builder: (context, value, child) =>
              Text(value.round().toString(), style: AuraType.scoreLarge),
        ),
        Text('aura', style: AuraType.bodySmall),
      ],
    );
  }
}

/// Page 2 — "example transaction card animation" (§5.2).
///
/// Shows one positive and one negative card together. Showing only the positive
/// one would undersell the mechanic; showing only the negative would make the
/// app look mean. Both, side by side, is the honest pitch.
class OnboardingTransactionArt extends StatelessWidget {
  const OnboardingTransactionArt({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MockTransactionCard(
          handle: '@sam',
          points: 120,
          reason: 'paid without being asked',
        ),
        SizedBox(height: AuraSpacing.md),
        _MockTransactionCard(
          handle: '@dev',
          points: -80,
          reason: 'left me on read',
        ),
      ],
    );
  }
}

class _MockTransactionCard extends StatelessWidget {
  const _MockTransactionCard({
    required this.handle,
    required this.points,
    required this.reason,
  });

  final String handle;
  final int points;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      borderColor: AuraColors.forPoints(points).withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(handle, style: AuraType.bodyStrong),
                const SizedBox(height: 2),
                Text(reason, style: AuraType.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AuraSpacing.md),
          AuraPoints(points: points, style: AuraType.scoreSmall),
        ],
      ),
    );
  }
}

/// Page 3 — "leaderboard + privacy toggle preview" (§5.2).
class OnboardingPrivacyArt extends StatelessWidget {
  const OnboardingPrivacyArt({super.key});

  static const _rows = <(int, String, int)>[
    (1, '@sam', 1420),
    (2, '@you', 1180),
    (3, '@dev', 940),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuraCard(
          child: Column(
            children: [
              for (final (rank, handle, score) in _rows) ...[
                if (rank > 1) const SizedBox(height: AuraSpacing.md),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$rank',
                        style: rank == 1
                            ? AuraType.bodyStrong.copyWith(
                                color: AuraColors.gold,
                              )
                            : AuraType.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        handle,
                        style: handle == '@you'
                            ? AuraType.bodyStrong
                            : AuraType.body,
                      ),
                    ),
                    Text('$score', style: AuraType.bodyStrong),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AuraSpacing.md),
        // A mock, not a live Switch: tapping it here would set a preference the
        // user has no account to store it on. The real control lives in settings
        // (§5.11). Marked decorative so a screen reader does not announce a
        // switch that cannot be operated.
        ExcludeSemantics(
          child: AuraCard(
            child: Row(
              children: [
                Expanded(
                  child: Text('show me on leaderboards', style: AuraType.body),
                ),
                const SizedBox(width: AuraSpacing.md),
                Container(
                  width: 44,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AuraColors.positive,
                    borderRadius: AuraRadius.pillAll,
                  ),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Page 4 — the contacts framing (§5.2, copy §7.4).
///
/// The permission is *not* requested from this art. Onboarding sets up the ask;
/// the actual `requestPermission` call belongs with the contact-matching flow in
/// slice 2, where a denial has somewhere sensible to land.
class OnboardingFriendsArt extends StatelessWidget {
  const OnboardingFriendsArt({super.key});

  static const _friends = <(String, int)>[
    ('@sam', 1420),
    ('@dev', 1180),
    ('@ria', 1060),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (handle, score) in _friends) ...[
          AuraCard(
            child: Row(
              children: [
                AuraOrb(score: score, size: 36),
                const SizedBox(width: AuraSpacing.md),
                Expanded(child: Text(handle, style: AuraType.bodyStrong)),
                Text('already here', style: AuraType.caption),
              ],
            ),
          ),
          const SizedBox(height: AuraSpacing.sm),
        ],
      ],
    );
  }
}
