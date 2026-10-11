import 'package:flutter/material.dart';

import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../shared/widgets/aura_orb.dart';

/// The §5.3 profile-photo step — **UI only, blocked on Cloud Storage.**
///
/// The bucket for `aura-d68c3` does not exist (HTTP 404 on the bucket URL), so
/// there is nowhere to upload to. See [PhotoRepository] for the full finding and
/// what unblocking it takes.
///
/// This is built and kept rather than deleted for two reasons: the layout is the
/// part worth reviewing on a real device, and the step's *shape* — orb as default,
/// skipping as a first-class choice — is a product decision that should not have
/// to be re-litigated when the bucket arrives.
///
/// **What it deliberately does not have:** a camera button that opens a picker.
/// A picker leading to a failed or discarded upload is worse than no picker, and
/// `image_picker` is a dependency and a set of Android permissions that would sit
/// unused for however long Storage stays blocked.
class PhotoStep extends StatelessWidget {
  const PhotoStep({
    super.key,
    required this.username,
    required this.score,
    required this.onSkip,
  });

  final String username;
  final int score;

  /// Skipping is the only way forward right now, so this is required rather than
  /// nullable — a build of this screen with no way out would be a dead end.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AuraSpacing.screenPadding),
      children: [
        Text('add a photo?', style: AuraType.headingLarge),
        const SizedBox(height: AuraSpacing.sm),
        Text(
          'or keep the orb. it shifts colour with your aura, which a photo cannot.',
          style: AuraType.body.copyWith(color: AuraColors.textMuted),
        ),
        const SizedBox(height: AuraSpacing.xxl),
        Center(child: AuraOrb(score: score, size: 160)),
        const SizedBox(height: AuraSpacing.lg),
        Center(child: Text('@$username', style: AuraType.headingMedium)),
        const SizedBox(height: AuraSpacing.xxl),
        // States the block plainly rather than showing a disabled camera button
        // with no explanation. A greyed-out control with no reason reads as a bug.
        Container(
          padding: const EdgeInsets.all(AuraSpacing.lg),
          decoration: BoxDecoration(
            color: AuraColors.surface,
            borderRadius: AuraRadius.cardAll,
            border: Border.all(color: AuraColors.surfaceBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                color: AuraColors.textMuted,
              ),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Text(
                  'photo upload is not switched on yet. the orb is your avatar for now.',
                  style: AuraType.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSkip,
            child: const Text('keep the orb'),
          ),
        ),
      ],
    );
  }
}
