import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_spacing.dart';

/// A paper surface with an optional pastel fill and a soft offset shadow.
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
    this.color = AuraColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Uses the 24px radius instead of 20px, for hero surfaces like the score card.
  final bool large;

  /// Overrides the hairline border — used to tint a card by outcome, e.g. a
  /// faint teal edge on a positive feed item.
  final Color? borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = large ? AuraRadius.cardLargeAll : AuraRadius.cardAll;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          BoxShadow(
            color: AuraColors.textPrimary.withValues(alpha: 0.05),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AuraColors.surfaceBorder),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return surface;

    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? AuraColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
