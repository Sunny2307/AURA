import 'package:flutter/material.dart';

import '../../../core/models/public_profile.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../shared/widgets/profile_photo.dart';

/// One person in a list: avatar, handle, and whatever action belongs to them.
///
/// There is no score here, and that is not an oversight. Scores live on
/// `users/{uid}`, which is readable only by its owner — see the comment on that
/// rule. A client-written public document could carry a score, but then a
/// tampered client could publish any number it liked and every friend list in
/// the app would show the lie. Friend scores arrive with a server, in slice 6.
class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.profile,
    this.trailing,
    this.onTap,
    this.subtitle,
  });

  final PublicProfile profile;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      // Keeps every row at or above the larger of the two platform minimums,
      // so a thumb never has to aim.
      minVerticalPadding: AuraSpacing.md,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.sm,
        vertical: AuraSpacing.xs,
      ),
      leading: _Avatar(profile: profile),
      // Truncates rather than wraps. A row with trailing controls can get
      // tight, and a two-line handle would push the whole list out of rhythm.
      title: Text(
        profile.handle,
        style: AuraType.bodyStrong,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AuraType.caption.copyWith(color: AuraColors.textMuted),
            ),
      trailing: trailing,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    const size = AuraTouch.minTarget;

    // Local prototype photos are saved on the device. Profiles without a
    // selected photo use the initial as their avatar.
    if (profile.photoUrl == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AuraColors.surface,
        ),
        child: Text(
          profile.username.isEmpty ? '?' : profile.username[0].toUpperCase(),
          style: AuraType.bodyStrong.copyWith(color: AuraColors.textMuted),
        ),
      );
    }

    return ProfilePhoto(url: profile.photoUrl!, size: size);
  }
}
