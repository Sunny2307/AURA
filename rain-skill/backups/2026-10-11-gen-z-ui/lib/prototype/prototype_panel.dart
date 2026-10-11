import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/aura_spacing.dart';
import '../features/auth/application/auth_providers.dart';
import 'prototype_runtime.dart';

class PrototypePanel extends ConsumerStatefulWidget {
  const PrototypePanel({super.key, this.compact = false});
  final bool compact;
  @override
  ConsumerState<PrototypePanel> createState() => _PrototypePanelState();
}

class _PrototypePanelState extends ConsumerState<PrototypePanel> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, String route) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // Wait for the provider graph to observe the changed session/profile.
      ref.invalidate(authStateProvider);
      await ref.read(authStateProvider.future);
      ref.invalidate(currentUserProvider);
      await ref.read(currentUserProvider.future);
      if (mounted) AppRouter.replaceWith(context, route);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'could not save the prototype change. try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('reset prototype?'),
        content: const Text(
          'Removes saved demo accounts, photos, scores and actions. You can start again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => resetPrototype(ref.read(prototypeStoreProvider)),
        AuraRoutes.onboarding,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(prototypeEnabledProvider)) return const SizedBox.shrink();
    final store = ref.watch(prototypeStoreProvider);
    ref.watch(currentUserProvider);
    return StreamBuilder<void>(
      stream: store.watch(() {}),
      builder: (context, _) {
        final history = store.history;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'local prototype',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Saved on this device. Use demo details; nothing is sent online.',
                ),
                if (!widget.compact)
                  const Text(
                    'Search @jordan to send a request. @alex has an incoming request.',
                  ),
                if (store.currentUid == null)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(store.openDemo, AuraRoutes.home),
                    child: const Text('try the demo'),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey(store.currentUid),
                  initialValue: store.currentUid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'view as / return to demo account',
                  ),
                  items: [
                    for (final account in store.accounts)
                      DropdownMenuItem(
                        value: account.uid,
                        child: Text(account.handle),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (uid) {
                          if (uid != null) {
                            unawaited(
                              _run(() => store.resume(uid), AuraRoutes.home),
                            );
                          }
                        },
                ),
                if (!widget.compact && store.currentUid != null) ...[
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => AppRouter.pushTo(context, AuraRoutes.photo),
                    child: const Text('change profile photo'),
                  ),
                  const SizedBox(height: AuraSpacing.sm),
                  const Text('recent local aura'),
                  if (history.isEmpty)
                    const Text(
                      'Send aura, then switch to the recipient to see their score.',
                    ),
                  for (final send in history.take(5))
                    Text(
                      '${store.profile(send['sender'] as String)?.handle ?? 'deleted'} → '
                      '${store.profile(send['recipient'] as String)?.handle ?? 'deleted'}: '
                      '${(send['points'] as int) > 0 ? '+' : ''}${send['points']} · ${send['reason']}',
                    ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TextButton(
                  onPressed: _busy ? null : _reset,
                  child: Text(_busy ? 'saving…' : 'reset prototype'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
