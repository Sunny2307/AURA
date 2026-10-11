import 'package:flutter/material.dart';

import 'aura_colors.dart';

/// Type scale for Aura, from spec section 6.3.
///
/// The spec asks for a rounded sans-serif — SF Pro Rounded, "or Poppins/Nunito
/// as cross-platform equivalents". Nunito is the pick: it has genuinely rounded
/// terminals, which Poppins does not (Poppins is geometric with flat cuts), so
/// Nunito is far closer to the SF Pro Rounded feel the spec is reaching for.
///
/// The font is bundled in `assets/fonts/` rather than fetched at runtime. A
/// runtime fetch would show a fallback font on first launch and offline, which
/// is unacceptable for an app whose whole pitch is how it looks.
abstract final class AuraType {
  static const family = 'Nunito';

  /// Nunito ships as a single variable font whose `wght` axis runs 200–1000 with
  /// a **default of 200** — verified by `tool/check_font.js`, not assumed.
  ///
  /// That default is the trap: [TextStyle.fontWeight] alone does not move a
  /// variable axis, so any style that omits [FontVariation] renders at 200
  /// (ExtraLight) — hairline thin, not merely "not bold". Every style in this
  /// class therefore sets the axis explicitly, and [textTheme] below fills in
  /// *every* slot so no Material widget can fall through to a variation-less
  /// default.
  static TextStyle _style({
    required double size,
    required int weight,
    double letterSpacing = 0,
    double? height,
    Color color = AuraColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  // ---- Score numbers ------------------------------------------------------
  // Spec: extra bold, 48-64px on the home screen, should feel bouncy and alive.

  /// The wordmark. Not part of the type scale — it takes a size because it
  /// appears at 40px on the splash, ~24px in a header, and small as a share-card
  /// watermark, and it must look like the same mark at all three.
  ///
  /// Weight 800 with tighter tracking than [scoreHero]: at four letters, tight
  /// tracking reads as deliberate; at a whole number it reads as cramped.
  static TextStyle wordmark({
    required double size,
    Color color = AuraColors.textPrimary,
  }) {
    return _style(
      size: size,
      weight: 800,
      letterSpacing: size * -0.045,
      height: 1.0,
      color: color,
    );
  }

  /// The big number on the home screen.
  static TextStyle get scoreHero =>
      _style(size: 60, weight: 800, letterSpacing: -2, height: 1.0);

  /// Score on a profile or an exported card.
  static TextStyle get scoreLarge =>
      _style(size: 40, weight: 800, letterSpacing: -1.2, height: 1.0);

  /// Point value on a feed card.
  static TextStyle get scoreSmall =>
      _style(size: 20, weight: 800, letterSpacing: -0.4);

  // ---- Headings -----------------------------------------------------------
  // Spec: letter spacing slightly tight on headers for a modern feel.

  static TextStyle get headingLarge =>
      _style(size: 28, weight: 700, letterSpacing: -0.6, height: 1.15);

  static TextStyle get headingMedium =>
      _style(size: 20, weight: 700, letterSpacing: -0.3, height: 1.2);

  // ---- Body ---------------------------------------------------------------
  // Spec: regular weight, 14-16px, normal letter spacing for readability.

  static TextStyle get body => _style(size: 15, weight: 400, height: 1.4);

  static TextStyle get bodyStrong =>
      _style(size: 15, weight: 600, height: 1.4);

  static TextStyle get bodySmall => _style(
    size: 13,
    weight: 400,
    height: 1.35,
    color: AuraColors.textMuted,
  );

  /// Buttons, chips, tab labels.
  static TextStyle get label =>
      _style(size: 15, weight: 600, letterSpacing: 0.1);

  /// Timestamps and other quiet metadata.
  static TextStyle get caption =>
      _style(size: 12, weight: 400, color: AuraColors.textMuted);

  /// Assembled [TextTheme].
  ///
  /// **Every one of the 15 slots is filled deliberately.** An empty slot falls
  /// back to a Material default that carries `fontFamily: Nunito` but no
  /// `fontVariations`, which lands on the axis default of 200 and renders as
  /// hairline text in whatever widget happened to use that slot.
  static TextTheme get textTheme => TextTheme(
    displayLarge: scoreHero,
    displayMedium: scoreLarge,
    displaySmall: scoreSmall,
    headlineLarge: headingLarge,
    headlineMedium: headingMedium,
    headlineSmall: headingMedium,
    titleLarge: headingMedium,
    titleMedium: bodyStrong,
    titleSmall: bodyStrong,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: bodySmall,
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  );
}
