import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../theme.dart';

/// Full-bleed photo tiles — one per workout type. Each tile shows a real
/// person doing the activity (Unsplash CDN, cached), with a dark gradient
/// at the bottom so the label always reads cleanly.
///
/// Reused by onboarding and settings so both stay in sync.
class WorkoutTypePicker extends StatelessWidget {
  final WorkoutType value;
  final ValueChanged<WorkoutType> onChanged;

  const WorkoutTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  // (type, label, accent (border+glow when selected), photo URL)
  static const _tiles = <(WorkoutType, String, Color, String)>[
    (
      WorkoutType.gym,
      'GYM',
      Color(0xFF2C6E9C),
      // Bright, well-lit gym scene — man working out with a barbell
      'https://images.unsplash.com/photo-1692369608191-005af0051fe2?w=800&q=80&fit=crop',
    ),
    (
      WorkoutType.homeWorkout,
      'HOME',
      Color(0xFF9C5A1F),
      // Woman doing sit-ups / core work at home
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&q=80&fit=crop',
    ),
    (
      WorkoutType.yoga,
      'YOGA',
      Color(0xFF5C3D8C),
      // Silhouette yoga pose
      'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800&q=80&fit=crop',
    ),
    (
      WorkoutType.meditation,
      'MEDITATION',
      Color(0xFF2A6E44),
      // Person meditating on a cliff
      'https://images.unsplash.com/photo-1512438248247-f0f2a5a8b7f0?w=800&q=80&fit=crop',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final tileW = (constraints.maxWidth - spacing) / 2;
        final tileH = tileW * 1.20;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final t in _tiles)
              SizedBox(
                width: tileW,
                height: tileH,
                child: _WorkoutTile(
                  type: t.$1,
                  label: t.$2,
                  accent: t.$3,
                  photoUrl: t.$4,
                  selected: value == t.$1,
                  onTap: () => onChanged(t.$1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final WorkoutType type;
  final String label;
  final Color accent;
  final String photoUrl;
  final bool selected;
  final VoidCallback onTap;

  const _WorkoutTile({
    required this.type,
    required this.label,
    required this.accent,
    required this.photoUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: selected
            ? (Matrix4.identity()..scaleByDouble(1.03, 1.03, 1.03, 1))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.20),
              blurRadius: selected ? 28 : 14,
              offset: Offset(0, selected ? 14 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Base color while photo loads ──
              Container(color: accent.withValues(alpha: 0.35)),

              // ── Photo — full bleed ──
              CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 320),
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => Container(
                  color: accent.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: Icon(_fallbackIcon(type),
                      size: 48, color: Colors.white),
                ),
              ),

              // ── Dark gradient at the bottom so the label reads
              //    cleanly regardless of the photo underneath ──
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x44000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.35, 0.65, 1.0],
                  ),
                ),
              ),

              // ── Accent border when selected ──
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent, width: 3),
                  ),
                ),

              // ── Label ──
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    shadows: [
                      Shadow(
                        color: Color(0xAA000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Selected check badge (top-right) ──
              Positioned(
                top: 10,
                right: 10,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Icon(Icons.check_rounded,
                        size: 16, color: AppColors.onAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _fallbackIcon(WorkoutType t) => switch (t) {
        WorkoutType.gym => Icons.fitness_center_rounded,
        WorkoutType.homeWorkout => Icons.home_rounded,
        WorkoutType.yoga => Icons.self_improvement_rounded,
        WorkoutType.meditation => Icons.spa_rounded,
        WorkoutType.none => Icons.directions_walk_rounded,
      };
}
