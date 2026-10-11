import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../../../features/friends/application/friends_providers.dart';
import '../../../shared/widgets/aura_orb.dart';
import '../../../prototype/prototype_panel.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/profile_photo.dart';

/// The signed-in account, read live from the selected repository.
///
/// **This is the slice-1 version, not the §5.4 home screen.** Its job is to prove
/// the round trip — an account exists, the document is real, the score is 1000 —
/// and to be the thing you can point at on a physical phone and say "that came
/// back from the cloud". The animated score, quick-stats row and feed arrive in
/// slices 3–5.
///
/// It reads from [currentUserProvider], a live Firestore stream rather than a
/// value passed in from signup. When the Node API changes the score, this
/// screen updates without anyone wiring anything up.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('aura', style: AuraType.headingMedium),
        actions: [
          IconButton(
            tooltip: 'friends',
            onPressed: () => AppRouter.pushTo(context, AuraRoutes.friends),
            icon: const Icon(Icons.people_outline),
          ),
          IconButton(
            tooltip: 'settings',
            onPressed: () => AppRouter.pushTo(context, AuraRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'sign out',
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRouter.pushTo(context, AuraRoutes.sendAura),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('send aura'),
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
          AsyncError(:final error) => _Failed(error: error),
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
        const SizedBox(height: AuraSpacing.xl),
        if (account.photoUrl != null)
          Center(child: ProfilePhoto(url: account.photoUrl!, size: 80)),
        Center(child: AuraOrb(score: account.score, size: 200)),
        const SizedBox(height: AuraSpacing.xl),
        Center(
          // Not animated yet. Spec §6.5 requires a count-up rather than a hard
          // cut, and that belongs with the first real score *change* in slice 3 —
          // counting up from nothing on every cold start would be theatre.
          child: Text('${account.score}', style: AuraType.scoreHero),
        ),
        const SizedBox(height: AuraSpacing.sm),
        Center(
          child: Text(
            account.handle,
            style: AuraType.body.copyWith(color: AuraColors.textMuted),
          ),
        ),
        const SizedBox(height: AuraSpacing.lg),
        const Center(child: _FriendCount()),
        const SizedBox(height: AuraSpacing.xxl),
        if (prototypeMode) const PrototypePanel(),
        Text(
          'send aura to a friend. your score updates live when they send to you.',
          textAlign: TextAlign.center,
          style: AuraType.bodySmall,
        ),
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

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
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
            // The message is shown, not swallowed. This is a beta on one device;
            // a generic "something went wrong" here would cost more debugging
            // time than the leak of a Firestore error code is worth. Worth
            // revisiting before a public release.
            Text(
              '$error',
              style: AuraType.bodySmall.copyWith(color: AuraColors.negative),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
