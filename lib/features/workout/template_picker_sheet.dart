import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/workout/routine_templates.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet to pick a ready-made routine template (PPL, Upper/Lower,
/// 5×5, Full-body). Applying one builds + activates the routine — no AI.
class TemplatePickerSheet extends ConsumerStatefulWidget {
  const TemplatePickerSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const TemplatePickerSheet(),
    );
  }

  @override
  ConsumerState<TemplatePickerSheet> createState() =>
      _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<TemplatePickerSheet> {
  String? _applying;

  Future<void> _apply(RoutineTemplate t) async {
    if (_applying != null) return;
    setState(() => _applying = t.id);
    try {
      await RoutineTemplates.applyTemplate(
        t,
        exercises: ref.read(exerciseRepoProvider),
        workouts: ref.read(workoutRepoProvider),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _applying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
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
            Text(AppLocalizations.of(context)!.pickATemplate, style: AppText.sectionTitle),
            const SizedBox(height: 2),
            Text(AppLocalizations.of(context)!.provenSplitsReadyToTrainReplacesYourRoutine,
                style: AppText.meta.copyWith(fontSize: 12)),
            const SizedBox(height: 14),
            for (final t in RoutineTemplates.all) ...[
              GestureDetector(
                onTap: () => _apply(t),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(t.subtitle, style: AppText.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      if (_applying == t.id)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: AppColors.accent),
                        )
                      else
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
