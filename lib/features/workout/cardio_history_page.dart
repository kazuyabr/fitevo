import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/cardio_session.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'cardio_log_sheet.dart' show CardioSessionRow;
import '../../l10n/app_localizations.dart';

/// Scrollable history of every logged cardio bout, grouped by day.
class CardioHistoryPage extends ConsumerWidget {
  const CardioHistoryPage({super.key});

  Future<void> _delete(WidgetRef ref, CardioSession s) async {
    await ref.read(cardioRepoProvider).delete(s.id);
    final nutrition = ref.read(nutritionRepoProvider);
    final log = await nutrition.getOrCreateLog(s.startedAt);
    final mins = s.durationSeconds ~/ 60;
    final dist = s.distanceKm ?? 0;
    final isOther = s.type != CardioType.run && s.type != CardioType.walk;
    await nutrition.upsertDailyLog(
      s.startedAt,
      runningKmToday: s.type == CardioType.run
          ? (log.runningKmToday - dist).clamp(0.0, double.infinity)
          : log.runningKmToday,
      walkingKmToday: s.type == CardioType.walk
          ? (log.walkingKmToday - dist).clamp(0.0, double.infinity)
          : log.walkingKmToday,
      otherCardioMinutes: isOther
          ? (log.otherCardioMinutes - mins).clamp(0, 1000000)
          : log.otherCardioMinutes,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final all = ref.watch(allCardioProvider).valueOrNull ?? const [];
    // Group by dateKey, preserving the sorted (desc) order.
    final byDay = <String, List<CardioSession>>{};
    for (final s in all) {
      (byDay[s.dateKey] ??= []).add(s);
    }
    final days = byDay.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.cardioHistory, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: all.isEmpty
            ? Center(
                child: Text(AppLocalizations.of(context)!.noCardioLoggedYet, style: AppText.body))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final key = days[i];
                  final sessions = byDay[key]!;
                  final total =
                      sessions.fold<int>(0, (a, s) => a + s.calories);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(
                          children: [
                            Text(_dayLabel(sessions.first.startedAt),
                                style: AppText.label),
                            const Spacer(),
                            Text('$total kcal',
                                style: AppText.meta.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.stroke),
                        ),
                        child: Column(
                          children: [
                            for (final s in sessions)
                              CardioSessionRow(
                                session: s,
                                onDelete: () => _delete(ref, s),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }
}
