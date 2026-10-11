import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_typography.dart';
import 'aura_logo.dart';

/// The brand wordmark: `aura`, lowercase, tight tracking.
///
/// Shared by the splash, onboarding and home header with the approved logo.
///
/// Lowercase is not a style preference here: spec §7.1 sets lowercase UI copy as
/// a voice rule, and the wordmark is the loudest instance of it.
class AuraWordmark extends StatelessWidget {
  const AuraWordmark({
    super.key,
    this.size = 40,
    this.color = AuraColors.textPrimary,
    this.showDot = false,
    this.showLogo = true,
  });

  /// Font size in logical pixels. The dot scales with it.
  final double size;

  final Color color;

  /// Optional punctuation for older wordmark callers.
  final bool showDot;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'aura',
      // The glyphs themselves are decorative once the label above names them;
      // without this a screen reader reads "aura" and then the raw text again.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showLogo) ...[
            AuraLogo(size: size * 1.15),
            SizedBox(width: size * 0.25),
          ],
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              'aura',
              style: AuraType.wordmark(size: size, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                  color: AuraColors.action,
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
