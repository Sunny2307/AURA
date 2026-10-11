import 'package:flutter/material.dart';

import '../../../core/models/public_profile.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';

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

    // No photo is in fact the *only* case right now. Cloud Storage is not
    // provisioned on the Spark plan, and as of the slice 2 security review
    // `isAllowedPhotoUrl` in firestore.rules rejects any non-null photoUrl —
    // because this widget renders a remote image for pending friend requests,
    // which made an arbitrary URL a zero-interaction IP beacon.
    //
    // So the branch below is currently unreachable, and is kept rather than
    // deleted because it is the shape the real feature takes once uploads are
    // constrained to the project's own bucket. The initial on a tinted circle is
    // the designed default either way, not a placeholder.
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

    return ClipOval(
      child: Image.network(
        profile.photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A photo that fails to load must not leave a broken-image glyph in a
        // friend list. It falls back to exactly what no-photo looks like.
        errorBuilder: (context, error, stackTrace) => Container(
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
        ),
      ),
    );
  }
}
