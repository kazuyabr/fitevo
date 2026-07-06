import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Brand AI mark — a rounded chat frame that breaks open at its lower-right
/// corner, a geometric "AI" wordmark inside, and a concave four-point sparkle
/// nested in the open corner. Drawn in code (no asset/PNG) so it scales
/// crisply to any [size] and takes a single [color], dropping in wherever a
/// Material [Icon] used to sit.
///
/// Below ~14px the interior "AI" is omitted — at that scale it would be an
/// illegible smudge, and those small placements always sit next to an
/// "AI"/"Coach"/"Photo" label anyway. The frame + sparkle carry the identity.
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
    Offset p(double nx, double ny) => Offset(nx * s, ny * s);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ---- Chat frame: rounded square opened at the bottom-right corner ----
    const r = 0.14; // corner radius (centerline)
    const l = 0.19, t = 0.19, rt = 0.805, b = 0.805;
    final rad = Radius.circular(r * s);
    final framePath = Path()
      ..moveTo(rt * s, 0.52 * s) // right edge stops partway down
      ..lineTo(rt * s, (t + r) * s)
      ..arcToPoint(p(rt - r, t), radius: rad, clockwise: false)
      ..lineTo((l + r) * s, t * s)
      ..arcToPoint(p(l, t + r), radius: rad, clockwise: false)
      ..lineTo(l * s, (b - r) * s)
      ..arcToPoint(p(l + r, b), radius: rad, clockwise: false)
      ..lineTo(0.62 * s, b * s); // bottom edge stops partway across
    canvas.drawPath(
      framePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * 0.082)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // ---- Four-point sparkle (concave sides) in the open corner ----
    final sc = p(0.770, 0.780);
    const rOut = 0.215, rIn = 0.058;
    final spark = Path();
    for (var i = 0; i <= 4; i++) {
      final a = i * math.pi / 2;
      final tip =
          Offset(sc.dx + rOut * s * math.cos(a), sc.dy + rOut * s * math.sin(a));
      if (i == 0) {
        spark.moveTo(tip.dx, tip.dy);
      } else {
        final ca = (i - 0.5) * math.pi / 2;
        final ctrl = Offset(
            sc.dx + rIn * s * math.cos(ca), sc.dy + rIn * s * math.sin(ca));
        spark.quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
      }
    }
    canvas.drawPath(spark..close(), fill);

    // ---- "AI" wordmark (omitted when too small to read) ----
    if (s >= 14) {
      // A — two leg triangles meeting at a sharp apex, joined by a crossbar,
      // leaving a triangular counter above the bar and an open splay below.
      final aPath = Path()
        ..moveTo(0.415 * s, 0.315 * s)
        ..lineTo(0.360 * s, 0.660 * s)
        ..lineTo(0.270 * s, 0.660 * s)
        ..close()
        ..moveTo(0.415 * s, 0.315 * s)
        ..lineTo(0.470 * s, 0.660 * s)
        ..lineTo(0.560 * s, 0.660 * s)
        ..close()
        ..addRect(Rect.fromLTRB(0.375 * s, 0.500 * s, 0.455 * s, 0.552 * s));
      canvas.drawPath(aPath, fill);

      // I — a solid bar with a whisper of corner rounding.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0.590 * s, 0.315 * s, 0.648 * s, 0.660 * s),
          Radius.circular(0.01 * s),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_AiIconPainter old) => old.color != color;
}
