import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_spacing.dart';
import '../../core/theme/aura_typography.dart';
import '../../shared/widgets/aura_card.dart';
import '../../shared/widgets/aura_orb.dart';
import '../../shared/widgets/aura_points.dart';

/// Development-only screen that renders every design-system primitive at once.
///
/// This is how slice 0 is verified: if the palette, the type scale, the orb and
/// the components all look right here, every later screen inherits that. It also
/// answers the one thing that cannot be checked by reading code — whether the
/// bundled Nunito variable font actually moves its weight axis. See the "type
/// scale" section: if 400 and 800 look identical, `fontVariations` is not being
/// applied and [AuraType] needs fixing.
///
/// Not reachable from the real app. Delete or hide behind a debug flag before
/// the beta.
class DesignCheckScreen extends StatelessWidget {
  const DesignCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('design check')),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpacing.screenPadding),
        children: const [
          _OrbSection(),
          SizedBox(height: AuraSpacing.xxl),
          _TypeSection(),
          SizedBox(height: AuraSpacing.xxl),
          _PaletteSection(),
          SizedBox(height: AuraSpacing.xxl),
          _PointsSection(),
          SizedBox(height: AuraSpacing.xxl),
          _ComponentSection(),
          SizedBox(height: AuraSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraType.headingMedium),
        if (note != null) ...[
          const SizedBox(height: AuraSpacing.xs),
          Text(note!, style: AuraType.bodySmall),
        ],
        const SizedBox(height: AuraSpacing.lg),
      ],
    );
  }
}

class _OrbSection extends StatelessWidget {
  const _OrbSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'the orb',
          note: 'should be breathing. colour follows the score.',
        ),
        Center(
          child: Column(
            children: [
              const AuraOrb(score: 1000, size: 220),
              const SizedBox(height: AuraSpacing.sm),
              Text('1000', style: AuraType.scoreHero),
              Text('aura', style: AuraType.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AuraSpacing.xl),
        // Smaller orbs across the range, so the colour ramp is visible at a
        // glance rather than having to be reasoned about.
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _OrbSample(score: 320),
            _OrbSample(score: 700),
            _OrbSample(score: 1000),
            _OrbSample(score: 2200),
          ],
        ),
      ],
    );
  }
}

class _OrbSample extends StatelessWidget {
  const _OrbSample({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AuraOrb(score: score, size: 68),
        const SizedBox(height: AuraSpacing.xs),
        Text('$score', style: AuraType.caption),
      ],
    );
  }
}

class _TypeSection extends StatelessWidget {
  const _TypeSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'type scale',
          note: 'nunito. the four weights below must look clearly different.',
        ),
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1000', style: AuraType.scoreHero),
              const SizedBox(height: AuraSpacing.sm),
              Text('heading large', style: AuraType.headingLarge),
              Text('heading medium', style: AuraType.headingMedium),
              const SizedBox(height: AuraSpacing.sm),
              Text('body — you got +80 aura from @sam', style: AuraType.body),
              Text('body strong', style: AuraType.bodyStrong),
              Text('body small, muted', style: AuraType.bodySmall),
              Text('2 minutes ago', style: AuraType.caption),
            ],
          ),
        ),
        const SizedBox(height: AuraSpacing.md),
        // The variable-font weight ladder. Same size, same text, four weights.
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final weight in [400, 600, 700, 800])
                Text(
                  'weight $weight — aura 1000',
                  style: TextStyle(
                    fontFamily: AuraType.family,
                    fontSize: 20,
                    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
                    fontVariations: [FontVariation('wght', weight.toDouble())],
                    color: AuraColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaletteSection extends StatelessWidget {
  const _PaletteSection();

  static const _swatches = <(String, Color)>[
    ('background', AuraColors.background),
    ('surface', AuraColors.surface),
    ('positive', AuraColors.positive),
    ('positiveDeep', AuraColors.positiveDeep),
    ('negative', AuraColors.negative),
    ('gold', AuraColors.gold),
    ('neutral', AuraColors.neutral),
    ('textPrimary', AuraColors.textPrimary),
    ('textMuted', AuraColors.textMuted),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('palette', note: 'spec 6.2, verbatim.'),
        Wrap(
          spacing: AuraSpacing.md,
          runSpacing: AuraSpacing.md,
          children: [
            for (final (name, color) in _swatches)
              SizedBox(
                width: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: AuraRadius.inputAll,
                        border: Border.all(color: AuraColors.surfaceBorder),
                      ),
                    ),
                    const SizedBox(height: AuraSpacing.xs),
                    Text(name, style: AuraType.caption),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PointsSection extends StatelessWidget {
  const _PointsSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'point values',
          note: 'the sign is always shown, never colour alone.',
        ),
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PointsRow(points: 120, reason: 'paid for everyone'),
              Divider(height: AuraSpacing.xl),
              _PointsRow(points: -80, reason: 'left me on read'),
              Divider(height: AuraSpacing.xl),
              _PointsRow(points: 0, reason: 'no change'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointsRow extends StatelessWidget {
  const _PointsRow({required this.points, required this.reason});

  final int points;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(reason, style: AuraType.body)),
        AuraPoints(points: points, style: AuraType.scoreSmall, showUnit: true),
      ],
    );
  }
}

class _ComponentSection extends StatelessWidget {
  const _ComponentSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          'components',
          note: 'pill buttons, 14px inputs, 20px cards.',
        ),
        FilledButton(onPressed: () {}, child: const Text('send aura')),
        const SizedBox(height: AuraSpacing.md),
        OutlinedButton(onPressed: () {}, child: const Text('maybe later')),
        const SizedBox(height: AuraSpacing.md),
        TextButton(onPressed: () {}, child: const Text('skip')),
        const SizedBox(height: AuraSpacing.lg),
        const TextField(
          decoration: InputDecoration(hintText: 'what did they do?'),
        ),
        const SizedBox(height: AuraSpacing.lg),
        AuraCard(
          large: true,
          borderColor: AuraColors.positive.withValues(alpha: 0.35),
          onTap: () {},
          child: Row(
            children: [
              const AuraOrb(score: 1400, size: 44),
              const SizedBox(width: AuraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@sam', style: AuraType.bodyStrong),
                    Text('tappable card, teal edge', style: AuraType.bodySmall),
                  ],
                ),
              ),
              const AuraPoints(points: 120),
            ],
          ),
        ),
      ],
    );
  }
}
