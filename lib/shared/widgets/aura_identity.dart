import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/aura_routes.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_typography.dart';
import 'aura_orb.dart';
import 'aura_dock_icon.dart';

/// Small editorial label used to separate content without another heavy card.
class AuraEyebrow extends StatelessWidget {
  const AuraEyebrow(this.text, {super.key, this.color = AuraColors.action});
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
      ..color = AuraColors.action.withValues(alpha: 0.28)
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
    final dot = Paint()..color = AuraColors.action;
    canvas.drawCircle(center + Offset(radius * 0.71, -radius * 0.71), 4, dot);
    canvas.drawCircle(center + Offset(-radius * 0.94, radius * 0.34), 2.5, dot);
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => false;
}

/// Existing top-level routes, exposed together without adding placeholder tabs.
class AuraNavigation extends StatelessWidget {
  const AuraNavigation({super.key, required this.selected, this.onSend});
  final int selected;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    void go(int index) {
      if (index != selected) {
        context.go(
          [AuraRoutes.home, AuraRoutes.friends, AuraRoutes.settings][index],
        );
      }
    }

    final items = [
      _DockItem(
        key: const Key('dock-aura'),
        label: 'Aura',
        semanticLabel: 'your aura',
        glyph: AuraDockGlyph.aura,
        selected: selected == 0,
        onTap: () => go(0),
      ),
      _DockItem(
        key: const Key('dock-people'),
        label: 'People',
        semanticLabel: 'your people',
        glyph: AuraDockGlyph.people,
        selected: selected == 1,
        onTap: () => go(1),
      ),
      _DockItem(
        key: const Key('dock-send'),
        label: 'Send',
        semanticLabel: 'send aura',
        glyph: AuraDockGlyph.send,
        action: true,
        onTap: onSend,
      ),
      _DockItem(
        key: const Key('dock-discover'),
        label: 'Discover',
        semanticLabel: 'discover people',
        glyph: AuraDockGlyph.discover,
        onTap: onSend == null ? null : () => context.push(AuraRoutes.addFriend),
      ),
      _DockItem(
        key: const Key('dock-settings'),
        label: 'Settings',
        semanticLabel: 'settings',
        glyph: AuraDockGlyph.settings,
        selected: selected == 2,
        onTap: () => go(2),
      ),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: AuraColors.textPrimary.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              key: const Key('floating-dock'),
              color: AuraColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
                side: const BorderSide(color: AuraColors.surfaceBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [for (final item in items) Expanded(child: item)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.glyph,
    this.selected = false,
    this.action = false,
    this.onTap,
  });
  final String label;
  final String semanticLabel;
  final AuraDockGlyph glyph;
  final bool selected;
  final bool action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    label: semanticLabel,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
            child: Center(
              heightFactor: 1,
              child: Ink(
                key: action ? const Key('dock-send-circle') : null,
                width: action ? 48 : 40,
                height: action ? 48 : 40,
                decoration: BoxDecoration(
                  color: action && onTap != null
                      ? AuraColors.action
                      : selected
                      ? AuraColors.lilac
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(action ? 24 : 14),
                ),
                child: Center(
                  child: AuraDockIcon(
                    glyph: glyph,
                    color: action && onTap != null
                        ? AuraColors.onAction
                        : selected
                        ? AuraColors.action
                        : AuraColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
        DecoratedBox(
          decoration: BoxDecoration(
            color: AuraColors.lime,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AuraEyebrow(label, color: AuraColors.textPrimary),
          ),
        ),
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
