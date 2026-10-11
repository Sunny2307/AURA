import 'package:aura/core/theme/aura_colors.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/core/theme/aura_typography.dart';
import 'package:aura/shared/widgets/aura_orb.dart';
import 'package:aura/shared/widgets/aura_points.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuraPoints', () {
    // The whole point of this widget: the sign carries the meaning, so that
    // someone who cannot separate teal from coral still reads it correctly.
    test('always shows an explicit sign, except for zero', () {
      expect(AuraPoints.format(120), '+120');
      expect(AuraPoints.format(-80), '-80');
      expect(AuraPoints.format(0), '0');
    });

    test('spells the sign out for screen readers', () {
      expect(AuraPoints.semanticLabel(120), 'plus 120 aura');
      expect(AuraPoints.semanticLabel(-80), 'minus 80 aura');
      expect(AuraPoints.semanticLabel(0), 'no aura change');
    });

    testWidgets('renders sign, unit and colour together', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AuraTheme.light,
          home: const Scaffold(body: AuraPoints(points: -80, showUnit: true)),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, '-80 aura');
      expect(text.style?.color, AuraColors.negative);
    });
  });

  group('AuraColors.forPoints', () {
    test('zero is neutral, not positive', () {
      expect(AuraColors.forPoints(1), AuraColors.positive);
      expect(AuraColors.forPoints(-1), AuraColors.negative);
      expect(AuraColors.forPoints(0), AuraColors.neutral);
    });
  });

  group('AuraOrb.colorForScore', () {
    test('bottoms out coral and tops out teal', () {
      expect(AuraOrb.colorForScore(0), AuraColors.negative);
      expect(AuraOrb.colorForScore(600), AuraColors.neutral);
      expect(AuraOrb.colorForScore(1000), AuraColors.positive);
      // Above the baseline the hue holds; only the glow grows.
      expect(AuraOrb.colorForScore(5000), AuraColors.positive);
    });

    test('gets steadily less red as the score rises', () {
      // Note the metric. The green channel alone is *not* monotonic here, and
      // that is intentional: the ramp goes coral -> dark grey -> teal, and the
      // grey midpoint is darker than the coral, so green dips before it climbs.
      // A dim orb at a mediocre score is the point. What must hold is that the
      // colour never gets *warmer* as the score improves, so we measure redness
      // relative to green.
      const scores = [0, 300, 600, 800, 1000];
      final redness = scores.map((s) {
        final c = AuraOrb.colorForScore(s);
        return c.r - c.g;
      }).toList();

      for (var i = 1; i < redness.length; i++) {
        expect(
          redness[i],
          lessThan(redness[i - 1]),
          reason: 'score ${scores[i]} looks warmer than ${scores[i - 1]}',
        );
      }
    });
  });

  group('AuraOrb', () {
    testWidgets('breathes by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuraOrb(score: 1000))),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // A forever-repeating animation means frames keep being scheduled.
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('stops entirely when the OS asks to reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: Scaffold(body: AuraOrb(score: 1000))),
        ),
      );

      // Would time out if the orb were still looping.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('disposes its controller without leaking a ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuraOrb(score: 1000))),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      // The test framework fails the test itself if a ticker outlives its state.
      expect(find.byType(AuraOrb), findsNothing);
    });
  });

  group('AuraTheme', () {
    test('redesign text and controls contrast on every surface', () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
      }

      for (final bg in [
        AuraColors.background,
        AuraColors.surface,
        AuraColors.surfaceRaised,
        AuraColors.lilac,
        AuraColors.peach,
        AuraColors.lime,
      ]) {
        for (final fg in [
          AuraColors.textPrimary,
          AuraColors.textMuted,
          AuraColors.positive,
          AuraColors.negative,
          AuraColors.gold,
          AuraColors.action,
        ]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(AuraColors.controlBorder, bg), greaterThanOrEqualTo(3));
      }
      expect(
        contrast(AuraTheme.light.colorScheme.onPrimary, AuraColors.action),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('uses a light canvas and separates actions from aura status', () {
      final theme = AuraTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AuraColors.background);
      expect(theme.colorScheme.primary, AuraColors.action);
      expect(theme.colorScheme.primary, isNot(AuraColors.positive));
      expect(theme.colorScheme.error, AuraColors.negative);
    });

    test('uses the bundled font, not a platform default', () {
      expect(AuraTheme.light.textTheme.bodyLarge?.fontFamily, 'Nunito');
    });

    // Nunito's wght axis defaults to 200 (verified by tool/check_font.js), so a
    // slot without an explicit FontVariation renders hairline-thin rather than
    // merely un-bolded. This test exists to catch a slot being added or blanked
    // later — it is cheap insurance against a subtle, whole-app visual bug.
    test('every text theme slot pins the weight axis', () {
      final t = AuraType.textTheme;
      final slots = <String, TextStyle?>{
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };

      slots.forEach((name, style) {
        expect(style, isNotNull, reason: '$name is unset');
        expect(
          style!.fontVariations?.any((v) => v.axis == 'wght'),
          isTrue,
          reason: '$name has no wght variation — it will render at weight 200',
        );
      });
    });
  });
}
