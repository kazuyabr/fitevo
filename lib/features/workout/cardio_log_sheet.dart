import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cardio_session.dart';
import '../../data/models/enums.dart';
import '../../home/todays_activity_card.dart' show TodaysActivityMath;
import '../../services/workout/cardio_math.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'cardio_history_page.dart';
import 'interval_timer_page.dart';
import 'mindfulness_page.dart';

/// Card for the workout tab — today's activity (run/walk/other) read from
/// the same DailyLog the home screen uses, plus loggers.
class CardioTodayCard extends ConsumerWidget {
  const CardioTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(todayLogProvider).valueOrNull;
    final profile = ref.watch(profileStreamProvider).valueOrNull;
    final today = ref.watch(todayCardioProvider).valueOrNull ?? const [];
    // Net kcal credited to today — the exact same delta-over-baseline math
    // the calorie ring + reports use, so the number matches app-wide.
    final kcal = profile == null
        ? 0
        : TodaysActivityMath.bonusKcal(
            profile: profile,
            walkingKmToday: log?.walkingKmToday ?? 0,
            runningKmToday: log?.runningKmToday ?? 0,
            otherCardioMinutes: log?.otherCardioMinutes ?? 0,
          );

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
              Icon(Icons.favorite_rounded, size: 16, color: AppColors.water),
              const SizedBox(width: 6),
              Text('CARDIO & ACTIVITY', style: AppText.label),
              const Spacer(),
              if (today.isNotEmpty)
                Text('+$kcal kcal today',
                    style: AppText.meta.copyWith(
                        fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CardioHistoryPage())),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.history_rounded,
                    size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const IntervalTimerPage())),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.timer_outlined,
                    size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MindfulnessPage())),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.self_improvement_rounded,
                    size: 20, color: AppColors.accent),
              ),
            ],
          ),
          if (today.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final s in today)
              CardioSessionRow(session: s, onDelete: () => _delete(ref, s)),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => CardioLogSheet.show(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('Log activity',
                      style: AppText.body.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Deletes a bout and rolls back its contribution to the day's activity
  /// aggregate so the calorie target stays in sync.
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
}

/// One cardio bout row (type icon + label + distance/time + calories),
/// with an optional delete.
class CardioSessionRow extends StatelessWidget {
  final CardioSession session;
  final VoidCallback? onDelete;
  const CardioSessionRow({super.key, required this.session, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final detail = s.distanceKm != null
        ? '${s.distanceKm!.toStringAsFixed(1)} km'
        : '${s.durationSeconds ~/ 60} min';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(CardioMath.icon(s.type),
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(CardioMath.label(s.type),
              style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Text('$detail · ${s.calories} kcal',
              style: AppText.meta.copyWith(fontSize: 12)),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Combined activity logger — run + walk (by distance) and one other
/// modality (by time) in a single entry. Writes into the day's activity
/// so today's calorie target rises with the effort (distance for run/walk,
/// time for the rest).
class CardioLogSheet extends ConsumerStatefulWidget {
  const CardioLogSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CardioLogSheet(),
    );
  }

  @override
  ConsumerState<CardioLogSheet> createState() => _CardioLogSheetState();
}

class _CardioLogSheetState extends ConsumerState<CardioLogSheet> {
  final _run = TextEditingController();
  final _walk = TextEditingController();
  final _otherMin = TextEditingController();
  CardioType _otherType = CardioType.cycle;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _run.addListener(() => setState(() {}));
    _walk.addListener(() => setState(() {}));
    _otherMin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _run.dispose();
    _walk.dispose();
    _otherMin.dispose();
    super.dispose();
  }

  /// Net kcal this entry adds to today's target — the delta the shared
  /// activity model (calorie ring + reports) will credit. Distance drives
  /// run/walk; time drives the rest.
  int get _kcal {
    final profile = ref.read(profileStreamProvider).valueOrNull;
    if (profile == null) return 0;
    final log = ref.read(todayLogProvider).valueOrNull;
    final curRun = log?.runningKmToday ?? 0;
    final curWalk = log?.walkingKmToday ?? 0;
    final curOther = log?.otherCardioMinutes ?? 0;
    final runKm = double.tryParse(_run.text.trim()) ?? 0;
    final walkKm = double.tryParse(_walk.text.trim()) ?? 0;
    final mins = int.tryParse(_otherMin.text.trim()) ?? 0;
    final before = TodaysActivityMath.bonusKcal(
      profile: profile,
      walkingKmToday: curWalk,
      runningKmToday: curRun,
      otherCardioMinutes: curOther,
    );
    final after = TodaysActivityMath.bonusKcal(
      profile: profile,
      walkingKmToday: curWalk + walkKm,
      runningKmToday: curRun + runKm,
      otherCardioMinutes: curOther + mins,
    );
    return (after - before).clamp(0, 100000).toInt();
  }

  Future<void> _save() async {
    if (_saving) return;
    final runKm = double.tryParse(_run.text.trim()) ?? 0;
    final walkKm = double.tryParse(_walk.text.trim()) ?? 0;
    final mins = int.tryParse(_otherMin.text.trim()) ?? 0;
    if (runKm <= 0 && walkKm <= 0 && mins <= 0) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final bw = ref.read(profileStreamProvider).valueOrNull?.weightKg ?? 0;
    // Calorie aggregate (drives target app-wide).
    final nutrition = ref.read(nutritionRepoProvider);
    final log = await nutrition.getOrCreateLog(now);
    await nutrition.upsertDailyLog(
      now,
      runningKmToday: log.runningKmToday + runKm,
      walkingKmToday: log.walkingKmToday + walkKm,
      otherCardioMinutes: log.otherCardioMinutes + mins,
    );
    // Per-bout history — one CardioSession per non-empty part.
    final cardio = ref.read(cardioRepoProvider);
    final key = CardioSession.keyFor(now);
    if (runKm > 0) {
      await cardio.add(CardioSession()
        ..dateKey = key
        ..type = CardioType.run
        ..startedAt = now
        ..distanceKm = runKm
        ..calories = CardioMath.distanceCalories(
            isRun: true, km: runKm, bodyweightKg: bw));
    }
    if (walkKm > 0) {
      await cardio.add(CardioSession()
        ..dateKey = key
        ..type = CardioType.walk
        ..startedAt = now
        ..distanceKm = walkKm
        ..calories = CardioMath.distanceCalories(
            isRun: false, km: walkKm, bodyweightKg: bw));
    }
    if (mins > 0) {
      await cardio.add(CardioSession()
        ..dateKey = key
        ..type = _otherType
        ..startedAt = now
        ..durationSeconds = mins * 60
        ..calories = CardioMath.estimateCalories(
            type: _otherType, minutes: mins, bodyweightKg: bw));
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
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
              Text('Log activity', style: AppText.sectionTitle),
              const SizedBox(height: 2),
              Text('Mix and match — run, walk and other in one go.',
                  style: AppText.meta.copyWith(fontSize: 12)),
              const SizedBox(height: 16),
              // Run + walk by distance.
              Row(
                children: [
                  Expanded(
                      child: _numField(_run, 'RUN', 'km',
                          Icons.directions_run_rounded)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _numField(_walk, 'WALK', 'km',
                          Icons.directions_walk_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              Text('OTHER CARDIO', style: AppText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in CardioMath.otherTypes)
                    GestureDetector(
                      onTap: () => setState(() => _otherType = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _otherType == t
                              ? AppColors.accent
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _otherType == t
                                  ? AppColors.accent
                                  : AppColors.stroke),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CardioMath.icon(t),
                                size: 14,
                                color: _otherType == t
                                    ? AppColors.onAccent
                                    : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(CardioMath.label(t),
                                style: TextStyle(
                                  color: _otherType == t
                                      ? AppColors.onAccent
                                      : AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _numField(_otherMin, 'DURATION', 'min', Icons.schedule_rounded),
              const SizedBox(height: 16),
              // Live calorie estimate.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('≈ $_kcal kcal',
                        style: AppText.sectionTitle.copyWith(fontSize: 18)),
                    const Spacer(),
                    Text('added to today',
                        style: AppText.meta.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: AppColors.onAccent))
                      : Text('Save',
                          style: AppText.body.copyWith(
                              color: AppColors.onAccent,
                              fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(
      TextEditingController c, String label, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(label, style: AppText.label.copyWith(fontSize: 9)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: AppText.sectionTitle.copyWith(fontSize: 20),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    hintText: '0',
                  ),
                ),
              ),
              Text(unit,
                  style: AppText.meta.copyWith(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
