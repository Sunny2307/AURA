import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/report_reason.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../prototype/local_moment.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/aura_card.dart';
import '../../../shared/widgets/aura_identity.dart';

Future<bool> localAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('could not save that change. try again.')),
      );
    }
    return false;
  }
}

String momentTime(DateTime at) {
  final age = DateTime.now().difference(at);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  return '${at.day}/${at.month}/${at.year}';
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _limit = 20;
  bool _mine = false;
  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final moments = store.feed
        .where(
          (m) =>
              !_mine ||
              m.sender == store.currentUid ||
              m.recipient == store.currentUid,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: const Text('the aura feed'),
      ),
      body: SafeArea(
        child: revision.hasError
            ? Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(localRevisionProvider),
                  child: const Text('retry feed'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(localRevisionProvider);
                  setState(() => _limit = 20);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount:
                      2 +
                      moments.take(_limit).length +
                      (moments.length > _limit ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuraIntro(
                            label: 'moments that matter',
                            title: 'energy in motion.',
                            body: 'The wins. The fails. Your people, keeping score.',
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('circle'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('just mine'),
                              ),
                            ],
                            selected: {_mine},
                            onSelectionChanged: (v) =>
                                setState(() => _mine = v.first),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }
                    if (index == 1) {
                      return moments.isEmpty
                          ? const FeedEmpty()
                          : const SizedBox.shrink();
                    }
                    final offset = index - 2;
                    if (offset >= _limit) {
                      return TextButton(
                        onPressed: () => setState(() => _limit += 20),
                        child: const Text('load more moments'),
                      );
                    }
                    return MomentCard(moment: moments[offset]);
                  },
                ),
              ),
      ),
    );
  }
}

class FeedEmpty extends ConsumerWidget {
  const FeedEmpty({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AuraCard(
    color: AuraColors.lime,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 40),
        const SizedBox(height: 12),
        Text('your next moment starts here.', style: AuraType.headingMedium),
        const Text(
          'Send aura to a friend, or add sample moments to explore the local demo.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => AppRouter.pushTo(context, AuraRoutes.sendAura),
          child: const Text('send some aura'),
        ),
        TextButton(
          onPressed: () => unawaited(
            localAction(context, ref.read(prototypeStoreProvider).seedMoments),
          ),
          child: const Text('add sample moments'),
        ),
      ],
    ),
  );
}

class MomentCard extends ConsumerStatefulWidget {
  const MomentCard({super.key, required this.moment, this.details = false});
  final LocalMoment moment;
  final bool details;
  @override
  ConsumerState<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends ConsumerState<MomentCard> {
  bool _busy = false;
  Future<void> _react(String emoji) async {
    if (_busy) return;
    setState(() => _busy = true);
    await localAction(
      context,
      () => ref.read(prototypeStoreProvider).react(widget.moment.id, emoji),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('report this moment', style: AuraType.headingMedium),
                const Text(
                  'This local demo saves the report and blocks the other account. No moderation team receives it.',
                ),
                for (final r in ReportReason.values)
                  ListTile(
                    title: Text(r.label),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (reason != null && mounted) {
      await localAction(
        context,
        () => ref
            .read(prototypeStoreProvider)
            .reportMoment(widget.moment.id, reason.wireValue),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final m = store.moment(widget.moment.id);
    if (m == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AuraCard(
        color: m.points > 0
            ? AuraColors.lime.withValues(alpha: .45)
            : AuraColors.peach.withValues(alpha: .55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  '@${store.profile(m.sender)?.username ?? 'friend'}',
                  style: AuraType.bodyStrong,
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16),
                Text(
                  '@${store.profile(m.recipient)?.username ?? 'friend'}',
                  style: AuraType.bodyStrong,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${m.signedPoints} aura',
              style: AuraType.scoreLarge.copyWith(
                color: AuraColors.forPoints(m.points),
              ),
            ),
            const SizedBox(height: 8),
            Text(m.reason, style: AuraType.bodyStrong),
            const SizedBox(height: 8),
            Text(
              '${momentTime(m.at)} · ${m.visibility == 'private' ? 'just us' : 'friends'}',
              style: AuraType.caption,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final emoji in ['💀', '🔥', '😭', '👑', '☠️'])
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: FilterChip(
                      key: ValueKey('${m.id}-$emoji'),
                      label: Text(
                        '$emoji ${m.reactions.values.where((v) => v == emoji).length}',
                      ),
                      tooltip: 'react $emoji',
                      selected: m.reactions[store.currentUid] == emoji,
                      onSelected: _busy
                          ? null
                          : (_) => unawaited(_react(emoji)),
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                if (!widget.details)
                  TextButton(
                    onPressed: () =>
                        AppRouter.pushTo(context, AuraRoutes.momentFor(m.id)),
                    child: const Text('view moment'),
                  ),
                if (widget.details)
                  TextButton(
                    onPressed: () => AppRouter.pushTo(
                      context,
                      '${AuraRoutes.sendAura}?to=${Uri.encodeQueryComponent(m.sender == store.currentUid ? m.recipient : m.sender)}',
                    ),
                    child: const Text('send aura back'),
                  ),
                TextButton(
                  onPressed: _busy ? null : _report,
                  child: const Text('report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MomentDetailScreen extends ConsumerWidget {
  const MomentDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final moment = ref.watch(prototypeStoreProvider).moment(id);
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: const Text('the moment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (moment == null)
              const Text('this moment is no longer available.')
            else
              MomentCard(moment: moment, details: true),
          ],
        ),
      ),
    );
  }
}
