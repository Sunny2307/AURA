import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_spacing.dart';

/// A solid raised surface with a quiet gradient and deliberate border.
///
/// Card styling lives here rather than in `ThemeData.cardTheme` on purpose, so
/// the border and radius are explicit and can't be silently dropped by a
/// Material version change.
class AuraCard extends StatelessWidget {
  const AuraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AuraSpacing.cardPadding),
    this.onTap,
    this.large = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Uses the 24px radius instead of 20px, for hero surfaces like the score card.
  final bool large;

  /// Overrides the hairline border — used to tint a card by outcome, e.g. a
  /// faint teal edge on a positive feed item.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = large ? AuraRadius.cardLargeAll : AuraRadius.cardAll;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AuraColors.surfaceRaised, AuraColors.surface],
        ),
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AuraColors.surfaceBorder),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return surface;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: onTap, child: surface),
    );
  }
}
