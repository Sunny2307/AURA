import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../../../features/friends/application/friends_providers.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../../shared/widgets/aura_card.dart';
import '../../../prototype/prototype_panel.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/profile_photo.dart';
import '../../../shared/widgets/animated_aura_score.dart';
import '../../../shared/widgets/aura_wordmark.dart';
import 'local_home_extras.dart';

/// The signed-in account, read live from the selected repository.
///
/// The identity card reads the selected repository's actual score. Primary
/// actions remain visible while content scrolls; demo tools are secondary.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AuraWordmark(size: 24),
        actions: [
          if (prototypeMode) const LocalHomeActions(),
          if (prototypeMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('local demo', style: AuraType.caption)),
            ),
          IconButton(
            tooltip: 'sign out',
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: AuraNavigation(
        selected: 0,
        onSend: user.value == null
            ? null
            : () => AppRouter.pushTo(context, AuraRoutes.sendAura),
      ),
      body: SafeArea(
        child: switch (user) {
          AsyncData(value: final AuraUser account) => _Account(
            account: account,
          ),
          // Signed in with no profile document. Reachable if the app died between
          // creating the auth account and writing the user — routed rather than
          // rendered, because there is genuinely nothing to show.
          AsyncData(value: null) => const _NeedsProfile(),
          AsyncError() => const _Failed(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    if (!context.mounted) return;
    // Straight to onboarding. Going to splash instead would re-run its timer and
    // land here again for the second or two before auth state propagates.
    AppRouter.replaceWith(context, AuraRoutes.onboarding);
  }
}

/// The friend count, derived rather than stored.
///
/// `users/{uid}` used to carry a `friendCount` field that only a Cloud Function
/// could legally move — so on the Spark plan nothing ever moved it and it was
/// permanently 0. This counts the live friend list instead, which cannot drift
/// and cannot be inflated by a tampered client.
class _FriendCount extends ConsumerWidget {
  const _FriendCount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(friendCountProvider);
    return Text(
      count == 1 ? '1 friend' : '$count friends',
      style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.account});

  final AuraUser account;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AuraSpacing.screenPadding),
      children: [
        const AuraEyebrow('your reputation, remixed'),
        const SizedBox(height: 8),
        Text('a little energy.\na lot of you.', style: AuraType.headingLarge),
        const SizedBox(height: 24),
        AuraCard(
          large: true,
          color: AuraColors.lilac,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: AuraEyebrow('aura identity')),
                  if (account.photoUrl != null)
                    ProfilePhoto(url: account.photoUrl!, size: 40)
                  else
                    const Icon(
                      Icons.fingerprint_rounded,
                      color: AuraColors.action,
                      size: 30,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AuraEyebrow('aura points'),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: AnimatedAuraScore(score: account.score),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AuraOrbit(score: account.score, size: 112),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(account.handle, style: AuraType.headingMedium),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 8,
                children: [
                  AuraEyebrow(
                    'made by your people',
                    color: AuraColors.textMuted,
                  ),
                  _FriendCount(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'good energy travels.',
                style: AuraType.headingMedium,
              ),
            ),
            IconButton(
              tooltip: 'find your people',
              onPressed: () => AppRouter.pushTo(context, AuraRoutes.addFriend),
              icon: const Icon(Icons.arrow_outward_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Someone had your back? Made your day? Send them a little aura.',
          style: AuraType.body.copyWith(color: AuraColors.textMuted),
        ),
        const SizedBox(height: 20),
        AuraCard(
          color: AuraColors.peach,
          onTap: () => AppRouter.pushTo(context, AuraRoutes.friends),
          child: Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: AuraColors.action,
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('your inner circle', style: AuraType.bodyStrong),
                    const SizedBox(height: 4),
                    const _FriendCount(),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (prototypeMode) const LocalHomeExtras(),
        if (prototypeMode) const PrototypePanel(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _NeedsProfile extends ConsumerWidget {
  const _NeedsProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'your account is not finished.',
              style: AuraType.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.md),
            Text(
              'pick up where you left off.',
              style: AuraType.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.xl),
            FilledButton(
              onPressed: () =>
                  AppRouter.replaceWith(context, AuraRoutes.signup),
              child: const Text('finish signing up'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends ConsumerWidget {
  const _Failed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'could not load your aura.',
              style: AuraType.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpacing.md),
            Text(
              'check your connection and try again.',
              style: AuraType.bodySmall.copyWith(color: AuraColors.negative),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.invalidate(currentUserProvider),
              child: const Text('try again'),
            ),
          ],
        ),
      ),
    );
  }
}
