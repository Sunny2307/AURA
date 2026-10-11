import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../prototype/local_social_providers.dart';
import '../../../prototype/prototype_runtime.dart';
import '../../../shared/widgets/aura_identity.dart';
import '../../feed/presentation/feed_screen.dart';

class LocalActivityScreen extends ConsumerWidget {
  const LocalActivityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localRevisionProvider);
    final store = ref.watch(prototypeStoreProvider);
    final activity = store.activity;
    return Scaffold(
      appBar: AppBar(
        leading: const AuraBackButton(),
        title: const Text('your activity'),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: activity.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  const AuraIntro(
                    label: 'in the loop',
                    title: 'someone’s thinking of you.',
                    body: 'Local demo activity. Remote push notifications come with live integration.',
                  ),
                  if (activity.isEmpty)
                    const Text(
                      'all quiet for now. incoming aura and reactions will show here.',
                    ),
                ],
              );
            }
            final event = activity[index - 1];
            final moment = store.moment(event.momentId)!;
            return Card(
              color: event.read ? AuraColors.surface : AuraColors.lilac,
              child: ListTile(
                leading: Icon(
                  event.kind == 'reactions'
                      ? Icons.favorite_outline
                      : Icons.auto_awesome_rounded,
                ),
                title: Text(
                  event.kind == 'reactions'
                      ? '@${store.profile(event.actor)?.username} reacted to your moment'
                      : '@${store.profile(event.actor)?.username} sent you ${moment.signedPoints} aura',
                ),
                subtitle: Text(
                  '${moment.reason}\n${momentTime(event.at)}${event.read ? '' : ' · unread'}',
                ),
                onTap: () => unawaited(() async {
                  if (await localAction(
                        context,
                        () => store.markRead(event.id),
                      ) &&
                      context.mounted) {
                    AppRouter.pushTo(
                      context,
                      AuraRoutes.momentFor(event.momentId),
                    );
                  }
                }()),
              ),
            );
          },
        ),
      ),
    );
  }
}
