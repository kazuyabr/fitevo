import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/routine.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import 'exercise_detail_page.dart';
import 'substitute_sheet.dart';
import 'workout_logger_page.dart';
import 'workout_photos.dart';

/// Detail page for a single [RoutineDay] — hero photo + kcal/duration
/// meta + Start Workout CTA + exercise cards. Matches the reference
/// design but themed with our palette (accent = orange, dark surface).
class RoutineDayDetailPage extends ConsumerStatefulWidget {
  final RoutineDay day;
  final String routineName;

  const RoutineDayDetailPage({
    super.key,
    required this.day,
    required this.routineName,
  });

  @override
  ConsumerState<RoutineDayDetailPage> createState() =>
      _RoutineDayDetailPageState();
}

class _RoutineDayDetailPageState extends ConsumerState<RoutineDayDetailPage> {
  // First image URL per exercise, resolved lazily via the image service.
  final Map<int, String?> _exImage = {};

  @override
  void initState() {
    super.initState();
    _prefetchImages();
  }

  /// Swap an exercise for one hitting the same muscle, and persist it to
  /// the active routine.
  Future<void> _substitute(RoutinePlanItem item) async {
    final oldId = item.exerciseId;
    final oldName = item.exerciseName;
    final chosen = await SubstituteSheet.show(
      context,
      exerciseId: oldId,
      exerciseName: oldName,
    );
    if (chosen == null || !mounted) return;
    final repo = ref.read(workoutRepoProvider);
    final routine = await repo.getActiveRoutine();
    if (routine != null) {
      for (final d in routine.days) {
        if (d.weekday != widget.day.weekday) continue;
        for (final it in d.items) {
          if (it.exerciseId == oldId && it.exerciseName == oldName) {
            it.exerciseId = chosen.id;
            it.exerciseName = chosen.name;
            it.restSeconds = chosen.defaultRestSeconds;
          }
        }
      }
      await repo.saveRoutine(routine);
    }
    // Reflect in the current view immediately.
    for (final it in widget.day.items) {
      if (it.exerciseId == oldId && it.exerciseName == oldName) {
        it.exerciseId = chosen.id;
        it.exerciseName = chosen.name;
        it.restSeconds = chosen.defaultRestSeconds;
      }
    }
    if (mounted) {
      setState(() {});
      _prefetchImages();
    }
  }

  /// Toggle a superset link between exercise [i] and the next one — they
  /// then interleave with no rest between them in the workout.
  Future<void> _toggleSuperset(int i) async {
    final items = widget.day.items;
    if (i < 0 || i >= items.length - 1) return;
    final a = items[i];
    final b = items[i + 1];
    final linked = a.supersetGroup != null && a.supersetGroup == b.supersetGroup;
    final int? newGroup;
    if (linked) {
      newGroup = null; // unlink
    } else {
      // New group id — max existing + 1.
      final maxG = items.fold<int>(
          0, (m, it) => (it.supersetGroup ?? 0) > m ? it.supersetGroup! : m);
      newGroup = maxG + 1;
    }
    void apply(List<dynamic> list) {
      // Match by exerciseId pair at adjacent positions.
      for (var j = 0; j < list.length - 1; j++) {
        if (list[j].exerciseId == a.exerciseId &&
            list[j + 1].exerciseId == b.exerciseId) {
          list[j].supersetGroup = newGroup;
          list[j + 1].supersetGroup = newGroup;
        }
      }
    }

    final repo = ref.read(workoutRepoProvider);
    final routine = await repo.getActiveRoutine();
    if (routine != null) {
      for (final d in routine.days) {
        if (d.weekday == widget.day.weekday) apply(d.items);
      }
      await repo.saveRoutine(routine);
    }
    apply(widget.day.items);
    if (mounted) setState(() {});
  }

  Future<void> _prefetchImages() async {
    final svc = ref.read(exerciseImageServiceProvider);
    for (final item in widget.day.items) {
      if (_exImage.containsKey(item.exerciseId)) continue;
      final url = await svc.firstImageFor(item.exerciseName);
      if (!mounted) return;
      setState(() => _exImage[item.exerciseId] = url);
    }
  }

  int _estKcal() {
    // Rough estimate: ~7 kcal per working set for gym workouts.
    final sets = widget.day.items.fold<int>(0, (s, i) => s + i.targetSets);
    return sets * 7;
  }

  int _estMinutes() {
    // Rough estimate per exercise: sets × (~45s work + rest) + 1min setup.
    int total = 0;
    for (final item in widget.day.items) {
      final perSet = 45 + item.restSeconds;
      total += 60 + (item.targetSets * perSet);
    }
    return (total / 60).round();
  }

  String _fmtDuration(int mins) {
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _timeLabel(int restSeconds, int sets) {
    // "1:35 min" style — total exercise time in mm:ss.
    final total = sets * (45 + restSeconds);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')} min';
  }

  String _dayName(int w) => switch (w) {
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
        7 => 'Sunday',
        _ => 'today',
      };

  /// Confirms with the user before starting a workout that isn't the
  /// one scheduled for today's weekday. Unassigned days (weekday == 0)
  /// and days that match today skip the prompt.
  Future<void> _confirmAndStart() async {
    final scheduled = widget.day.weekday;
    final today = DateTime.now().weekday;
    if (scheduled == 0 || scheduled == today) {
      _startLogger();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.event_busy_rounded,
                        size: 18, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Not today\'s workout',
                        style: AppText.sectionTitle.copyWith(fontSize: 17)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Today is ${_dayName(today)}. "${widget.day.name}" is scheduled for ${_dayName(scheduled)}. Start anyway?',
                style: AppText.body,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Start anyway',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) _startLogger();
  }

  void _startLogger() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutLoggerPage(
          routineName: widget.routineName,
          day: widget.day,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ── Hero photo header ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _Hero(
              dayName: day.name,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Title + meta pills + Start CTA ────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.name,
                    style: AppText.sectionTitle.copyWith(
                      fontSize: 26,
                      letterSpacing: -0.4,
                    ),
                  ).animate().fadeIn(delay: 80.ms, duration: 260.ms),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '${_estKcal()} Kcal',
                        color: AppColors.calorieTo,
                      ),
                      _MetaPill(
                        icon: Icons.schedule_rounded,
                        label: _fmtDuration(_estMinutes()),
                        color: AppColors.water,
                      ),
                      _MetaPill(
                        icon: Icons.fitness_center_rounded,
                        label: '${day.items.length} exercises',
                        color: AppColors.accent,
                      ),
                    ],
                  ).animate().fadeIn(delay: 140.ms, duration: 260.ms),
                  const SizedBox(height: 20),
                  _StartWorkoutCta(
                    onTap: _confirmAndStart,
                  ).animate()
                      .fadeIn(delay: 200.ms, duration: 260.ms)
                      .slideY(begin: 0.15, end: 0),
                ],
              ),
            ),
          ),

          // ── Section label ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                'EXERCISES',
                style: AppText.label.copyWith(letterSpacing: 1.4),
              ),
            ),
          ),

          // ── Exercise cards ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              itemCount: day.items.length,
              itemBuilder: (context, i) {
                final item = day.items[i];
                final next = i < day.items.length - 1 ? day.items[i + 1] : null;
                final linkedNext = next != null &&
                    item.supersetGroup != null &&
                    item.supersetGroup == next.supersetGroup;
                return Column(
                  children: [
                    _ExerciseRow(
                      imageUrl: _exImage[item.exerciseId],
                      name: item.exerciseName,
                      superset: item.supersetGroup != null,
                      timeLabel:
                          _timeLabel(item.restSeconds, item.targetSets),
                      setsRepsLabel:
                          '${item.targetSets} × ${item.targetRepsLow}-${item.targetRepsHigh}',
                      onSwap: () => _substitute(item),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailPage(
                              exerciseId: item.exerciseId,
                              planItem: item,
                            ),
                          ),
                        );
                      },
                    ),
                    // Link-with-next control (superset).
                    if (next != null)
                      GestureDetector(
                        onTap: () => _toggleSuperset(i),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                linkedNext
                                    ? Icons.link_rounded
                                    : Icons.add_link_rounded,
                                size: 14,
                                color: linkedNext
                                    ? AppColors.accent
                                    : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                linkedNext ? 'Superset' : 'Superset with next',
                                style: AppText.meta.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: linkedNext
                                      ? AppColors.accent
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                  ],
                )
                    .animate(delay: (60 * i).ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Hero header ───────────────────────

class _Hero extends StatelessWidget {
  final String dayName;
  final VoidCallback onBack;
  const _Hero({required this.dayName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final photoUrl = WorkoutPhotos.networkUrlFor(dayName);
    final gradient = WorkoutPhotos.gradientFor(dayName);
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: BoxDecoration(gradient: gradient)),
          CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 400),
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
          // Bottom fade so the title area behind the hero blends into bg.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.05),
                  AppColors.bg,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Meta pill ───────────────────────

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────── Start Workout CTA ───────────────────────

class _StartWorkoutCta extends StatelessWidget {
  final VoidCallback onTap;
  const _StartWorkoutCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Two separate accent shapes of the same height, joined by a thin
    // horizontal bar that overlaps INTO both so the seam is invisible.
    // The play circle carries a small dark inner disc with the icon on
    // top — a "button inside a button" for extra depth.
    const size = 56.0;
    const barWidth = 18.0;
    const barOverlap = 6.0; // how much the bar tucks into each side
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Pill on the left — full width minus (circle + gap area)
            Positioned(
              left: 0,
              right: size + barWidth - (2 * barOverlap),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(size / 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Start Workout',
                  style: TextStyle(
                    color: AppColors.onAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            // Connecting bar — sits centred vertically, overlapping into
            // both the pill (left) and the circle (right) so the joins
            // read as one continuous colour with no visible gap.
            Positioned(
              right: size - barOverlap,
              top: (size - 10) / 2,
              child: Container(
                width: barWidth,
                height: 10,
                color: AppColors.accent,
              ),
            ),
            // Play circle on the right — same height as the pill. Has an
            // inner dark disc holding the play icon.
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                // Inner dark disc — separate background inside the well.
                child: Container(
                  width: size - 16,
                  height: size - 16,
                  decoration: BoxDecoration(
                    color: AppColors.onAccent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.play_arrow_rounded,
                      size: 22, color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Exercise row ───────────────────────

class _ExerciseRow extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String timeLabel;
  final String setsRepsLabel;
  final VoidCallback onTap;
  final VoidCallback? onSwap;
  final bool superset;

  const _ExerciseRow({
    required this.imageUrl,
    required this.name,
    required this.timeLabel,
    required this.setsRepsLabel,
    required this.onTap,
    this.onSwap,
    this.superset = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl == null
                  ? Icon(Icons.fitness_center_rounded,
                      color: AppColors.textTertiary)
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 240),
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => Icon(
                          Icons.fitness_center_rounded,
                          color: AppColors.textTertiary),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (superset) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('SS',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: AppText.meta.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.repeat_rounded,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        setsRepsLabel,
                        style: AppText.meta.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSwap != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onSwap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Icon(Icons.swap_horiz_rounded,
                      size: 17, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.play_arrow_rounded,
                  size: 18, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
