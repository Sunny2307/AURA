import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/aura_card.dart';
import '../../feed/presentation/feed_screen.dart';

class LocalHomeActions extends ConsumerWidget {
  const LocalHomeActions({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final unread = store.activity.where((e) => !e.read).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: unread == 0 ? 'your activity' : '$unread unread activities',
          onPressed: () => AppRouter.pushTo(context, AuraRoutes.activity),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        IconButton(
          tooltip: 'your profile',
          onPressed: store.currentUid == null
              ? null
              : () => AppRouter.pushTo(
                  context,
                  AuraRoutes.localProfileFor(store.currentUid!),
                ),
          icon: const Icon(Icons.person_outline_rounded),
        ),
      ],
    );
  }
}

class LocalHomeExtras extends ConsumerWidget {
  const LocalHomeExtras({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final uid = store.currentUid;
    if (uid == null) return const SizedBox.shrink();
    final change = store.changeSince(
      uid,
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final moments = store.feed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        AuraCard(
          color: AuraColors.lime,
          onTap: () => AppRouter.pushTo(context, AuraRoutes.leaderboard),
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.rank == null
                        ? 'unranked'
                        : '#${store.rank} in your circle',
                    style: AuraType.bodyStrong,
                  ),
                  const Text('friends leaderboard →'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${change >= 0 ? '+' : ''}$change aura',
                    style: AuraType.bodyStrong,
                  ),
                  const Text('last 7 days'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('your circle lately', style: AuraType.headingMedium),
            ),
            TextButton(
              onPressed: () => AppRouter.pushTo(context, AuraRoutes.feed),
              child: const Text('view feed'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (moments.isEmpty) const FeedEmpty(),
        for (final m in moments.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AuraCard(
              color: m.points > 0 ? AuraColors.lime : AuraColors.peach,
              onTap: () =>
                  AppRouter.pushTo(context, AuraRoutes.momentFor(m.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${store.profile(m.sender)?.username} → @${store.profile(m.recipient)?.username}',
                    style: AuraType.bodyStrong,
                  ),
                  const SizedBox(height: 8),
                  Text('${m.signedPoints} aura · ${m.reason}'),
                  const SizedBox(height: 8),
                  Text(momentTime(m.at), style: AuraType.caption),
                ],
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => AppRouter.pushTo(context, AuraRoutes.exportCard),
          icon: const Icon(Icons.ios_share),
          label: const Text('make your Aura Card'),
        ),
      ],
    );
  }
}
