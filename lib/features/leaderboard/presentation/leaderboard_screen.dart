import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../../shared/widgets/aura_card.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final people = store.leaderboard;
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: const Text('friends leaderboard'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AuraCard(
          color: AuraColors.lilac,
          child: Text(
            store.rank == null
                ? 'your score is private · you are not ranked'
                : 'your spot: #${store.rank} · ${store.user(store.currentUid!)!.score} aura',
            style: AuraType.bodyStrong,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: people.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuraIntro(
                    label: 'friendly competition',
                    title: 'who’s got the energy?',
                    body: 'Your circle. Ranked by aura. Private accounts stay off this list.',
                  ),
                  if (people.isEmpty)
                    const Text('no rankings yet. invite your people to start.'),
                ],
              );
            }
            final person = people[index - 1];
            final change = store.changeSince(
              person.uid,
              DateTime.now().subtract(const Duration(days: 1)),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AuraCard(
                color: person.uid == store.currentUid
                    ? AuraColors.lilac
                    : index <= 3
                    ? AuraColors.lime
                    : AuraColors.surface,
                onTap: () => AppRouter.pushTo(
                  context,
                  AuraRoutes.localProfileFor(person.uid),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        index <= 3 ? ['🥇', '🥈', '🥉'][index - 1] : '#$index',
                        style: AuraType.bodyStrong,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(person.handle, style: AuraType.bodyStrong),
                          Text(
                            '${change >= 0 ? '+' : ''}$change in 24h',
                            style: AuraType.caption,
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${person.score}',
                        style: AuraType.headingMedium,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
