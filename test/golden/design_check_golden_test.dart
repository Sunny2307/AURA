import 'dart:io';

import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/features/dev/design_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the whole design system to a PNG so it can be *looked at*, not just
/// asserted about.
///
/// Regenerate after any theme change:
///
///   flutter test test/golden/design_check_golden_test.dart --update-goldens
///
/// Then open `test/golden/goldens/design_check.png`. Things to check by eye,
/// because no assertion can:
///   - the four weights in the "type scale" ladder look clearly different
///   - the orb ramp goes coral -> grey -> teal left to right
///   - nothing is hairline-thin (that would mean a missing `fontVariations`)
///
/// Animations are disabled here, which both makes the frame deterministic and
/// exercises the orb's reduce-motion path.
void main() {
  // `flutter test` does NOT pick up fonts declared in pubspec.yaml — it swaps
  // every family for a placeholder that draws filled rectangles instead of
  // glyphs. Without this the golden is useless for judging type, which is the
  // main reason the golden exists. So load the real file off disk.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await File('assets/fonts/Nunito[wght].ttf').readAsBytes();
    await (FontLoader('Nunito')
          ..addFont(
            Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
          ))
        .load();
  });

  testWidgets('design system renders', (tester) async {
    // Tall surface so the whole scrolling screen fits in one frame. 840x4300
    // physical at DPR 2 = 420x2150 logical, which is just taller than the
    // content — bump it if a new section gets clipped.
    tester.view.physicalSize = const Size(840, 4300);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AuraTheme.dark,
          themeMode: ThemeMode.dark,
          debugShowCheckedModeBanner: false,
          home: const DesignCheckScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design_check.png'),
    );
  });
}
