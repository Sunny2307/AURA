import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/public_profile.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../auth/application/auth_providers.dart';
import '../../friends/application/friends_providers.dart';
import '../../friends/presentation/friend_tile.dart';
import '../../safety/application/safety_providers.dart';
import '../../safety/data/safety_repository.dart';

/// Who you have blocked, and the way back.
///
/// This list is readable by its owner and nobody else — that rule is what makes
/// blocking silent, so there is no equivalent "who has blocked me" screen and
/// there never should be.
class BlockedListScreen extends ConsumerWidget {
  const BlockedListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUidsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: Text('blocked accounts', style: AuraType.headingMedium),
      ),
      body: SafeArea(
        child: switch (blocked) {
          AsyncData(value: final uids) when uids.isEmpty => const _Empty(),
          AsyncData(value: final uids) => ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.sm,
              vertical: AuraSpacing.md,
            ),
            itemCount: uids.length,
            itemBuilder: (context, index) =>
                _BlockedRow(key: ValueKey(uids[index]), uid: uids[index]),
          ),
          AsyncError() => const _Centred('could not load your blocked list.'),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(publicProfileProvider(widget.uid));

    final unblock = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AuraTouch.minTarget),
      child: OutlinedButton(
        onPressed: _busy ? null : _unblock,
        child: const Text('unblock'),
      ),
    );

    return switch (profile) {
      AsyncData(value: final PublicProfile p) => FriendTile(
        profile: p,
        trailing: unblock,
      ),
      // A blocked account that has since deleted itself, or whose profile will
      // not read. The row stays and stays actionable — a block you cannot see
      // is one you cannot lift, and the entry would sit here forever.
      _ => ListTile(
        minVerticalPadding: AuraSpacing.md,
        leading: const SizedBox(
          height: AuraTouch.minTarget,
          width: AuraTouch.minTarget,
          child: Icon(Icons.person_off_outlined),
        ),
        title: Text('someone', style: AuraType.bodyStrong),
        subtitle: Text(
          'this account could not be loaded',
          style: AuraType.caption.copyWith(color: AuraColors.textMuted),
        ),
        trailing: unblock,
      ),
    };
  }

  Future<void> _unblock() async {
    final myUid = ref.read(authStateProvider).value?.uid;
    if (myUid == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .unblock(viewerUid: myUid, blockedUid: widget.uid);
    } on SafetyFailure {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('could not unblock. try again.')),
      );
    } finally {
      // The row is removed from the list the moment the listener fires, which
      // can happen before this returns.
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 64, color: AuraColors.positive),
        SizedBox(height: 20),
        _Centred(
          'nobody blocked.\n\nblocking someone removes them from your friends and '
          'stops them reaching you. they are not told.',
        ),
      ],
    );
  }
}

class _Centred extends StatelessWidget {
  const _Centred(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        child: Text(
          text,
          style: AuraType.bodySmall.copyWith(color: AuraColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
