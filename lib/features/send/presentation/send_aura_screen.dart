import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/aura_user.dart';
import '../../../core/models/friendship.dart';
import '../../../core/models/public_profile.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../auth/application/auth_providers.dart';
import '../../friends/application/friends_providers.dart';
import '../data/aura_api.dart';
import '../../../core/theme/aura_motion.dart';
import '../../../prototype/prototype_runtime.dart';

const _chips = [
  'showed up for me',
  'had my back',
  'made everyone laugh',
  'left me on read',
  'broke a promise',
  'clutch save',
  'main character energy',
  'carried the group project',
  'gave the best advice',
  'certified real one',
  'flaked last minute',
  'ghosted the group chat',
  'forgot my birthday',
];

String _newKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

class SendAuraScreen extends ConsumerStatefulWidget {
  const SendAuraScreen({super.key, this.recipientUid});
  final String? recipientUid;

  @override
  ConsumerState<SendAuraScreen> createState() => _SendAuraScreenState();
}

class _SendAuraScreenState extends ConsumerState<SendAuraScreen> {
  final _reason = TextEditingController();
  final _search = TextEditingController();
  String? _recipientUid;
  String? _chip;
  String _visibility = 'friends';
  int _points = 80;
  bool _sending = false;
  String? _error;
  late String _idempotencyKey = _newKey();

  @override
  void initState() {
    super.initState();
    _recipientUid = widget.recipientUid;
  }

  @override
  void dispose() {
    _reason.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendshipsProvider);
    final me = ref.watch(currentUserProvider).value;
    final myUid = ref.watch(authStateProvider).value?.uid;
    final caps = me?.pointCaps;
    final choices = friends.value?.toList() ?? <Friendship>[];
    final local = ref.watch(prototypeEnabledProvider);
    if (local && myUid != null) {
      final store = ref.watch(prototypeStoreProvider);
      final recent = store.feed.expand((m) => [m.sender, m.recipient]).toList();
      choices.sort((a, b) {
        final aIndex = recent.indexOf(a.otherMember(myUid));
        final bIndex = recent.indexOf(b.otherMember(myUid));
        return (aIndex < 0 ? recent.length : aIndex).compareTo(
          bIndex < 0 ? recent.length : bIndex,
        );
      });
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: Text('send aura', style: AuraType.headingMedium),
      ),
      bottomNavigationBar: me == null || friends is! AsyncData<List<Friendship>>
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: AuraType.bodySmall.copyWith(
                            color: AuraColors.negative,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed:
                          _sending ||
                              _recipientUid == null ||
                              _reason.text.trim().isEmpty ||
                              !me.pointCaps.allows(_points)
                          ? null
                          : () => _send(me),
                      child: Text(_sending ? 'sending…' : 'send aura'),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: switch (friends) {
          AsyncData(value: final List<Friendship> accepted)
              when me != null && myUid != null =>
            ListView(
              padding: const EdgeInsets.all(AuraSpacing.screenPadding),
              children: [
                const AuraIntro(
                  label: 'pass the energy',
                  title: 'make their day.',
                  body: 'Pick a person. Name the moment. Send some aura.',
                ),
                Text('1. pick a friend', style: AuraType.headingMedium),
                const SizedBox(height: AuraSpacing.sm),
                if (accepted.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('add and accept a friend first.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            AppRouter.pushTo(context, AuraRoutes.addFriend),
                        icon: const Icon(Icons.person_add_alt_rounded),
                        label: const Text('find a friend'),
                      ),
                    ],
                  ),
                if (accepted.isNotEmpty) ...[
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'search your friends',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final friendship in choices)
                  _FriendChoice(
                    uid: friendship.otherMember(myUid),
                    selected: _recipientUid == friendship.otherMember(myUid),
                    search: _search.text,
                    onSelected: (uid) => setState(() {
                      _recipientUid = uid;
                      _idempotencyKey = _newKey();
                    }),
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
                        labelStyle: AuraType.bodyStrong.copyWith(
                          color: _chip == chip
                              ? AuraColors.onAction
                              : AuraColors.textPrimary,
                        ),
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
                  decoration: const InputDecoration(
                    labelText: 'or write your own moment',
                  ),
                  onChanged: (_) => setState(() {
                    _chip = null;
                    _idempotencyKey = _newKey();
                  }),
                ),
                const SizedBox(height: AuraSpacing.lg),
                Text('3. points', style: AuraType.headingMedium),
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: _points > 0 ? AuraColors.lime : AuraColors.peach,
                    borderRadius: AuraRadius.cardLargeAll,
                    border: Border.all(color: AuraColors.surfaceBorder),
                  ),
                  child: Text(
                    '${_points > 0 ? '+' : ''}$_points aura',
                    textAlign: TextAlign.center,
                    style: AuraType.scoreLarge.copyWith(
                      color: AuraColors.forPoints(_points),
                    ),
                  ),
                ),
                Slider(
                  label: '${_points > 0 ? '+' : ''}$_points aura',
                  min: caps!.maxNegative.toDouble(),
                  max: caps.maxPositive.toDouble(),
                  value: _points
                      .clamp(caps.maxNegative, caps.maxPositive)
                      .toDouble(),
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
                  onSelectionChanged: (value) => setState(() {
                    _visibility = value.first;
                    _idempotencyKey = _newKey();
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  _visibility == 'private'
                      ? 'Only you and the recipient can see this moment.'
                      : 'This moment is visible to friends.',
                  style: AuraType.bodySmall,
                ),
                const SizedBox(height: AuraSpacing.xl),
                const SizedBox(height: AuraSpacing.xxl),
              ],
            ),
          AsyncError() => const Center(
            child: Text('could not load your friends.'),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _send(AuraUser me) async {
    if (_sending || _recipientUid == null || !me.pointCaps.allows(_points)) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final sentPoints = _points;
    try {
      await ref
          .read(auraApiProvider)
          .send(
            recipientUid: _recipientUid!,
            points: _points,
            reason: _reason.text.trim(),
            visibility: _visibility,
            idempotencyKey: _idempotencyKey,
            chipId: _chip,
          );
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: sentPoints > 0 ? AuraColors.lime : AuraColors.peach,
          title: Text(
            sentPoints > 0 ? 'good energy delivered.' : 'moment delivered.',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .7, end: 1),
                duration: AuraMotion.respecting(context, AuraMotion.burst),
                curve: Curves.easeOutBack,
                builder: (_, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Icon(
                  sentPoints > 0
                      ? Icons.auto_awesome_rounded
                      : Icons.bolt_rounded,
                  size: 72,
                  color: AuraColors.action,
                ),
              ),
              const SizedBox(height: 16),
              Text('${sentPoints > 0 ? '+' : ''}$sentPoints aura'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('aura sent.')));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        AppRouter.replaceWith(context, AuraRoutes.home);
      }
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
  const _FriendChoice({
    required this.uid,
    required this.selected,
    required this.onSelected,
    this.search = '',
  });
  final String uid;
  final bool selected;
  final ValueChanged<String> onSelected;
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(uid));
    if (profile.value != null &&
        !profile.value!.handle.toLowerCase().contains(
          search.trim().toLowerCase(),
        )) {
      return const SizedBox.shrink();
    }
    return switch (profile) {
      AsyncData(value: final PublicProfile friend) => RadioGroup<String>(
        groupValue: selected ? uid : null,
        onChanged: (value) {
          if (value != null) onSelected(value);
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<String>(
            shape: RoundedRectangleBorder(
              borderRadius: AuraRadius.inputAll,
              side: BorderSide(
                color: selected ? AuraColors.action : AuraColors.surfaceBorder,
              ),
            ),
            tileColor: selected ? AuraColors.lilac : AuraColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(friend.handle),
            value: uid,
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
