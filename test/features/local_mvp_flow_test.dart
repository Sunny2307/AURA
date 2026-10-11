import 'dart:io';
import 'dart:ui' as ui;

import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/core/router/app_router.dart';
import 'package:aura/features/feed/presentation/feed_screen.dart';
import 'package:aura/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:aura/features/profile/presentation/local_profile_screen.dart';
import 'package:aura/features/notifications/presentation/local_activity_screen.dart';
import 'package:aura/features/sharing/presentation/aura_export_screen.dart';
import 'package:aura/features/settings/presentation/local_notification_settings.dart';
import 'package:aura/features/send/presentation/send_aura_screen.dart';
import 'package:aura/prototype/prototype_runtime.dart';
import 'package:aura/prototype/prototype_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = await File('assets/fonts/Nunito[wght].ttf').readAsBytes();
    await (FontLoader(
      'Nunito',
    )..addFont(Future.value(ByteData.sublistView(font)))).load();
    final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  });
  late PrototypeStore store;
  Future<void> initialize(WidgetTester tester) async {
    store = PrototypeStore(save: (_) async {});
    await store.openDemo();
    await store.seedMoments();
  }

  Future<void> host(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    bool settle = true,
  }) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox()));
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      prototypeScope(
        store,
        MaterialApp(
          theme: AuraTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 780),
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(key: const Key('capture'), child: child),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '../docs/rain-skill/tasks/evidence/2026-10-11-complete-mvp-frontend/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  testWidgets('feed reaction saves and detail hides after blocking', (
    tester,
  ) async {
    await initialize(tester);
    await host(tester, const FeedScreen());
    expect(find.text('energy in motion.'), findsOneWidget);
    final id = store.feed.first.id;
    final chip = find.byKey(ValueKey('$id-🔥'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(store.feed.first.reactions[store.currentUid], '🔥');
    await host(tester, MomentDetailScreen(id: id));
    expect(find.text('send aura back'), findsOneWidget);
    final block = store.block(store.currentUid!, store.feed.first.sender);
    await tester.pump();
    await block;
    await tester.pumpAndSettle();
    expect(find.text('this moment is no longer available.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('leaderboard displays actual rank and privacy changes', (
    tester,
  ) async {
    await initialize(tester);
    await host(tester, const LeaderboardScreen());
    expect(find.text('@aura_demo'), findsOneWidget);
    expect(find.textContaining('your spot: #1'), findsOneWidget);
    final account = store.user(store.currentUid!)!;
    final privacy = store.privacy(
      account.uid,
      account.privacy.copyWith(appearOnLeaderboards: false),
    );
    await tester.pump();
    await privacy;
    await tester.pumpAndSettle();
    expect(find.text('@aura_demo'), findsNothing);
    expect(find.textContaining('your score is private'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('profile edits bio; large text profile stays scrollable', (
    tester,
  ) async {
    await initialize(tester);
    await host(tester, LocalProfileScreen(uid: store.currentUid!));
    await tester.tap(find.text('edit bio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'good energy only');
    await tester.tap(find.text('save bio'));
    await tester.pumpAndSettle();
    expect(find.text('good energy only'), findsOneWidget);
    await host(tester, LocalProfileScreen(uid: store.currentUid!), scale: 2);
    await tester.scrollUntilVisible(find.text('top moments'), 400);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('activity preferences change new incoming events', (
    tester,
  ) async {
    await initialize(tester);
    await host(tester, const Scaffold(body: LocalNotificationSettings()));
    await tester.tap(find.text('incoming aura'));
    await tester.pumpAndSettle();
    expect(store.preference('transactions'), isFalse);
    await host(tester, const LocalActivityScreen(), scale: 2);
    expect(find.text('someone’s thinking of you.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets(
    'card rendering produces exact Stories dimensions for all templates',
    (tester) async {
      await tester.runAsync(() async {
        for (final template in AuraExportTemplate.values) {
          final bytes = await renderAuraCard(
            handle: '@aura_demo',
            score: 1810,
            template: template,
            moment: 'certified real one',
            points: 200,
            rank: 1,
          );
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 1080);
          expect(frame.image.height, 1920);
          frame.image.dispose();
          codec.dispose();
          final file = File(
            '../docs/rain-skill/tasks/evidence/2026-10-11-complete-mvp-frontend/card-${template.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
        }
      });
    },
  );

  testWidgets(
    'export preview shares PNG and handles cancellation and failure',
    (tester) async {
      await initialize(tester);
      ShareParams? shared;
      var fail = false;
      await host(
        tester,
        ProviderScope(
          overrides: [
            auraCardShareProvider.overrideWithValue((params) async {
              shared = params;
              if (fail) throw StateError('share unavailable');
              return const ShareResult('', ShareResultStatus.dismissed);
            }),
          ],
          child: const AuraExportScreen(),
        ),
        settle: false,
      );
      for (
        var i = 0;
        i < 30 &&
            find.byKey(const Key('aura-export-preview')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const Key('aura-export-preview')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('share card'), 300);
      await tester.tap(find.text('share card'));
      await tester.pumpAndSettle();
      expect(find.text('sharing cancelled.'), findsOneWidget);
      expect(shared!.files!.single.mimeType, 'image/png');
      expect((await shared!.files!.single.readAsBytes()).take(4).toList(), [
        137,
        80,
        78,
        71,
      ]);
      fail = true;
      await tester.tap(find.text('share card'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not export this card'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await store.dispose();
    },
  );

  testWidgets('capture the local frontend screens', (tester) async {
    await initialize(tester);
    for (final entry in <String, Widget>{
      'feed': const FeedScreen(),
      'leaderboard': const LeaderboardScreen(),
      'profile': LocalProfileScreen(uid: store.currentUid!),
      'activity': const LocalActivityScreen(),
    }.entries) {
      await host(tester, entry.value);
      expect(tester.takeException(), isNull);
      await capture(tester, entry.key);
    }
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets(
    'new routes use guarded account access and send-back preselection',
    (tester) async {
      await initialize(tester);
      addTearDown(() async => tester.pumpWidget(const SizedBox()));
      final router = AppRouter.build();
      await tester.pumpWidget(
        prototypeScope(
          store,
          MaterialApp.router(
            theme: AuraTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      router.go(AuraRoutes.momentFor(store.feed.first.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('send aura back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SendAuraScreen>(find.byType(SendAuraScreen)).recipientUid,
        store.feed.first.sender,
      );
      router.go(AuraRoutes.activity);
      await tester.pumpAndSettle();
      final event = store.activity.first;
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(store.activity.firstWhere((e) => e.id == event.id).read, isTrue);
      expect(find.byType(MomentDetailScreen), findsOneWidget);
      router.go(AuraRoutes.localAccounts);
      await tester.pumpAndSettle();
      await tester.tap(find.text('@sam'));
      await tester.pumpAndSettle();
      expect(store.currentUid, 'sample-sam');
      expect(find.text('@sam'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await store.dispose();
      router.dispose();
    },
  );
}
