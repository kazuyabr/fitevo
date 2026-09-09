import 'package:flutter/material.dart';

import '../../data/models/workout_session.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// GitHub-style training heatmap — one square per day over the last ~16
/// weeks, tinted by how many working sets were logged. Makes consistency
/// (and gaps) visible at a glance.
class TrainingCalendarCard extends StatelessWidget {
  final List<WorkoutSession> sessions;
  const TrainingCalendarCard({super.key, required this.sessions});

  static const _weeks = 16;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Sets per day.
    final setsByDay = <String, int>{};
    for (final s in sessions) {
      final key = s.dateKey;
      final working = s.sets.where((e) => !e.isWarmup).length;
      setsByDay[key] = (setsByDay[key] ?? 0) + working;
    }

    // Grid runs from the Monday of (16 weeks ago) to today.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startMonday =
        today.subtract(Duration(days: today.weekday - 1 + (_weeks - 1) * 7));

    Color cellColor(int sets) {
      if (sets <= 0) return AppColors.surfaceHigh;
      final t = (sets / 20).clamp(0.2, 1.0);
      return Color.lerp(
          AppColors.accent.withValues(alpha: 0.35), AppColors.accent, t)!;
    }

    final columns = <Widget>[];
    for (var w = 0; w < _weeks; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = startMonday.add(Duration(days: w * 7 + d));
        final key = WorkoutSession.keyFor(day);
        final isFuture = day.isAfter(today);
        cells.add(
          Container(
            width: 13,
            height: 13,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: isFuture
                  ? Colors.transparent
                  : cellColor(setsByDay[key] ?? 0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }
      columns.add(Column(mainAxisSize: MainAxisSize.min, children: cells));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.trainingCalendar, style: AppText.label),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(children: columns),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(AppLocalizations.of(context)!.less,
                  style: AppText.meta
                      .copyWith(fontSize: 10, color: AppColors.textTertiary)),
              const SizedBox(width: 6),
              for (final a in [0.0, 0.4, 0.7, 1.0])
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: a == 0.0
                        ? AppColors.surfaceHigh
                        : Color.lerp(
                            AppColors.accent.withValues(alpha: 0.35),
                            AppColors.accent,
                            a)!,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 6),
              Text(AppLocalizations.of(context)!.more,
                  style: AppText.meta
                      .copyWith(fontSize: 10, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
