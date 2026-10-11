import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../auth/application/auth_providers.dart';
import '../../safety/application/safety_providers.dart';
import '../../safety/data/safety_repository.dart';

/// Permanent account deletion, behind a typed confirmation.
///
/// Typed rather than a two-button dialog because this is the only irreversible
/// action in the app and there is no server-side grace period to undo it with.
/// Typing your own handle is a deliberate pause, and it also proves you know
/// which account you are on — which matters for anyone who has signed in and
/// out of more than one.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Re-renders the button's enabled state as they type.
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('delete account', style: AuraType.headingMedium),
      ),
      body: SafeArea(
        child: account == null
            ? const Center(child: CircularProgressIndicator())
            : _form(account),
      ),
    );
  }

  Widget _form(AuraUser account) {
    final matches = _controller.text.trim().toLowerCase() == account.username;

    return ListView(
      padding: const EdgeInsets.all(AuraSpacing.screenPadding),
      children: [
        Text('this cannot be undone.', style: AuraType.headingMedium),
        const SizedBox(height: AuraSpacing.lg),

        // Said plainly, including the part people do not expect. Someone who
        // deletes to free up their handle for a second account needs to know
        // beforehand that it will not work.
        const _Point('your profile, photo and score are deleted.'),
        const _Point('every friendship is removed, for both sides.'),
        const _Point('your blocked list is deleted.'),
        const _Point('your sign-in is deleted. you cannot log back in.'),
        const _Point(
          'your handle is never given to anyone else — and you cannot '
          'reuse it either. it stays reserved forever so nobody can take '
          'it and be mistaken for you.',
          emphasised: true,
        ),

        const SizedBox(height: AuraSpacing.xl),
        Text(
          'type ${account.handle} to confirm',
          style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
        ),
        const SizedBox(height: AuraSpacing.sm),
        TextField(
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_busy,
          decoration: const InputDecoration(prefixText: '@'),
        ),

        const SizedBox(height: AuraSpacing.xl),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AuraTouch.minTarget),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AuraColors.negative,
            ),
            onPressed: matches && !_busy ? () => _delete(account) : null,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('delete my account'),
          ),
        ),
        const SizedBox(height: AuraSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AuraTouch.minTarget),
          child: TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            child: const Text('keep my account'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(AuraUser account) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(accountDeletionServiceProvider)
          .deleteAccount(account.uid);
      if (!mounted) return;
      // Straight to onboarding rather than splash: splash branches on auth
      // state, and the account it would branch on no longer exists.
      AppRouter.replaceWith(context, AuraRoutes.onboarding);
    } on SafetyFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (failure.problem) {
            SafetyProblem.network => 'could not finish deleting. please try again.',
            SafetyProblem.permissionDenied => 'that is not allowed.',
            _ when failure.code == 'recent-login-required' =>
              'sign out and sign back in, then try deleting again.',
            // Deliberately not "nothing was deleted" — by the time an unknown
            // failure surfaces, the Firestore side may already have gone.
            // Telling someone their data is intact when it might not be is the
            // worse error to make.
            _ => 'something went wrong. check your account and try again.',
          }),
        ),
      );
    }
  }
}

class _Point extends StatelessWidget {
  const _Point(this.text, {this.emphasised = false});

  final String text;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: AuraSpacing.sm),
            child: Icon(
              Icons.remove,
              size: 14,
              color: emphasised ? AuraColors.negative : AuraColors.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: emphasised
                  ? AuraType.bodySmall.copyWith(color: AuraColors.textPrimary)
                  : AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
