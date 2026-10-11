import 'package:flutter/widgets.dart';

/// Spacing, radii and sizing, from spec section 6.6.
///
/// Spec asks for: cards 16–24px radius, buttons fully rounded ("pill"), inputs
/// 12–14px, generous whitespace, one card per idea. These are the only spacing
/// numbers in the app — do not hardcode padding at call sites.
abstract final class AuraSpacing {
  /// 4pt base grid.
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Standard screen edge inset. Spec calls for generous whitespace.
  static const screenPadding = 20.0;

  /// Inside a feed / stat card.
  static const cardPadding = 16.0;

  /// Gap between stacked cards.
  static const cardGap = 12.0;
}

abstract final class AuraRadius {
  /// Inputs — spec says 12–14px.
  static const input = Radius.circular(14);

  /// Cards — spec says 16–24px. 20 is our default; use [cardLarge] for hero
  /// surfaces like the score card.
  static const card = Radius.circular(20);
  static const cardLarge = Radius.circular(24);

  /// Bottom sheets, rounded on top only.
  static const sheet = Radius.circular(28);

  /// Fully rounded pill. Spec: buttons are "fully rounded pills".
  static const pill = Radius.circular(999);

  static const inputAll = BorderRadius.all(input);
  static const cardAll = BorderRadius.all(card);
  static const cardLargeAll = BorderRadius.all(cardLarge);
  static const pillAll = BorderRadius.all(pill);
  static const sheetTop = BorderRadius.vertical(top: sheet);
}

/// Minimum tap sizes. iOS HIG says 44pt, Android Material says 48dp — we use
/// the larger of the two everywhere so a control is never comfortable on one
/// platform and fiddly on the other.
abstract final class AuraTouch {
  static const minTarget = 48.0;

  /// Smallest gap between two adjacent tappable things, so a thumb doesn't
  /// catch the wrong one.
  static const minGap = 8.0;
}
