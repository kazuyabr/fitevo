import 'package:flutter/material.dart';

import '../theme.dart';

/// A subtle pulsing placeholder block. Matches the app's surface / stroke
/// palette so it feels like the real content is just moments away.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Pulse between surfaceHigh and a slightly lighter blend of stroke —
        // reads as "loading" in both light and dark palettes.
        final t = Curves.easeInOut.transform(_ctrl.value);
        final color = Color.lerp(
          AppColors.surfaceHigh,
          AppColors.stroke,
          t * 0.6,
        );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// Circular skeleton — avatars, rings, round buttons.
class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) => SkeletonBox(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );
}

/// Skeleton mirroring a typical list row: leading circle, two text
/// lines, and a trailing value block — PR rows, food rows, etc.
class SkeletonRow extends StatelessWidget {
  final double height;
  const SkeletonRow({super.key, this.height = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          SkeletonCircle(size: height * 0.55),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 140, height: 13),
                SizedBox(height: 7),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          const SkeletonBox(width: 46, height: 13),
        ],
      ),
    );
  }
}

/// Skeleton mirroring a `_Section` card layout: title bar + a few rows of
/// content inside a rounded surface. Composed of `SkeletonBox`es so each
/// one pulses independently with a smooth wave feel.
class SkeletonSection extends StatelessWidget {
  final int rows;
  final double titleWidth;

  const SkeletonSection({
    super.key,
    this.rows = 3,
    this.titleWidth = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: titleWidth, height: 18),
          const SizedBox(height: 10),
          SkeletonBox(width: 220, height: 12),
          const SizedBox(height: 20),
          for (int i = 0; i < rows; i++) ...[
            const SkeletonBox(height: 44),
            if (i < rows - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
