import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Brand AI mark — a rounded-square badge holding an "AI" wordmark with a
/// four-point sparkle nested at its lower-right corner. Drawn in code (no
/// asset, no PNG) so it scales crisply to any [size] and takes a single
/// [color], dropping in wherever a Material [Icon] used to sit.
///
/// Below ~14px the interior "AI" is omitted — at that scale it would be an
/// illegible smudge, and those small placements always sit next to an
/// "AI"/"Coach"/"Photo" text label anyway. The box + sparkle carry the
/// identity on their own.
class AiIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const AiIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? AppColors.accent;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AiIconPainter(c)),
    );
  }
}

class _AiIconPainter extends CustomPainter {
  final Color color;

  _AiIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = math.max(1.0, s * 0.085);

    // Rounded-square badge, offset toward the upper-left so the sparkle can
    // nest just beyond its lower-right corner while the whole mark stays
    // visually centered in the box.
    final boxRect = Rect.fromLTWH(s * 0.06, s * 0.06, s * 0.62, s * 0.62);
    final rrect = RRect.fromRectAndRadius(boxRect, Radius.circular(s * 0.15));
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(rrect, line);

    // "AI" wordmark, only where there's room to render it legibly.
    if (s >= 14) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'AI',
          style: TextStyle(
            color: color,
            fontSize: s * 0.30,
            fontWeight: FontWeight.w900,
            letterSpacing: -s * 0.012,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          boxRect.center.dx - tp.width / 2,
          boxRect.center.dy - tp.height / 2,
        ),
      );
    }

    // Four-point sparkle at the lower-right corner.
    final center = Offset(s * 0.78, s * 0.78);
    const outerR = 0.20;
    const innerR = 0.07;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = (i.isEven ? outerR : innerR) * s;
      final a = i * math.pi / 4;
      final p = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AiIconPainter old) => old.color != color;
}
