import 'package:flutter/material.dart';

/// The social-collectible palette: warm ink, mint, and readable paper-white.
/// Text contrast on all three surfaces is checked by design_system_test.dart.
abstract final class AuraColors {
  /// Near-black app background. Not pure #000000 on purpose: true black causes
  /// visible smearing while scrolling on OLED panels.
  static const background = Color(0xFF0C100F);

  /// Raised surfaces — cards, sheets, list rows.
  static const surface = Color(0xFF19201D);
  static const surfaceRaised = Color(0xFF242E28);

  /// Quiet decorative borders; interactive outlines use [controlBorder].
  static const surfaceBorder = Color(0xFF39463D);
  static const controlBorder = Color(0xFF82978A);

  /// Positive aura and the primary action colour.
  static const positive = Color(0xFFB5F5CE);

  /// The deep end of that gradient, for fills and button backgrounds.
  static const positiveDeep = Color(0xFF285942);

  /// Negative aura. Used *only* for negative point values and error states —
  /// never decoratively, or it stops reading as a warning.
  static const negative = Color(0xFFFB7360);

  /// Premium / streaks / top-3 leaderboard. Used very sparingly by design.
  static const gold = Color(0xFFEBD89C);

  static const textPrimary = Color(0xFFF6F5EF);
  static const textMuted = Color(0xFFADB9B0);

  /// Neutral used for a zero point value, and as the low end of the orb's
  /// colour range when someone's score is poor.
  static const neutral = Color(0xFF52525B);

  /// The positive gradient from spec 6.2, for primary buttons and the orb core.
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
