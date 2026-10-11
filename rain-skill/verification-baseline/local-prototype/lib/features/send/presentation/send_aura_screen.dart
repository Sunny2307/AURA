import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/models/friendship.dart';
import '../../../core/models/public_profile.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../auth/application/auth_providers.dart';
import '../../friends/application/friends_providers.dart';
import '../data/aura_api.dart';

const _chips = [
  'showed up for me', 'had my back', 'made everyone laugh',
  'left me on read', 'broke a promise',
];

String _newKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

class SendAuraScreen extends ConsumerStatefulWidget {
  const SendAuraScreen({super.key});

  @override
  ConsumerState<SendAuraScreen> createState() => _SendAuraScreenState();
}

class _SendAuraScreenState extends ConsumerState<SendAuraScreen> {
  final _reason = TextEditingController();
  String? _recipientUid;
  String? _chip;
  String _visibility = 'friends';
  int _points = 80;
  bool _sending = false;
  String? _error;
  late String _idempotencyKey = _newKey();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendshipsProvider);
    final me = ref.watch(currentUserProvider).value;
    final myUid = ref.watch(authStateProvider).value?.uid;
    final caps = me?.pointCaps;
    return Scaffold(
      appBar: AppBar(title: Text('send aura', style: AuraType.headingMedium)),
      body: SafeArea(
        child: switch (friends) {
          AsyncData(value: final List<Friendship> accepted) when me != null && myUid != null =>
            ListView(
              padding: const EdgeInsets.all(AuraSpacing.screenPadding),
              children: [
                Text('1. pick a friend', style: AuraType.headingMedium),
                const SizedBox(height: AuraSpacing.sm),
                if (accepted.isEmpty) const Text('add and accept a friend first.'),
                for (final friendship in accepted)
                  _FriendChoice(
                    uid: friendship.otherMember(myUid),
                    selected: _recipientUid == friendship.otherMember(myUid),
                    onSelected: (uid) => setState(() { _recipientUid = uid; _idempotencyKey = _newKey(); }),
                  ),
                const SizedBox(height: AuraSpacing.xl),
                Text('2. what happened?', style: AuraType.headingMedium),
                const SizedBox(height: AuraSpacing.sm),
                Wrap(
                  spacing: AuraSpacing.sm,
                  runSpacing: AuraSpacing.sm,
                  children: [
                    for (final chip in _chips)
                      ChoiceChip(
                        label: Text(chip),
                        selected: _chip == chip,
                        onSelected: (_) => setState(() {
                          _chip = chip;
                          _reason.text = chip;
                          _idempotencyKey = _newKey();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AuraSpacing.md),
                TextField(
                  controller: _reason,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'or write your own moment'),
                  onChanged: (_) => setState(() { _chip = null; _idempotencyKey = _newKey(); }),
                ),
                const SizedBox(height: AuraSpacing.lg),
                Text('3. points', style: AuraType.headingMedium),
                Text(
                  '${_points > 0 ? '+' : ''}$_points aura',
                  style: AuraType.scoreSmall.copyWith(color: AuraColors.forPoints(_points)),
                ),
                Slider(
                  min: caps!.maxNegative.toDouble(),
                  max: caps.maxPositive.toDouble(),
                  value: _points.clamp(caps.maxNegative, caps.maxPositive).toDouble(),
                  onChanged: (value) => setState(() {
                    final next = value.round();
                    _points = next == 0 ? 1 : next;
                    _idempotencyKey = _newKey();
                  }),
                ),
                const SizedBox(height: AuraSpacing.lg),
                Text('4. who sees it?', style: AuraType.headingMedium),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'private', label: Text('just us')),
                    ButtonSegment(value: 'friends', label: Text('friends')),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (value) => setState(() { _visibility = value.first; _idempotencyKey = _newKey(); }),
                ),
                const SizedBox(height: AuraSpacing.xl),
                if (_error != null) ...[
                  Text(_error!, style: AuraType.bodySmall.copyWith(color: AuraColors.negative)),
                  const SizedBox(height: AuraSpacing.md),
                ],
                FilledButton(
                  onPressed: _sending || _recipientUid == null || _reason.text.trim().isEmpty
                      ? null
                      : () => _send(me),
                  child: Text(_sending ? 'sending…' : 'send aura'),
                ),
                const SizedBox(height: AuraSpacing.xxl),
              ],
            ),
          AsyncError() => const Center(child: Text('could not load your friends.')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _send(AuraUser me) async {
    if (_sending || _recipientUid == null || !me.pointCaps.allows(_points)) return;
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(auraApiProvider).send(
        recipientUid: _recipientUid!, points: _points, reason: _reason.text.trim(),
        visibility: _visibility, idempotencyKey: _idempotencyKey, chipId: _chip,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('aura sent.')));
      Navigator.of(context).pop();
    } on AuraApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'could not send aura. try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _FriendChoice extends ConsumerWidget {
  const _FriendChoice({required this.uid, required this.selected, required this.onSelected});
  final String uid;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(uid));
    return switch (profile) {
      AsyncData(value: final PublicProfile friend) => RadioGroup<String>(
        groupValue: selected ? uid : null,
        onChanged: (value) { if (value != null) onSelected(value); },
        child: RadioListTile<String>(
          title: Text(friend.handle),
          value: uid,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
