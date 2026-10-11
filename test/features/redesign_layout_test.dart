import 'dart:io';
import 'dart:ui' as ui;

import 'package:aura/app.dart';
import 'package:aura/core/router/app_router.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/shared/widgets/aura_identity.dart';
import 'package:aura/features/home/presentation/home_screen.dart';
import 'package:aura/features/friends/presentation/friends_screen.dart';
import 'package:aura/features/friends/presentation/add_friend_screen.dart';
import 'package:aura/features/send/presentation/send_aura_screen.dart';
import 'package:aura/prototype/prototype_runtime.dart';
import 'package:aura/prototype/prototype_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _capture = Key('redesign-capture');

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '../docs/rain-skill/tasks/evidence/2026-10-11-compact-five-icon-dock/$name.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'dock announces selection and exposes an accessible send action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var sends = 0;
      Widget host(VoidCallback? onSend) => MaterialApp(
        theme: AuraTheme.light,
        home: Scaffold(
          bottomNavigationBar: AuraNavigation(selected: 1, onSend: onSend),
        ),
      );
      await tester.pumpWidget(host(() => sends++));
      final people = tester.getSemantics(find.byKey(const Key('dock-people')));
      expect(people.flagsCollection.isSelected, ui.Tristate.isTrue);
      final send = tester.getSemantics(find.byKey(const Key('dock-send')));
      expect(send.label, 'send aura');
      expect(send.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
      await tester.tap(find.byKey(const Key('dock-send')));
      expect(sends, 1);
      await tester.pumpWidget(host(null));
      final disabled = tester.getSemantics(find.byKey(const Key('dock-send')));
      expect(disabled.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(
        disabled.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    },
  );
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = await File('assets/fonts/Nunito[wght].ttf').readAsBytes();
    await (FontLoader(
      'Nunito',
    )..addFont(Future.value(ByteData.sublistView(font)))).load();
    final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  });

  for (final scale in [1.3, 2.0]) {
    for (final width in [360.0, 600.0, 1200.0]) {
      testWidgets(
        'main destinations and send stay usable at ${width.toInt()}px and ${scale}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = PrototypeStore(save: (_) async {});
          await store.openDemo();
          await tester.pumpWidget(prototypeScope(store, const AuraApp()));
          await _advance(tester);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('dock-send')), findsOneWidget);
          final dock = tester.getRect(find.byKey(const Key('floating-dock')));
          expect(dock.left, greaterThan(0));
          expect(dock.right, lessThan(width));
          expect(dock.height, 64);
          expect(find.text('Aura'), findsNothing);
          expect(find.text('People'), findsNothing);
          final circle = tester.getRect(
            find.byKey(const Key('dock-send-circle')),
          );
          expect(circle.center.dx, closeTo(dock.center.dx, 0.01));
          expect(circle.center.dy, closeTo(dock.center.dy, 0.01));
          for (final item in [
            'aura',
            'people',
            'send',
            'discover',
            'settings',
          ]) {
            final size = tester.getSize(find.byKey(Key('dock-$item')));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          await tester.tap(find.byKey(const Key('dock-discover')));
          await _advance(tester);
          expect(find.byType(AddFriendScreen), findsOneWidget);
          await tester.tap(find.byTooltip('go back'));
          await _advance(tester);
          expect(find.byType(HomeScreen), findsOneWidget);
          await tester.tap(find.byKey(const Key('dock-people')));
          await _advance(tester);
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getRect(find.byType(FloatingActionButton))
                .overlaps(
                  tester.getRect(find.byKey(const Key('floating-dock'))),
                ),
            isFalse,
          );
          await tester.tap(find.byKey(const Key('dock-send')));
          await _advance(tester);
          expect(find.byType(SendAuraScreen), findsOneWidget);
          await tester.tap(find.byTooltip('go back'));
          await _advance(tester);
          expect(find.byType(FriendsScreen), findsOneWidget);
          await tester.tap(find.byKey(const Key('dock-settings')));
          await _advance(tester);
          expect(find.text('your aura.\nyour rules.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('dock-send')));
          await _advance(tester);
          expect(find.byType(SendAuraScreen), findsOneWidget);
          await tester.tap(find.byTooltip('go back'));
          await _advance(tester);
          expect(find.text('your aura.\nyour rules.'), findsOneWidget);
          await tester.tap(find.byKey(const Key('dock-aura')));
          await _advance(tester);
          await tester.tap(find.byKey(const Key('dock-send')));
          await _advance(tester);
          expect(find.byType(SendAuraScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          final submit = find.widgetWithText(FilledButton, 'send aura');
          expect(tester.getRect(submit).bottom, lessThanOrEqualTo(900));
          expect(tester.widget<FilledButton>(submit).onPressed, isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 320);
          await tester.pump();
          expect(tester.getRect(submit).bottom, lessThanOrEqualTo(580));
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pump();
          await tester.scrollUntilVisible(
            find.byType(SegmentedButton<String>),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await store.dispose();
        },
      );
    }
  }

  testWidgets('render redesigned screens and keyboard-safe discovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PrototypeStore(save: (_) async {});
    await tester.pumpWidget(
      prototypeScope(
        store,
        const RepaintBoundary(key: _capture, child: AuraApp()),
      ),
    );
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'onboarding');
    await tester.tap(find.text('demo controls'));
    await _advance(tester);
    expect(find.text('reset prototype'), findsOneWidget);
    await tester.tap(find.text('reset prototype'));
    await _advance(tester);
    expect(find.text('reset prototype?'), findsOneWidget);
    await tester.tap(find.text('cancel'));
    await _advance(tester);
    await tester.tapAt(const Offset(10, 100));
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('try the demo'));
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'home');
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    await tester.tap(find.byKey(const Key('dock-people')));
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'friends');
    router.go(AuraRoutes.settings);
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'settings');
    router.go(AuraRoutes.home);
    await _advance(tester);
    await tester.tap(find.byKey(const Key('dock-send')));
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'send');
    await tester.tap(find.text('@sam'));
    await tester.tap(find.text('showed up for me'));
    await tester.scrollUntilVisible(
      find.byType(SegmentedButton<String>),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'send-detail');
    await tester.tap(find.widgetWithText(FilledButton, 'send aura'));
    await _advance(tester);
    expect(store.user('sample-sam')!.score, 1080);
    expect(find.text('good energy delivered.'), findsOneWidget);
    await tester.tap(find.text('continue'));
    await _advance(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    router.go(AuraRoutes.addFriend);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'jordan');
    await tester.ensureVisible(find.text('look up'));
    await tester.tap(find.text('look up'));
    tester.view.resetViewInsets();
    await _advance(tester);
    expect(find.text('@jordan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'discovery');
    router.go(AuraRoutes.profileFor('jordan'));
    await _advance(tester);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'profile');
    await tester.tap(find.byTooltip('go back'));
    await _advance(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('signup remains reachable with a keyboard and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    final store = PrototypeStore(save: (_) async {});
    await tester.pumpWidget(prototypeScope(store, const AuraApp()));
    await _advance(tester);
    await tester.tap(find.text('skip'));
    await _advance(tester);
    for (final input in [
      'test@aura.test',
      'NiceDay!420',
      '2000',
      'vibe_check',
    ]) {
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField).first, input);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.tap(find.text('continue'));
      await _advance(tester);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('that is everything.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('point range'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });
}
