import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/aura_motion.dart';
import '../../core/theme/aura_typography.dart';

class AnimatedAuraScore extends StatefulWidget {
  const AnimatedAuraScore({super.key, required this.score});
  final int score;
  @override
  State<AnimatedAuraScore> createState() => _AnimatedAuraScoreState();
}

class _AnimatedAuraScoreState extends State<AnimatedAuraScore> {
  @override
  void didUpdateWidget(AnimatedAuraScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.score - widget.score).abs() >= 100 &&
        !AuraMotion.prefersReducedMotion(context)) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${widget.score} aura points',
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: widget.score.toDouble(),
          end: widget.score.toDouble(),
        ),
        duration: AuraMotion.respecting(context, AuraMotion.scoreCount),
        curve: Curves.easeOutCubic,
        builder: (_, value, _) =>
            Text('${value.round()}', style: AuraType.scoreHero),
      ),
    ),
  );
}
