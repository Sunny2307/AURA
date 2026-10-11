import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../prototype/local_social_providers.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../feed/presentation/feed_screen.dart';

class LocalNotificationSettings extends ConsumerStatefulWidget {
  const LocalNotificationSettings({super.key});
  @override
  ConsumerState<LocalNotificationSettings> createState() =>
      _LocalNotificationSettingsState();
}

class _LocalNotificationSettingsState
    extends ConsumerState<LocalNotificationSettings> {
  bool _busy = false;
  Future<void> _save(String kind, bool value) async {
    setState(() => _busy = true);
    await localAction(
      context,
      () => ref.read(prototypeStoreProvider).setPreference(kind, value),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Local activity only. These settings control new inbox items; remote push comes later.',
          ),
        ),
        SwitchListTile(
          title: const Text('incoming aura'),
          value: store.preference('transactions'),
          onChanged: _busy ? null : (v) => _save('transactions', v),
        ),
        SwitchListTile(
          title: const Text('reactions to your moments'),
          value: store.preference('reactions'),
          onChanged: _busy ? null : (v) => _save('reactions', v),
        ),
      ],
    );
  }
}
