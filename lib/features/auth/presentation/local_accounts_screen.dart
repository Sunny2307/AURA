import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../application/auth_providers.dart';
import '../../feed/presentation/feed_screen.dart';

class LocalAccountsScreen extends ConsumerStatefulWidget {
  const LocalAccountsScreen({super.key});
  @override
  ConsumerState<LocalAccountsScreen> createState() =>
      _LocalAccountsScreenState();
}

class _LocalAccountsScreenState extends ConsumerState<LocalAccountsScreen> {
  bool _busy = false;
  Future<void> _resume(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = ref.read(prototypeStoreProvider);
    if (await localAction(context, () async {
          await store.resume(uid);
          ref.invalidate(authStateProvider);
          await ref.read(authStateProvider.future);
          ref.invalidate(currentUserProvider);
          await ref.read(currentUserProvider.future);
        }) &&
        mounted) {
      AppRouter.replaceWith(context, AuraRoutes.home);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localRevisionProvider);
    final accounts = ref.watch(prototypeStoreProvider).accounts;
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: const Text('return to your demo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AuraIntro(
              label: 'welcome back',
              title: 'your energy is still here.',
              body: 'Choose an account saved on this device. Local demo access is passwordless. Live sign-in and recovery email come later.',
            ),
            for (final account in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(_resume(account.uid)),
                  child: Text(account.handle),
                ),
              ),
            if (accounts.isEmpty)
              const Text('no saved accounts yet. create one to get started.'),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => AppRouter.pushTo(context, AuraRoutes.signup),
              child: const Text('create a local account'),
            ),
          ],
        ),
      ),
    );
  }
}
