import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/user_repository.dart';
import '../../safety/application/safety_providers.dart';

/// Privacy and safety settings — spec §5.11.
///
/// Deliberately has **no notification toggles**. Push is Slice 7 and is blocked
/// on the Blaze plan, so the switches would be real controls writing fields
/// nothing reads. A dead switch teaches people that the settings screen lies,
/// which costs more than the missing row.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text('settings', style: AuraType.headingMedium)),
      body: SafeArea(
        child: switch (user) {
          AsyncData(value: final AuraUser account) => _Body(
            account: account,
            busy: _busy,
            onPrivacyChanged: (privacy) => _save(account, privacy),
          ),
          AsyncError() => const _Message('could not load your settings.'),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _save(AuraUser account, AuraPrivacy privacy) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updatePrivacy(uid: account.uid, privacy: privacy);
    } on AccountFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (failure.problem) {
            AccountProblem.network => 'no connection. not saved.',
            AccountProblem.permissionDenied => 'that change is not allowed.',
            _ => 'could not save that.',
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.account,
    required this.busy,
    required this.onPrivacyChanged,
  });

  final AuraUser account;
  final bool busy;
  final ValueChanged<AuraPrivacy> onPrivacyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedCount = ref.watch(blockedUidsProvider).value?.length ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AuraSpacing.md),
      children: [
        const _Heading('who can send you aura'),
        // `RadioGroup` rather than per-tile `groupValue`/`onChanged`, which
        // Flutter deprecated after 3.32.
        RadioGroup<WhoCanSendAura>(
          groupValue: account.privacy.whoCanSendAura,
          // `RadioGroup.onChanged` is non-nullable, so "disabled while saving"
          // is a no-op rather than a null callback. The tiles stay tappable and
          // the tap does nothing, which for a write that takes a moment is
          // better than them going grey and back.
          onChanged: (value) {
            if (busy || value == null) return;
            onPrivacyChanged(account.privacy.copyWith(whoCanSendAura: value));
          },
          child: Column(
            children: [
              for (final option in WhoCanSendAura.values)
                RadioListTile<WhoCanSendAura>(
                  value: option,
                  title: Text(_labelFor(option), style: AuraType.body),
                  subtitle: Text(
                    _explanationFor(option),
                    style: AuraType.caption.copyWith(
                      color: AuraColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AuraSpacing.lg),
        const _Heading('visibility'),
        SwitchListTile(
          value: account.privacy.appearOnLeaderboards,
          // Locked, not hidden, for minors. Hiding it would leave a 16-year-old
          // unable to tell whether they are on a leaderboard; showing it
          // unlocked would let them flip a control the server will refuse.
          onChanged: busy || account.isMinor
              ? null
              : (value) => onPrivacyChanged(
                  account.privacy.copyWith(appearOnLeaderboards: value),
                ),
          title: Text('appear on leaderboards', style: AuraType.body),
          subtitle: Text(
            account.isMinor
                ? 'off for under-18 accounts, and not changeable.'
                : 'turn this off to stay off every public leaderboard.',
            style: AuraType.caption.copyWith(color: AuraColors.textMuted),
          ),
        ),

        const SizedBox(height: AuraSpacing.lg),
        const _Heading('safety'),
        ListTile(
          onTap: () => AppRouter.pushTo(context, AuraRoutes.blockedList),
          title: Text('blocked accounts', style: AuraType.body),
          subtitle: Text(
            blockedCount == 1 ? '1 account' : '$blockedCount accounts',
            style: AuraType.caption.copyWith(color: AuraColors.textMuted),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),

        const SizedBox(height: AuraSpacing.xl),
        const _Heading('account'),
        ListTile(
          onTap: () => AppRouter.pushTo(context, AuraRoutes.deleteAccount),
          title: Text(
            'delete my account',
            style: AuraType.body.copyWith(color: AuraColors.negative),
          ),
          subtitle: Text(
            'permanent. there is no undo.',
            style: AuraType.caption.copyWith(color: AuraColors.textMuted),
          ),
        ),
        const SizedBox(height: AuraSpacing.xxl),
      ],
    );
  }

  String _labelFor(WhoCanSendAura option) => switch (option) {
    WhoCanSendAura.everyone => 'everyone',
    WhoCanSendAura.friends => 'friends only',
    WhoCanSendAura.nobody => 'nobody',
  };

  String _explanationFor(WhoCanSendAura option) => switch (option) {
    WhoCanSendAura.everyone => 'anyone who knows your handle.',
    WhoCanSendAura.friends => 'only people you have accepted.',
    // Worth saying plainly: this setting currently gates friend requests too,
    // which is not obvious from its name.
    WhoCanSendAura.nobody => 'nobody at all. also stops new friend requests.',
  };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.screenPadding,
        AuraSpacing.md,
        AuraSpacing.screenPadding,
        AuraSpacing.sm,
      ),
      child: Text(
        text,
        style: AuraType.label.copyWith(color: AuraColors.textMuted),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        child: Text(
          text,
          style: AuraType.body.copyWith(color: AuraColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
