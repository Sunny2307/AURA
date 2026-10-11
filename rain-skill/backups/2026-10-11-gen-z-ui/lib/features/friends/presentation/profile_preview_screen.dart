import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/public_profile.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../core/validation/username_rules.dart';
import '../../auth/application/auth_providers.dart';
import '../application/friends_providers.dart';
import '../../safety/presentation/safety_menu.dart';
import 'friend_action_button.dart';
import 'friend_tile.dart';

/// Where an invite link lands: one person, by handle, with the same add/accept
/// control the search screen uses.
///
/// Reached from `aura://u/<handle>`. The link carries the *handle* rather than
/// the uid deliberately — a uid in a shared link is an opaque string nobody can
/// sanity-check, while `aura://u/samjones` is legible, and the handle is
/// permanent anyway because `usernames/{name}` is never reassigned.
class ProfilePreviewScreen extends ConsumerWidget {
  const ProfilePreviewScreen({super.key, required this.username});

  final String username;

  /// The handle if it could possibly be one, and a placeholder otherwise.
  /// Deliberately does not echo back the rejected input — the point is to keep
  /// attacker-chosen characters out of the UI, so printing them in an error
  /// would defeat it.
  static String _safeHandle(String raw) {
    return switch (UsernameRules.check(raw)) {
      UsernameValid(:final normalised) => normalised,
      UsernameInvalid() => '…',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    final lookup = ref.watch(profileByUsernameProvider(username));

    return Scaffold(
      // The *normalised* handle, never the raw path parameter. A deep link is
      // attacker-supplied text, and rendering it unfiltered into the app bar
      // would let a crafted link put chosen glyphs — right-to-left overrides,
      // zero-width characters — inside the app's own chrome. `UsernameRules`
      // only admits `[a-z0-9_]`.
      appBar: AppBar(title: Text('@${_safeHandle(username)}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.screenPadding),
          child: switch (lookup) {
            AsyncError() => _Centred(
              title: 'could not open that link.',
              body: 'check your connection and try again.',
              onRetry: () =>
                  ref.invalidate(profileByUsernameProvider(username)),
            ),

            // Null covers both "no such handle" and a handle that could never be
            // valid. They read the same to the person holding the link, and
            // distinguishing them would only tell a stranger which handles are
            // well-formed but free.
            AsyncData(value: null) => const _Centred(
              title: 'nobody has that handle.',
              body: 'the link may be out of date.',
            ),

            AsyncData(value: final PublicProfile p) when p.uid == myUid =>
              const _Centred(
                title: 'this is your own link.',
                body: 'send it to someone else to be added.',
              ),

            AsyncData(value: final PublicProfile p) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FriendTile(
                  profile: p,
                  // Available before you are friends, which is the point: this
                  // screen is reachable from an invite link sent by a stranger.
                  trailing: SafetyMenu(otherUid: p.uid, handle: p.handle),
                ),
                const SizedBox(height: AuraSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FriendActionButton(
                    otherUid: p.uid,
                    handle: p.handle,
                  ),
                ),
              ],
            ),

            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _Centred extends StatelessWidget {
  const _Centred({required this.title, required this.body, this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AuraType.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AuraSpacing.md),
          Text(
            body,
            style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AuraSpacing.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AuraTouch.minTarget,
              ),
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
