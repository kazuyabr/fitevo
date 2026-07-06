import '../../data/models/enums.dart';
import '../../data/models/routine.dart';
import '../../data/models/workout_session.dart';
import 'pr_tracker.dart';

/// What the coach recommends doing on the next set/session for an exercise.
enum ProgressionAction {
  buildBase, // no history yet — just log a solid first session
  addWeight,
  addReps,
  hold,
  backOff, // pain or a bad grind — reduce load
}

class ProgressionAdvice {
  final ProgressionAction action;
  final String headline;
  final String detail;
  final double? suggestedWeightKg;
  final int? suggestedReps;
  const ProgressionAdvice({
    required this.action,
    required this.headline,
    required this.detail,
    this.suggestedWeightKg,
    this.suggestedReps,
  });
}

/// Per-exercise plateau read.
class PlateauInfo {
  final int exerciseId;
  final String exerciseName;
  final int stalledSessions;
  const PlateauInfo({
    required this.exerciseId,
    required this.exerciseName,
    required this.stalledSessions,
  });
}

/// Whole-program fatigue read that suggests a lighter week.
class DeloadSignal {
  final int painFlags;
  final int brutalSets;
  final String reason;
  const DeloadSignal({
    required this.painFlags,
    required this.brutalSets,
    required this.reason,
  });
}

/// Turns logged history — weight, reps, RIR (stored as RPE) and the
/// rest-screen "feeling" — into concrete next-session recommendations.
/// This is the "coach brain" that upgrades the app from a logbook into a
/// program: it decides when to add load, when to hold, and when to back off.
class ProgressionCoach {
  /// Recommendation for the next time the user trains [item], based on the
  /// most recent completed sets for it. Working sets only (warmups skipped).
  static ProgressionAdvice nextTarget({
    required RoutinePlanItem item,
    required List<SetEntry> previousSets,
  }) {
    final working =
        previousSets.where((s) => s.setType != SetType.warmup).toList();
    if (working.isEmpty) {
      return const ProgressionAdvice(
        action: ProgressionAction.buildBase,
        headline: 'First time — find your working weight',
        detail: 'Pick a weight you can control for the full rep range.',
      );
    }

    // Pain anywhere in the last effort dominates everything else.
    final hadPain = working.any((s) => s.feeling == SetFeeling.pain);
    final lastWeight = working.first.weightKg;
    if (hadPain) {
      final drop = _round(lastWeight * 0.9);
      return ProgressionAdvice(
        action: ProgressionAction.backOff,
        headline: 'You flagged pain last time',
        detail: lastWeight > 0
            ? 'Drop to ${_fmt(drop)} kg and focus on clean reps, or swap the movement.'
            : 'Ease off and focus on pain-free range of motion, or swap the movement.',
        suggestedWeightKg: lastWeight > 0 ? drop : null,
      );
    }

    final avgReps =
        working.map((s) => s.reps).reduce((a, b) => a + b) / working.length;
    final high = item.targetRepsHigh;
    final low = item.targetRepsLow;
    final hitTop = avgReps >= high - 0.5;
    final missedBottom = avgReps < low;

    // Effort signal: lowest RIR across the sets (closest to failure) plus
    // whether any set felt brutal. RPE stored as 10 - RIR.
    final rpes = working.map((s) => s.rpe).whereType<double>().toList();
    final maxRpe = rpes.isEmpty ? null : rpes.reduce((a, b) => a > b ? a : b);
    final feltBrutal = working.any((s) => s.feeling == SetFeeling.brutal);
    final feltEasy = working.every((s) =>
        s.feeling == SetFeeling.easy ||
        s.feeling == SetFeeling.good ||
        s.feeling == SetFeeling.unset);

    // Bodyweight movement — progress by reps.
    if (lastWeight <= 0) {
      if (hitTop && (maxRpe == null || maxRpe < 9)) {
        return ProgressionAdvice(
          action: ProgressionAction.addReps,
          headline: 'Add a rep',
          detail: 'You topped the range cleanly — push one more rep per set.',
          suggestedReps: high + 1,
        );
      }
      return const ProgressionAdvice(
        action: ProgressionAction.hold,
        headline: 'Hold and own the reps',
        detail: 'Keep the same target and tighten your form.',
      );
    }

    // Loaded movement.
    if (hitTop && !feltBrutal && (maxRpe == null || maxRpe <= 8)) {
      // Left reps in reserve at the top of the range → clear progression.
      // Bigger jump when it genuinely felt easy.
      final bigJump = feltEasy && (maxRpe == null || maxRpe <= 7);
      final next = _round(lastWeight + (bigJump ? 5 : 2.5));
      return ProgressionAdvice(
        action: ProgressionAction.addWeight,
        headline: 'Add weight → ${_fmt(next)} kg',
        detail: bigJump
            ? 'Last session felt easy at the top of the range — take a full jump.'
            : 'You hit the top of the range — nudge the load up.',
        suggestedWeightKg: next,
        suggestedReps: low,
      );
    }
    if (missedBottom || feltBrutal || (maxRpe != null && maxRpe >= 9.5)) {
      // Struggled — hold to consolidate rather than pile on more.
      return ProgressionAdvice(
        action: ProgressionAction.hold,
        headline: 'Hold ${_fmt(lastWeight)} kg',
        detail: feltBrutal
            ? 'That was near your limit — repeat it and aim for cleaner reps.'
            : 'Stay here until you own the full rep range.',
        suggestedWeightKg: lastWeight,
      );
    }
    // Mid-range — same weight, chase more reps.
    return ProgressionAdvice(
      action: ProgressionAction.addReps,
      headline: 'Same weight, chase reps',
      detail: 'Keep ${_fmt(lastWeight)} kg and work toward $high reps.',
      suggestedWeightKg: lastWeight,
      suggestedReps: (avgReps.round() + 1).clamp(low, high),
    );
  }

  /// Detects a plateau on an exercise: its best estimated-1RM hasn't
  /// improved across the last [window] sessions that trained it. Returns
  /// null when there's not enough history or progress is still happening.
  static PlateauInfo? plateau(
    List<WorkoutSession> sessions,
    int exerciseId, {
    int window = 3,
  }) {
    // Best e1RM per session (most recent first) where the exercise appears.
    final perSession = <(DateTime, double, String)>[];
    for (final s in sessions) {
      double best = 0;
      String name = '';
      for (final set in s.sets) {
        if (set.exerciseId != exerciseId) continue;
        if (set.setType == SetType.warmup) continue;
        final e = PrTracker.estimatedFromSet(set);
        if (e > best) {
          best = e;
          name = set.exerciseName;
        }
      }
      if (best > 0) perSession.add((s.startedAt, best, name));
    }
    if (perSession.length < window) return null;
    perSession.sort((a, b) => b.$1.compareTo(a.$1));
    final recent = perSession.take(window).toList();
    // The most recent best is no better than the oldest in the window
    // (within 1% noise) → stalled.
    final newest = recent.first.$2;
    final oldest = recent.last.$2;
    if (newest <= oldest * 1.01) {
      return PlateauInfo(
        exerciseId: exerciseId,
        exerciseName: recent.first.$3,
        stalledSessions: window,
      );
    }
    return null;
  }

  /// Whole-program fatigue read across [recentSessions] (pass the last
  /// ~6–8 sessions). Fires when pain and/or a pile of brutal sets suggest
  /// the user should take a lighter week. Null = keep training as normal.
  static DeloadSignal? deloadSignal(List<WorkoutSession> recentSessions) {
    // Only consider the last two weeks of work.
    final cutoff = _now(recentSessions).subtract(const Duration(days: 14));
    var pain = 0;
    var brutal = 0;
    var considered = 0;
    for (final s in recentSessions) {
      if (s.startedAt.isBefore(cutoff)) continue;
      considered++;
      for (final set in s.sets) {
        if (set.feeling == SetFeeling.pain) pain++;
        if (set.feeling == SetFeeling.brutal) brutal++;
      }
    }
    if (considered < 3) return null; // too little data to call it
    if (pain >= 2) {
      return DeloadSignal(
        painFlags: pain,
        brutalSets: brutal,
        reason:
            'You\'ve flagged pain $pain times recently — take a lighter week to recover.',
      );
    }
    if (brutal >= 6) {
      return DeloadSignal(
        painFlags: pain,
        brutalSets: brutal,
        reason:
            'Lots of near-failure sets lately — a deload week will let you come back stronger.',
      );
    }
    return null;
  }

  // Latest session start among the list, so the 14-day window is relative
  // to the user's actual last workout (Date.now() isn't available in some
  // pure contexts and keeps this testable).
  static DateTime _now(List<WorkoutSession> sessions) {
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final s in sessions) {
      if (s.startedAt.isAfter(latest)) latest = s.startedAt;
    }
    return latest == DateTime.fromMillisecondsSinceEpoch(0)
        ? DateTime.now()
        : latest;
  }

  static double _round(double w) => (w / 2.5).round() * 2.5;

  static String _fmt(double w) =>
      w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}
