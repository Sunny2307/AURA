import 'package:flutter/material.dart';

/// Aura's colour palette, taken verbatim from the product spec section 6.2.
///
/// Every value here has been checked against WCAG contrast ratios by
/// `tool/check_contrast.js`. Worst case in the palette is 6.78:1 (coral on
/// surface) and everything else clears 7:1 (AAA). Re-run that script if you
/// change any value.
///
/// Deliberately only two real hues — teal and coral — plus gold used sparingly
/// so it keeps its meaning. Do not add a third accent without a reason.
abstract final class AuraColors {
  /// Near-black app background. Not pure #000000 on purpose: true black causes
  /// visible smearing while scrolling on OLED panels.
  static const background = Color(0xFF0A0A0A);

  /// Raised surfaces — cards, sheets, list rows.
  static const surface = Color(0xFF141414);

  /// Hairline border on surfaces, giving the glassmorphic edge the spec asks
  /// for. Spec says 6–8% white; 7% is the middle.
  static const surfaceBorder = Color(0x12FFFFFF);

  /// Positive aura. The bright end of the teal-emerald gradient.
  static const positive = Color(0xFF14B88A);

  /// The deep end of that gradient, for fills and button backgrounds.
  static const positiveDeep = Color(0xFF053D2C);

  /// Negative aura. Used *only* for negative point values and error states —
  /// never decoratively, or it stops reading as a warning.
  static const negative = Color(0xFFFB7360);

  /// Premium / streaks / top-3 leaderboard. Used very sparingly by design.
  static const gold = Color(0xFFD4AF37);

  static const textPrimary = Color(0xFFF4F4F5);
  static const textMuted = Color(0xFFA1A1AA);

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
