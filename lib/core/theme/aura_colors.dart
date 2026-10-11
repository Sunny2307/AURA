import 'package:flutter/material.dart';

/// A bright collectible palette. Pastels decorate; dark colors carry meaning.
/// Contrast on paper and every pastel is checked by design_system_test.dart.
abstract final class AuraColors {
  static const background = Color(0xFFFFFBF3);

  /// Raised surfaces — cards, sheets, list rows.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFF4F0E8);
  static const lilac = Color(0xFFECE4FF);
  static const peach = Color(0xFFFFE7D6);
  static const lime = Color(0xFFE5F5B6);
  static const action = Color(0xFF5842B5);
  static const onAction = Color(0xFFFFFFFF);

  /// Quiet decorative borders; interactive outlines use [controlBorder].
  static const surfaceBorder = Color(0xFFE4DDD0);
  static const controlBorder = Color(0xFF817889);

  /// Positive aura; deliberately separate from the violet action color.
  static const positive = Color(0xFF24643D);

  /// The deep end of the positive aura gradient.
  static const positiveDeep = Color(0xFF163F28);

  /// Negative aura. Used *only* for negative point values and error states —
  /// never decoratively, or it stops reading as a warning.
  static const negative = Color(0xFFB33631);

  /// Premium / streaks / top-3 leaderboard. Used very sparingly by design.
  static const gold = Color(0xFF79510B);

  static const textPrimary = Color(0xFF292337);
  static const textMuted = Color(0xFF62586B);

  /// Neutral used for a zero point value, and as the low end of the orb's
  /// colour range when someone's score is poor.
  static const neutral = Color(0xFF52525B);

  /// Positive aura gradient. Primary actions use [action] instead.
  static const positiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [positive, positiveDeep],
  );

  /// Colour for a point value. Zero is neutral grey rather than teal, so
  /// "no change" never reads as a win.
  ///
  /// Colour alone must never carry this meaning — see [AuraPoints], which
  /// always renders an explicit + or - sign alongside. Roughly 8% of men
  /// cannot reliably separate the teal from the coral.
  static Color forPoints(int points) {
    if (points > 0) return positive;
    if (points < 0) return negative;
    return neutral;
  }
}
