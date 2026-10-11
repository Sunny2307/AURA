import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_typography.dart';

/// The brand wordmark: `aura`, lowercase, tight tracking.
///
/// Exists as a widget rather than a `Text` in three places because it appears on
/// the splash, in onboarding, and as the watermark on exported share cards
/// (§5.9) — and the watermark is the growth engine, so the brand must be
/// pixel-identical everywhere it lands on someone's Instagram story.
///
/// Lowercase is not a style preference here: spec §7.1 sets lowercase UI copy as
/// a voice rule, and the wordmark is the loudest instance of it.
class AuraWordmark extends StatelessWidget {
  const AuraWordmark({
    super.key,
    this.size = 40,
    this.color = AuraColors.textPrimary,
    this.showDot = true,
  });

  /// Font size in logical pixels. The dot scales with it.
  final double size;

  final Color color;

  /// The teal dot after the word. Off for the share-card watermark, where a
  /// coloured mark competes with the user's own score.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'aura',
      // The glyphs themselves are decorative once the label above names them;
      // without this a screen reader reads "aura" and then the raw text again.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'aura',
            style: AuraType.wordmark(size: size, color: color),
          ),
          if (showDot) ...[
            SizedBox(width: size * 0.06),
            Padding(
              // Sits on the baseline rather than centred on it, the way a full
              // stop does.
              padding: EdgeInsets.only(bottom: size * 0.12),
              child: Container(
                width: size * 0.14,
                height: size * 0.14,
                decoration: const BoxDecoration(
                  color: AuraColors.positive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
