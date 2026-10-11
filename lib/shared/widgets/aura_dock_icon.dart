import 'package:flutter/material.dart';

import 'aura_logo.dart';

enum AuraDockGlyph { aura, people, send, discover, settings }

/// A consistent set of round, two-point line icons for the floating dock.
class AuraDockIcon extends StatelessWidget {
  const AuraDockIcon({super.key, required this.glyph, required this.color});
  final AuraDockGlyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 28,
      child: glyph == AuraDockGlyph.aura
          ? const AuraLogo(size: 28)
          : CustomPaint(painter: _DockIconPainter(glyph, color)),
    ),
  );
}

class _DockIconPainter extends CustomPainter {
  const _DockIconPainter(this.glyph, this.color);
  final AuraDockGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case AuraDockGlyph.aura:
        canvas.drawPath(
          Path()
            ..moveTo(16, 4)
            ..quadraticBezierTo(18, 14, 28, 16)
            ..quadraticBezierTo(18, 18, 16, 28)
            ..quadraticBezierTo(14, 18, 4, 16)
            ..quadraticBezierTo(14, 14, 16, 4)
            ..close(),
          pen,
        );
      case AuraDockGlyph.people:
        canvas.drawCircle(const Offset(11, 10), 4, pen);
        canvas.drawCircle(const Offset(23, 11), 3, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 26)
            ..lineTo(3, 24)
            ..cubicTo(3, 16, 19, 16, 19, 24)
            ..lineTo(19, 26)
            ..moveTo(23, 18)
            ..cubicTo(29, 18, 29, 23, 29, 26),
          pen,
        );
      case AuraDockGlyph.send:
        canvas.drawPath(
          Path()
            // Symmetric upright plane keeps its visual center on the circle.
            ..moveTo(16, 5)
            ..lineTo(27, 27)
            ..lineTo(16, 22)
            ..lineTo(5, 27)
            ..close()
            ..moveTo(16, 5)
            ..lineTo(16, 22),
          pen,
        );
      case AuraDockGlyph.discover:
        canvas.drawCircle(const Offset(16, 16), 12, pen);
        canvas.drawPath(
          Path()
            ..moveTo(21, 11)
            ..lineTo(18, 18)
            ..lineTo(11, 21)
            ..lineTo(14, 14)
            ..close(),
          pen,
        );
      case AuraDockGlyph.settings:
        for (final x in [7.0, 16.0, 25.0]) {
          final y = x == 16 ? 22.0 : 10.0;
          canvas.drawLine(Offset(x, 5), Offset(x, y - 3), pen);
          canvas.drawLine(Offset(x, y + 3), Offset(x, 27), pen);
          canvas.drawCircle(Offset(x, y), 3, pen);
        }
    }
  }

  @override
  bool shouldRepaint(_DockIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
