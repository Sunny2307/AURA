import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_motion.dart';

/// The orb — Aura's visual identity (spec section 6.1: "a glowing orb that
/// represents your aura").
///
/// Its colour reflects standing and it breathes continuously (spec 6.5: "always
/// subtle pulse — the orb is alive").
///
/// Three things about the implementation matter, because this widget is on
/// screen the whole time the app is open:
///
/// 1. **It never rebuilds per frame.** [ScaleTransition] and [FadeTransition]
///    mark the layer for repaint without rebuilding the widget tree, so the
///    gradients are laid out once, not 60 times a second.
/// 2. **It is wrapped in a [RepaintBoundary]** so the breathing never dirties
///    the rest of the screen.
/// 3. **It stops when it should.** An animation that runs forever is a battery
///    cost and, for someone with vestibular sensitivity, a genuine problem — so
///    it honours the OS reduce-motion setting and pauses when the app leaves the
///    foreground.
class AuraOrb extends StatefulWidget {
  const AuraOrb({
    super.key,
    this.score,
    this.color,
    this.size = 200,
  }) : assert(
         score != null || color != null,
         'Give AuraOrb a score, or an explicit color.',
       );

  /// The score the orb represents. Drives its colour via [colorForScore].
  final int? score;

  /// Explicit colour, overriding [score]. For the design-check screen and for
  /// contexts where standing is already known.
  final Color? color;

  /// Diameter of the glow. The solid core is about half this.
  final double size;

  /// Baseline score for a new account (spec section 3).
  static const baselineScore = 1000;

  /// Colour for a score.
  ///
  /// Coral at or below 600, through neutral grey, to full teal at the 1000
  /// baseline. Above 1000 the hue stops changing and the glow gets stronger
  /// instead — see [_glowStrengthForScore]. Gold is deliberately *not* used for
  /// a high score: the spec reserves it for premium, streaks and top-3, and it
  /// only stays meaningful if it stays rare.
  static Color colorForScore(int score) {
    const floor = 600.0;
    const baseline = 1000.0;

    if (score <= floor) {
      final t = (score / floor).clamp(0.0, 1.0);
      return Color.lerp(AuraColors.negative, AuraColors.neutral, t)!;
    }
    final t = ((score - floor) / (baseline - floor)).clamp(0.0, 1.0);
    return Color.lerp(AuraColors.neutral, AuraColors.positive, t)!;
  }

  /// 1.0 at the baseline, rising to 1.5 by 2500 aura. Gives high scorers a
  /// visibly bigger halo without inventing a new colour for them.
  static double _glowStrengthForScore(int score) {
    if (score <= baselineScore) return 1;
    return 1 + ((score - baselineScore) / 1500).clamp(0.0, 0.5);
  }

  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  /// 0 → 1 → 0 breath cycle, eased. Every visual tween is driven off this.
  late Animation<double> _breath;

  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: AuraMotion.orbBreath,
      vsync: this,
    );
    _breath = _controller.drive(CurveTween(curve: AuraMotion.breathCurve));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only available here, not in initState.
    final reduced = AuraMotion.prefersReducedMotion(context);
    if (reduced == _reducedMotion && (reduced || _controller.isAnimating)) {
      return;
    }
    _reducedMotion = reduced;
    _applyMotionPreference();
  }

  void _applyMotionPreference() {
    if (_reducedMotion) {
      _controller.stop();
      // Hold mid-breath so a still orb still looks like the animated one.
      _breath = const AlwaysStoppedAnimation(0.5);
    } else {
      _breath = _controller.drive(CurveTween(curve: AuraMotion.breathCurve));
      _controller.repeat(reverse: true);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flutter already halts vsync when the app is backgrounded, so this is
    // belt-and-braces — but `inactive` (app switcher, incoming call) is a real
    // case where the ticker can keep running.
    if (state == AppLifecycleState.resumed) {
      if (!_reducedMotion && !_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    final target = widget.color ?? AuraOrb.colorForScore(score!);
    final glowStrength = score == null
        ? 1.0
        : AuraOrb._glowStrengthForScore(score);

    return RepaintBoundary(
      child: Semantics(
        label: score == null ? 'Aura orb' : 'Aura orb, score $score',
        child: SizedBox.square(
          dimension: widget.size,
          // Colour change is tweened rather than snapped so a score update
          // shifts the hue instead of flickering to it.
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: AuraMotion.respecting(context, AuraMotion.scoreCount),
            builder: (context, color, _) => _OrbBody(
              breath: _breath,
              color: color ?? target,
              glowStrength: glowStrength,
            ),
          ),
        ),
      ),
    );
  }
}

/// The layers of the orb. Split out so the transitions below own their own
/// render objects and can repaint without touching [_AuraOrbState].
class _OrbBody extends StatelessWidget {
  const _OrbBody({
    required this.breath,
    required this.color,
    required this.glowStrength,
  });

  final Animation<double> breath;
  final Color color;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        // Outer halo. Fades to fully transparent rather than using a blurred
        // shadow — a gradient costs nothing to composite, a blur costs a lot.
        FadeTransition(
          opacity: breath.drive(Tween(begin: 0.55, end: 1)),
          child: ScaleTransition(
            scale: breath.drive(Tween(begin: 0.92, end: 1.06)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.40 * glowStrength),
                    color.withValues(alpha: 0.14 * glowStrength),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0.28, 0.55, 1],
                ),
              ),
            ),
          ),
        ),

        // Solid core.
        Center(
          child: ScaleTransition(
            scale: breath.drive(Tween(begin: 0.97, end: 1.03)),
            child: FractionallySizedBox(
              widthFactor: 0.52,
              heightFactor: 0.52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    // Off-centre so the orb reads as a lit sphere, not a disc.
                    center: const Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: [
                      Color.lerp(color, Colors.white, 0.35)!,
                      color,
                      Color.lerp(color, AuraColors.background, 0.55)!,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
