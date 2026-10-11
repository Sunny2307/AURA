import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/aura_routes.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_typography.dart';
import 'aura_orb.dart';

/// Small editorial label used to separate content without another heavy card.
class AuraEyebrow extends StatelessWidget {
  const AuraEyebrow(this.text, {super.key, this.color = AuraColors.positive});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AuraType.label.copyWith(
      fontSize: 12,
      color: color,
      letterSpacing: 2,
    ),
  );
}

/// Orbit lines give the existing animated orb a recognizable collectible frame.
class AuraOrbit extends StatelessWidget {
  const AuraOrbit({super.key, required this.score, this.size = 240});
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(child: CustomPaint(painter: _OrbitPainter())),
        ),
        AuraOrb(score: score, size: size * 0.86),
      ],
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.43;
    final line = Paint()
      ..color = AuraColors.positive.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, line);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.15,
        height: radius * 0.84,
      ),
      line,
    );
    canvas.restore();
    final dot = Paint()..color = AuraColors.positive;
    canvas.drawCircle(center + Offset(radius * 0.71, -radius * 0.71), 4, dot);
    canvas.drawCircle(center + Offset(-radius * 0.94, radius * 0.34), 2.5, dot);
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => false;
}

/// Existing top-level routes, exposed together without adding placeholder tabs.
class AuraNavigation extends StatelessWidget {
  const AuraNavigation({super.key, required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AuraColors.surfaceBorder)),
    ),
    child: NavigationBar(
      backgroundColor: AuraColors.background,
      indicatorColor: AuraColors.positive,
      selectedIndex: selected,
      height: 76,
      onDestinationSelected: (index) {
        if (index == selected) return;
        context.go(
          [AuraRoutes.home, AuraRoutes.friends, AuraRoutes.settings][index],
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.blur_on_rounded),
          selectedIcon: Icon(
            Icons.blur_on_rounded,
            color: AuraColors.background,
          ),
          label: 'your aura',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(
            Icons.people_rounded,
            color: AuraColors.background,
          ),
          label: 'your people',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_rounded),
          selectedIcon: Icon(Icons.tune_rounded, color: AuraColors.background),
          label: 'settings',
        ),
      ],
    ),
  );
}

class AuraIntro extends StatelessWidget {
  const AuraIntro({
    super.key,
    required this.label,
    required this.title,
    required this.body,
  });
  final String label;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraEyebrow(label),
        const SizedBox(height: 10),
        Text(title, style: AuraType.headingLarge),
        const SizedBox(height: 8),
        Text(body, style: AuraType.body.copyWith(color: AuraColors.textMuted)),
      ],
    ),
  );
}

/// Drill-in routes can also be opened directly by an invite or restored session.
class AuraBackButton extends StatelessWidget {
  const AuraBackButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'go back',
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.maybeOf(context)?.go(AuraRoutes.home);
      }
    },
  );
}
