import 'package:aura/app.dart';
import 'package:aura/core/models/friendship.dart';
import 'package:aura/core/router/app_router.dart';
import 'package:aura/features/auth/application/auth_providers.dart';
import 'package:aura/features/friends/application/friends_providers.dart';
import 'package:aura/features/safety/application/safety_providers.dart';
import 'package:aura/features/send/data/aura_api.dart';
import 'package:aura/prototype/prototype_runtime.dart';
import 'package:aura/prototype/prototype_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prototype boots and opens demo without initializing Firebase', (
    tester,
  ) async {
    final store = PrototypeStore(save: (_) async {});
    await tester.pumpWidget(prototypeScope(store, const AuraApp()));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('try the demo'), findsOneWidget);
    await tester.tap(find.text('try the demo'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('@aura_demo'), findsWidgets);
    await tester.scrollUntilVisible(find.text('local prototype'), 300);
    expect(find.text('local prototype'), findsOneWidget);
    expect(find.byKey(const Key('dock-send')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('all repository providers are local and updates reach home', (
    tester,
  ) async {
    final store = PrototypeStore(save: (_) async {});
    await store.openDemo();
    await tester.pumpWidget(prototypeScope(store, const AuraApp()));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    final element = tester.element(find.byKey(const Key('dock-send')));
    final container = ProviderScope.containerOf(element);
    expect(container.read(authRepositoryProvider), isA<LocalAuth>());
    expect(container.read(userRepositoryProvider), isA<LocalUsers>());
    expect(
      container.read(publicProfileRepositoryProvider),
      isA<LocalProfiles>(),
    );
    expect(container.read(friendshipRepositoryProvider), isA<LocalFriends>());
    expect(container.read(safetyRepositoryProvider), isA<LocalSafety>());
    expect(
      container.read(accountDeletionServiceProvider),
      isA<LocalDeletion>(),
    );
    expect(container.read(auraApiProvider), isA<LocalAura>());
    await container
        .read(auraApiProvider)
        .send(
          recipientUid: 'sample-sam',
          points: 80,
          reason: 'had my back',
          visibility: 'friends',
          idempotencyKey: 'test',
        );
    expect(store.user('sample-sam')!.score, 1080);
    await store.resume('sample-sam');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1080'), findsOneWidget);
    AppRouter.pushTo(element, AuraRoutes.friends);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      store.friends('sample-sam', FriendshipStatus.accepted),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });
}
