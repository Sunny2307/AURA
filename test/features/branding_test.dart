import 'dart:io';
import 'dart:ui' as ui;

import 'package:aura/app.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/features/onboarding/presentation/onboarding_screen.dart';
import 'package:aura/features/sharing/presentation/aura_export_screen.dart';
import 'package:aura/prototype/prototype_runtime.dart';
import 'package:aura/prototype/prototype_store.dart';
import 'package:aura/shared/widgets/aura_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('branding-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../design/branding/evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

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
  testWidgets('approved logo loads on splash, home, dock and onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = PrototypeStore(save: (_) async {});
    await store.openDemo();
    await tester.pumpWidget(
      prototypeScope(
        store,
        const RepaintBoundary(key: Key('branding-capture'), child: AuraApp()),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(AuraLogo.assetPath),
        tester.element(find.byType(AuraLogo).first),
      );
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AuraLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'splash');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(AuraLogo), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await capture(tester, 'home');
    await tester.pumpWidget(
      MaterialApp(
        theme: AuraTheme.light,
        home: const RepaintBoundary(
          key: Key('branding-capture'),
          child: OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AuraLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'onboarding');
    await tester.pumpWidget(const SizedBox());
    await store.dispose();
  });

  testWidgets('all exported templates contain the approved logo', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final template in AuraExportTemplate.values) {
        final bytes = await renderAuraCard(
          handle: '@maya',
          score: 1200,
          template: template,
          moment: 'had my back',
          points: 50,
          rank: 2,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(image.width, 1080);
        expect(image.height, 1920);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        // A pixel inside the logo tile's top edge must be violet, not the lilac card.
        const offset = (140 * 1080 + 540) * 4;
        expect(pixels.getUint8(offset), inInclusiveRange(70, 110));
        expect(pixels.getUint8(offset + 1), inInclusiveRange(45, 90));
        expect(pixels.getUint8(offset + 2), inInclusiveRange(160, 205));
        image.dispose();
        final file = File(
          '../design/branding/evidence/export-${template.name}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
    });
  });
}
