import '../../data/models/daily_log.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/profile.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/nutrition_repo.dart';
import '../../home/todays_activity_card.dart' show TodaysActivityMath;
import '../../services/progress/weight_trend.dart';
import '../../services/workout/pr_tracker.dart';

/// Centralises the user-context strings that every AI surface (coach chat,
/// weekly review, meal suggestions, food analysis, target advisory) needs.
///
/// Before this class, context was built independently in [coach_page.dart]
/// and [dashboard_page.dart] — 300+ lines of duplicated string assembly.
/// Now every AI call site constructs a [UserContextBuilder] and picks the
/// level of detail it needs.
class UserContextBuilder {
  const UserContextBuilder({
    required this.profile,
    required this.totals,
    this.todayLog,
    this.recentFoods = const [],
    this.recentLogs = const [],
    this.recentSessions = const [],
    this.weightTrend,
    this.streak = 0,
    this.prCount = 0,
    this.sessionsThisWeek = 0,
  });

  final Profile profile;
  final DailyTotals totals;
  final DailyLog? todayLog;
  final List<FoodEntry> recentFoods;
  final List<DailyLog> recentLogs;
  final List<WorkoutSession> recentSessions;
  final WeightTrend? weightTrend;
  final int streak;
  final int prCount;
  final int sessionsThisWeek;

  // ---------------------------------------------------------------------------
  // Full context — for coach chat and weekly review.
  // ---------------------------------------------------------------------------

  /// Comprehensive context string covering profile, today's intake, recent
  /// history, weight trend, streak, PRs and workout feedback.  Mirrors the
  /// old `_profileSummary()` from coach_page and `_buildCoachContext()` from
  /// dashboard, combined into a single canonical source.
  String buildFullContext() {
    final goal = profile.goal.name;
    final focus = profile.bodyFocusNotes.trim();

    final todayBaseTarget = profile.effectiveCalorieTarget;
    final todayCalTarget = TodaysActivityMath.effectiveTodayCalorieTarget(
      profile: profile,
      log: todayLog,
    );
    final todayBonus = todayCalTarget - todayBaseTarget;

    // Per-day breakdown for last 6 days.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logsByKey = <String, DailyLog>{
      for (final l in recentLogs) l.dateKey: l,
    };
    final foodsByKey = <String, List<FoodEntry>>{};
    for (final f in recentFoods) {
      (foodsByKey[f.dateKey] ??= []).add(f);
    }
    final sessionsByKey = <String, List<WorkoutSession>>{};
    for (final s in recentSessions) {
      (sessionsByKey[s.dateKey] ??= []).add(s);
    }

    final perDay = <String>[];
    for (var i = 1; i <= 6; i++) {
      final day = today.subtract(Duration(days: i));
      final key = _dateKey(day);
      final foods = foodsByKey[key] ?? const <FoodEntry>[];
      final log = logsByKey[key];
      final sessions = sessionsByKey[key] ?? const <WorkoutSession>[];

      if (foods.isEmpty && sessions.isEmpty && log == null) {
        perDay.add(i == 1
            ? '- Yesterday: nothing logged'
            : '- ${_weekdayShort(day)} ${day.month}/${day.day}: nothing logged');
        continue;
      }

      int c = 0, p = 0, cb = 0, f = 0, fb = 0;
      for (final e in foods) {
        c += e.calories;
        p += e.proteinG;
        cb += e.carbsG;
        f += e.fatG;
        fb += e.fiberG;
      }

      final dayCalTarget = TodaysActivityMath.effectiveTodayCalorieTarget(
        profile: profile,
        log: log,
      );
      final delta = c - dayCalTarget;
      final deltaLabel = delta == 0
          ? 'on target'
          : delta > 0
              ? '+$delta over'
              : '${-delta} under';

      final actBits = <String>[];
      if (log != null) {
        if (log.walkingKmToday > 0) {
          actBits.add('${log.walkingKmToday.toStringAsFixed(1)}km walk');
        }
        if (log.runningKmToday > 0) {
          actBits.add('${log.runningKmToday.toStringAsFixed(1)}km run');
        }
        if (log.otherCardioMinutes > 0) {
          actBits.add('${log.otherCardioMinutes}min cardio');
        }
      }
      if (sessions.isNotEmpty) {
        final mins =
            sessions.fold<int>(0, (s, w) => s + w.duration.inMinutes);
        actBits.add(
            '${sessions.length} workout${sessions.length == 1 ? '' : 's'} ($mins min)');
      }
      final dayBonus = dayCalTarget - profile.effectiveCalorieTarget;
      final actDetail = actBits.isEmpty
          ? ''
          : ' · activity: ${actBits.join(', ')}'
              '${dayBonus > 0 ? ' (+$dayBonus kcal earned, already added to target)' : ''}';

      final label = i == 1
          ? 'Yesterday'
          : '${_weekdayShort(day)} ${day.month}/${day.day}';
      perDay.add('- $label: ate $c / target $dayCalTarget kcal '
          '($deltaLabel) · P${p}g C${cb}g F${f}g, fiber ${fb}g$actDetail');
    }

    // Recent set feeling.
    final feelingLine = _recentSetFeelingSummary(recentSessions);

    return [
      'Name: ${profile.displayName.isEmpty ? "user" : profile.displayName}',
      'Goal: $goal',
      if (profile.country.isNotEmpty) 'Country: ${profile.country}',
      'Diet: ${profile.dietPreference.name}',
      'Today\'s calorie target: $todayCalTarget kcal'
          '${todayBonus > 0 ? ' (= $todayBaseTarget base + $todayBonus from today\'s activity)' : ' (base)'}',
      'Protein target: ${profile.effectiveProteinTarget}g',
      'Weight: ${profile.weightKg.toStringAsFixed(1)} kg',
      'Strength training: ${profile.trainingDaysPerWeek} days/week',
      'Cardio: ${profile.cardioSessionsPerWeek} sessions/week',
      if (feelingLine != null) feelingLine,
      if (focus.isNotEmpty) 'Body focus: $focus',
      if (profile.restDays.isNotEmpty)
        'Rest days: ${profile.restDays.join(",")}',
      if (profile.gymStartDate != null)
        'Gym experience: ${DateTime.now().difference(profile.gymStartDate!).inDays ~/ 30} months',
      if (profile.bodyFatPct != null)
        'Body fat: ${profile.bodyFatPct!.toStringAsFixed(0)}%',
      if (profile.healthFlags.isNotEmpty)
        'Health flags: ${profile.healthFlags.map((f) => f.name).join(", ")}',
      if (profile.gender == Gender.female &&
          profile.cyclePhase != CyclePhase.unknown)
        'Cycle phase: ${profile.cyclePhase.name}',
      'Today so far: ${totals.calories} kcal · ${totals.proteinG}g P · '
          '${totals.carbsG}g C · ${totals.fatG}g F · fiber ${totals.fiberG}g · '
          'sodium ${totals.sodiumMg}mg',
      'Water today: ${totals.waterMl} ml of ${profile.effectiveWaterTarget} ml '
          'target · fiber target ${profile.effectiveFiberTarget} g/day.',
      'Current streak: $streak days',
      'PRs achieved: $prCount',
      'Workouts this week: $sessionsThisWeek',
      if (weightTrend != null && weightTrend!.toContextLines().isNotEmpty) weightTrend!.toContextLines(),
      if (perDay.isNotEmpty)
        'Last 6 days (use this for history questions):\n${perDay.join('\n')}',
    ].join('\n');
  }

  // ---------------------------------------------------------------------------
  // Light context — for food analysis, meal suggestions, target advisory.
  // ---------------------------------------------------------------------------

  /// Compact context with profile basics + today's intake.  Useful for
  /// operations that don't need full history but benefit from knowing the
  /// user's diet, goals and what they've already eaten today.
  String buildLightContext() {
    final calTarget = TodaysActivityMath.effectiveTodayCalorieTarget(
      profile: profile,
      log: todayLog,
    );
    final macros = TodaysActivityMath.effectiveTodayMacros(
      profile: profile,
      log: todayLog,
    );
    final calLeft = (calTarget - totals.calories).clamp(0, 99999);
    final protLeft = (macros.proteinG - totals.proteinG).clamp(0, 99999);
    final carbLeft = (macros.carbG - totals.carbsG).clamp(0, 99999);
    final fatLeft = (macros.fatG - totals.fatG).clamp(0, 99999);

    return [
      'Name: ${profile.displayName.isEmpty ? "user" : profile.displayName}',
      'Goal: ${profile.goal.name}',
      if (profile.country.isNotEmpty) 'Country: ${profile.country}',
      'Diet: ${profile.dietPreference.name}',
      if (profile.healthFlags.isNotEmpty)
        'Health flags: ${profile.healthFlags.map((f) => f.name).join(", ")}',
      if (profile.bodyFocusNotes.isNotEmpty)
        'Body focus: ${profile.bodyFocusNotes}',
      'Weight: ${profile.weightKg.toStringAsFixed(1)} kg',
      'Daily target: $calTarget kcal · P${macros.proteinG}g C${macros.carbG}g F${macros.fatG}g',
      'Today consumed: ${totals.calories} kcal · '
          'P${totals.proteinG}g C${totals.carbsG}g F${totals.fatG}g',
      'Remaining: $calLeft kcal · P${protLeft}g C${carbLeft}g F${fatLeft}g',
    ].join('\n');
  }

  // ---------------------------------------------------------------------------
  // Per-day summary — for weekly review (7-day window, Mon-first).
  // ---------------------------------------------------------------------------

  /// Builds a Mon-first 7-day breakdown with activity-adjusted targets and
  /// hit-count scoreboard.  Used by the weekly review surface.
  String buildWeeklySummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final since = today.subtract(const Duration(days: 6));

    final weekFoods =
        recentFoods.where((f) => !f.timestamp.isBefore(since)).toList();
    final weekSessions =
        recentSessions.where((s) => !s.startedAt.isBefore(since)).toList();
    final weekLogs = recentLogs.where((l) {
      final parsed = DateTime.tryParse(l.dateKey);
      return parsed != null && !parsed.isBefore(since);
    }).toList();

    final foodsByKey = <String, List<FoodEntry>>{};
    for (final f in weekFoods) {
      (foodsByKey[f.dateKey] ??= []).add(f);
    }
    final logsByKey = <String, DailyLog>{for (final l in weekLogs) l.dateKey: l};
    final sessionsByKey = <String, List<WorkoutSession>>{};
    for (final s in weekSessions) {
      (sessionsByKey[s.dateKey] ??= []).add(s);
    }

    int daysLogged = 0;
    int daysWithinKcalBand = 0;
    int daysHitProtein = 0;
    int daysOver20Pct = 0;
    int totalKcal = 0;
    final perDay = <String>[];

    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key = _dateKey(day);
      final dayFoods = foodsByKey[key] ?? const <FoodEntry>[];
      final log = logsByKey[key];
      final daySessions = sessionsByKey[key] ?? const <WorkoutSession>[];

      if (dayFoods.isEmpty && daySessions.isEmpty && log == null) {
        perDay.add('- ${_weekdayShort(day)}: nothing logged');
        continue;
      }
      daysLogged++;

      int c = 0, p = 0;
      for (final e in dayFoods) {
        c += e.calories;
        p += e.proteinG;
      }
      totalKcal += c;

      final dayCalT = TodaysActivityMath.effectiveTodayCalorieTarget(
        profile: profile,
        log: log,
      );
      final dayMac = TodaysActivityMath.effectiveTodayMacros(
        profile: profile,
        log: log,
      );
      final deltaPct = dayCalT == 0 ? 0.0 : (c - dayCalT) / dayCalT;
      if (deltaPct.abs() <= 0.10 && c > 0) daysWithinKcalBand++;
      if (deltaPct > 0.20) daysOver20Pct++;
      if (dayMac.proteinG > 0 && p >= dayMac.proteinG * 0.9) {
        daysHitProtein++;
      }

      final actBits = <String>[];
      if (log != null) {
        if (log.walkingKmToday > 0) {
          actBits.add('${log.walkingKmToday.toStringAsFixed(1)}km walk');
        }
        if (log.runningKmToday > 0) {
          actBits.add('${log.runningKmToday.toStringAsFixed(1)}km run');
        }
        if (log.otherCardioMinutes > 0) {
          actBits.add('${log.otherCardioMinutes}min cardio');
        }
      }
      if (daySessions.isNotEmpty) {
        actBits.add(
            '${daySessions.length} workout${daySessions.length == 1 ? '' : 's'}');
      }
      final delta = c - dayCalT;
      final dLabel = delta == 0
          ? 'on target'
          : delta > 0
              ? '+$delta over'
              : '${-delta} under';
      final actTail = actBits.isEmpty ? '' : ' · ${actBits.join(', ')}';
      perDay.add(
          '- ${_weekdayShort(day)}: $c/$dayCalT kcal ($dLabel) · P${p}g$actTail');
    }

    final avgKcal = daysLogged == 0 ? 0 : (totalKcal / daysLogged).round();
    final plannedSessions = profile.trainingDaysPerWeek;
    final actualSessions =
        weekSessions.where((s) => s.completedAt != null).length;
    final skippedSessions =
        (plannedSessions - actualSessions).clamp(0, plannedSessions);
    final prs = PrTracker.personalRecords(recentSessions);

    return [
      'Goal: ${profile.goal.name}',
      if (profile.country.isNotEmpty) 'Country: ${profile.country}',
      'Diet: ${profile.dietPreference.name}',
      if (profile.bodyFocusNotes.isNotEmpty)
        'Body focus: ${profile.bodyFocusNotes}',
      'Base targets: ${profile.effectiveCalorieTarget} kcal · '
          '${profile.effectiveProteinTarget}g P',
      'Week scoreboard: $daysLogged/7 days logged · '
          '$daysWithinKcalBand/7 within ±10% kcal band · '
          '$daysHitProtein/7 hit protein (≥90% of target) · '
          '$daysOver20Pct/7 over by 20%+',
      'Avg kcal on logged days: $avgKcal',
      'Workouts: $actualSessions completed vs $plannedSessions planned · '
          '$skippedSessions skipped',
      'Total PRs ever: ${prs.length}',
      if (weightTrend != null && weightTrend!.toContextLines().isNotEmpty) weightTrend!.toContextLines(),
      if (perDay.isNotEmpty)
        'Per-day breakdown:\n${perDay.join('\n')}',
    ].join('\n');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _weekdayShort(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }

  static String? _recentSetFeelingSummary(List<WorkoutSession> sessions) {
    final counts = <SetFeeling, int>{};
    final painExercises = <String>{};
    for (final s in sessions) {
      for (final set in s.sets) {
        if (set.feeling == SetFeeling.unset) continue;
        counts[set.feeling] = (counts[set.feeling] ?? 0) + 1;
        if (set.feeling == SetFeeling.pain) {
          painExercises.add(set.exerciseName);
        }
      }
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return null;

    final parts = <String>[];
    if (painExercises.isNotEmpty) {
      parts.add('⚠️ user flagged PAIN on: ${painExercises.join(", ")} '
          '(advise caution / suggest a swap or lighter load)');
    }
    final easy =
        (counts[SetFeeling.easy] ?? 0) + (counts[SetFeeling.good] ?? 0);
    final hard =
        (counts[SetFeeling.hard] ?? 0) + (counts[SetFeeling.brutal] ?? 0);
    if (easy > hard * 2 && easy > 3) {
      parts.add(
          'most recent sets felt easy/good — room to add load or reps');
    } else if (hard > easy * 2 && hard > 3) {
      parts.add(
          'most recent sets felt hard/brutal — near capacity, '
          'consider holding weight or a deload');
    }
    if (parts.isEmpty) return null;
    return 'Set feedback: ${parts.join(". ")}';
  }
}
