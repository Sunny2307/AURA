import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_typography.dart';

/// A point value — the single most important number in the app.
///
/// **Always use this widget instead of formatting a point value by hand.**
///
/// Aura's core mechanic is telling positive from negative, and the spec encodes
/// that difference as teal vs coral (section 6.2) — which is a green/red pair.
/// Roughly 8% of men cannot reliably distinguish those. So this widget *always*
/// renders an explicit `+` or `-` alongside the colour: the sign is the real
/// signal, the colour is reinforcement. Centralising it here is the only way to
/// guarantee some future screen doesn't forget.
///
/// The sign characters are plain ASCII `+` and `-` rather than the typographic
/// U+2212 minus, because they are guaranteed to exist in any font we ship and a
/// missing-glyph box on this particular number would be a serious bug.
class AuraPoints extends StatelessWidget {
  const AuraPoints({
    super.key,
    required this.points,
    this.style,
    this.showUnit = false,
  });

  final int points;

  /// Defaults to [AuraType.scoreSmall] — pass a bigger style for hero contexts.
  final TextStyle? style;

  /// Appends " aura", for feed cards and notification-style copy.
  final bool showUnit;

  /// Signed string for a point value: `+80`, `-40`, `0`.
  ///
  /// Zero is deliberately unsigned — a `+0` would read as a win that didn't
  /// happen.
  static String format(int points) {
    if (points > 0) return '+$points';
    if (points < 0) return '-${points.abs()}';
    return '0';
  }

  /// What a screen reader should say. "+80" alone is read inconsistently across
  /// TalkBack and VoiceOver, so we spell it out.
  static String semanticLabel(int points) {
    if (points > 0) return 'plus $points aura';
    if (points < 0) return 'minus ${points.abs()} aura';
    return 'no aura change';
  }

  @override
  Widget build(BuildContext context) {
    final text = showUnit ? '${format(points)} aura' : format(points);

    return Text(
      text,
      style: (style ?? AuraType.scoreSmall).copyWith(
        color: AuraColors.forPoints(points),
      ),
      semanticsLabel: semanticLabel(points),
    );
  }
}
