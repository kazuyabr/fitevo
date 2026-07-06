import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/soreness_log.dart';
import '../../services/workout/muscle_volume.dart';
import '../../state/providers.dart';
import '../../theme.dart';

/// Muscles the check-in asks about (the trainable majors).
const List<MuscleGroup> _sorenessMuscles = [
  MuscleGroup.chest,
  MuscleGroup.back,
  MuscleGroup.shoulders,
  MuscleGroup.biceps,
  MuscleGroup.triceps,
  MuscleGroup.quads,
  MuscleGroup.hamstrings,
  MuscleGroup.glutes,
  MuscleGroup.calves,
  MuscleGroup.core,
];

/// Workout-tab recovery card: a soreness check-in button plus a smart
/// warning when today's planned day hits muscles the user flagged sore.
class RecoveryCard extends ConsumerWidget {
  const RecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soreness = ref.watch(todaySorenessProvider).valueOrNull;
    final day = ref.watch(todaysRoutineDayProvider).valueOrNull;
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? const [];
    final byId = {for (final e in exercises) e.id: e};

    // Muscles today's day trains.
    final dayMuscles = <MuscleGroup>{};
    if (day != null && !day.isRest) {
      for (final item in day.items) {
        dayMuscles.addAll(byId[item.exerciseId]?.muscleGroups ?? const []);
      }
    }
    // Sore muscles (level ≥ 3) that today's day would hit.
    final clashing = <String>[];
    if (soreness != null) {
      for (final e in soreness.entries) {
        if (e.level >= 3 && dayMuscles.contains(e.muscle)) {
          clashing.add(MuscleVolumeService.muscleLabel(e.muscle));
        }
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.healing_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('RECOVERY', style: AppText.label),
              const Spacer(),
              if (soreness != null)
                Text('Checked in',
                    style: AppText.meta.copyWith(
                        fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          if (clashing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your ${clashing.join(", ")} ${clashing.length == 1 ? 'is' : 'are'} still sore, '
                      'and today hits ${clashing.length == 1 ? 'it' : 'them'}. '
                      'Go lighter or train something fresher.',
                      style: AppText.meta.copyWith(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => SorenessSheet.show(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(soreness == null ? 'Soreness check-in' : 'Update check-in',
                  style: AppText.body.copyWith(
                      color: AppColors.accent, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: rate today's soreness per muscle (0 fresh → 4 very sore).
class SorenessSheet extends ConsumerStatefulWidget {
  const SorenessSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SorenessSheet(),
    );
  }

  @override
  ConsumerState<SorenessSheet> createState() => _SorenessSheetState();
}

class _SorenessSheetState extends ConsumerState<SorenessSheet> {
  final Map<MuscleGroup, int> _levels = {};

  @override
  void initState() {
    super.initState();
    // Prefill from today's existing check-in if any.
    final existing = ref.read(todaySorenessProvider).valueOrNull;
    if (existing != null) {
      for (final e in existing.entries) {
        _levels[e.muscle] = e.level;
      }
    }
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final log = SorenessLog()
      ..dateKey = SorenessLog.keyFor(now)
      ..createdAt = now
      ..entries = [
        for (final entry in _levels.entries)
          if (entry.value > 0)
            (MuscleSoreness()
              ..muscle = entry.key
              ..level = entry.value),
      ];
    await ref.read(sorenessRepoProvider).save(log);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('How sore are you?', style: AppText.sectionTitle),
            const SizedBox(height: 2),
            Text('Tap a level for each muscle — 0 fresh, 4 very sore.',
                style: AppText.meta.copyWith(fontSize: 12)),
            const SizedBox(height: 14),
            for (final m in _sorenessMuscles) ...[
              Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(MuscleVolumeService.muscleLabel(m),
                        style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  for (var lvl = 0; lvl <= 4; lvl++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _levels[m] = lvl),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (_levels[m] ?? 0) == lvl
                                ? _levelColor(lvl)
                                : AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: (_levels[m] ?? 0) == lvl
                                    ? _levelColor(lvl)
                                    : AppColors.stroke),
                          ),
                          child: Text('$lvl',
                              style: TextStyle(
                                color: (_levels[m] ?? 0) == lvl
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              )),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _save,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Text('Save check-in',
                    style: AppText.body.copyWith(
                        color: AppColors.onAccent,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(int lvl) => switch (lvl) {
        0 => const Color(0xFF2FB673),
        1 => const Color(0xFF7CB342),
        2 => AppColors.accent,
        3 => const Color(0xFFEF6C00),
        _ => AppColors.danger,
      };
}
