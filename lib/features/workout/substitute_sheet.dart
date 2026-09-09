import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/exercise.dart';
import '../../services/workout/muscle_volume.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet listing swap options for an exercise — other movements
/// that hit the same primary muscle. Returns the chosen [Exercise].
class SubstituteSheet extends ConsumerWidget {
  final int exerciseId;
  final String exerciseName;
  const SubstituteSheet({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  static Future<Exercise?> show(
    BuildContext context, {
    required int exerciseId,
    required String exerciseName,
  }) {
    return showModalBottomSheet<Exercise>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SubstituteSheet(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final all = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final current = all.where((e) => e.id == exerciseId).firstOrNull;
    final primary = current?.muscleGroups.firstOrNull;

    // Alternatives: share the primary muscle, not the current exercise.
    final alts = all.where((e) {
      if (e.id == exerciseId) return false;
      if (primary == null) return false;
      return e.muscleGroups.contains(primary);
    }).toList()
      // Same equipment first, then beginner-friendly, then name.
      ..sort((a, b) {
        final eqA = a.equipment == current?.equipment ? 0 : 1;
        final eqB = b.equipment == current?.equipment ? 0 : 1;
        if (eqA != eqB) return eqA - eqB;
        return a.name.compareTo(b.name);
      });

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
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
              Text(AppLocalizations.of(context)!.substituteExercise, style: AppText.sectionTitle),
              const SizedBox(height: 2),
              Text(
                primary == null
                    ? 'Swapping $exerciseName'
                    : 'Same target: ${MuscleVolumeService.muscleLabel(primary)}',
                style: AppText.meta.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: alts.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context)!.noAlternativesInYourLibraryYet,
                            style: AppText.body))
                    : ListView.separated(
                        controller: controller,
                        itemCount: alts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = alts[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).pop(e),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.stroke),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e.name,
                                            style: AppText.body.copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.equipment.name,
                                          style: AppText.meta.copyWith(
                                              fontSize: 11,
                                              color: AppColors.textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.swap_horiz_rounded,
                                      color: AppColors.accent, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
