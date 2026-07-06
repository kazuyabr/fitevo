import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../data/models/routine.dart';
import '../../data/repositories/exercise_repo.dart';
import '../../data/repositories/workout_repo.dart';
import '../ai/ai_service.dart';

class RoutineGenerator {
  RoutineGenerator({
    required this.ai,
    required this.exercises,
    required this.workouts,
  });

  final AiService ai;
  final ExerciseRepo exercises;
  final WorkoutRepo workouts;

  /// Generates a routine via AI, persists it to the database, marks it
  /// active, and returns the saved Routine.
  Future<Routine> generateAndActivate({
    required FitnessGoal goal,
    required int trainingDaysPerWeek,
    List<int> restDays = const [],
    WorkoutType workoutType = WorkoutType.gym,
    // Coach preferences from the pre-generate popup. Nulls mean "let
    // the AI pick from the user's experience level".
    int? preferredSets,
    int? preferredRepsLow,
    int? preferredRepsHigh,
  }) async {
    final library = await exercises.all();
    final libraryNames = library.map((e) => e.name).toList();

    // The rest-days list is authoritative for scheduling: training days
    // = 7 − rest-days count. If the user cleared their rest days we
    // train all 7. `trainingDaysPerWeek` in the profile stays around
    // for calorie math but no longer competes with the schedule.
    final derivedTrainingDays = (7 - restDays.length).clamp(1, 7);

    final plan = await ai.generateStarterRoutine(
      goal: goal,
      trainingDaysPerWeek: derivedTrainingDays,
      libraryExerciseNames: libraryNames,
      restWeekdays: restDays,
      workoutType: workoutType,
      preferredSets: preferredSets,
      preferredRepsLow: preferredRepsLow,
      preferredRepsHigh: preferredRepsHigh,
    );

    final routine = Routine()
      ..name = plan.name
      ..description = _goalDescription(goal, trainingDaysPerWeek);

    final libByName = {
      for (final e in library) e.name.toLowerCase().trim(): e,
    };

    // Rest-day enforcement — the user's rest-days list is absolute:
    //   • Weekday in restDays → rest day (no exercises, no matter what AI said)
    //   • Weekday NOT in restDays → training day (keep AI's exercises if
    //     it happened to mark this day training; otherwise it stays empty
    //     until we regenerate — better than silently dropping the day)
    // Empty restDays list therefore means every weekday is training.
    final userRestSet = restDays.toSet();

    for (final d in plan.days) {
      final forcedRest = userRestSet.contains(d.weekday);
      final day = RoutineDay()
        ..name = d.name
        ..weekday = d.weekday
        ..isRest = forcedRest;
      if (!forcedRest) {
        // Dedupe within a single day — AI sometimes lists the same exercise
        // twice ("Lat Pulldown" then "Lat Pulldown" again) which reads as
        // a bug in the UI. First occurrence wins.
        final seenInDay = <int>{};
        for (final ex in d.exercises) {
          final lookup = ex.name.toLowerCase().trim();
          Exercise match = libByName[lookup] ??
              (await _resolveOrCreate(ex.name, libByName));
          if (!seenInDay.add(match.id)) continue;
          // User's explicit prefs win over whatever the AI returned.
          final sets = preferredSets ?? ex.sets;
          final repsLow = preferredRepsLow ?? ex.repsLow;
          final repsHigh = preferredRepsHigh ?? ex.repsHigh;
          final item = RoutinePlanItem()
            ..exerciseId = match.id
            ..exerciseName = match.name
            ..targetSets = sets.clamp(1, 10)
            ..targetRepsLow = repsLow.clamp(1, 50)
            ..targetRepsHigh = repsHigh.clamp(repsLow, 60)
            ..restSeconds = match.defaultRestSeconds
            ..notes = ex.notes;
          day.items.add(item);
        }
      }
      routine.days.add(day);
    }

    // Ensure every weekday 1-7 is present in the routine — the AI
    // sometimes drops days entirely, which would leave gaps in the UI
    // like "Sunday: nothing at all". Missing weekdays default to rest.
    final presentWeekdays = routine.days.map((d) => d.weekday).toSet();
    for (int wd = 1; wd <= 7; wd++) {
      if (presentWeekdays.contains(wd)) continue;
      routine.days.add(RoutineDay()
        ..name = 'Rest'
        ..weekday = wd
        ..isRest = true);
    }
    // Sort so days flow Mon→Sun for the UI.
    routine.days.sort((a, b) => a.weekday.compareTo(b.weekday));

    final saved = await workouts.saveRoutine(routine);
    await workouts.activateRoutine(saved.id);
    return saved;
  }

  Future<Exercise> _resolveOrCreate(
      String name, Map<String, Exercise> libByName) async {
    final lookup = name.toLowerCase().trim();
    final existing = libByName[lookup];
    if (existing != null) return existing;
    final created = Exercise()
      ..name = _titleCase(name)
      ..isSeeded = false
      ..equipment = Equipment.other;
    await exercises.save(created);
    libByName[lookup] = created;
    return created;
  }

  String _goalDescription(FitnessGoal goal, int days) {
    final label = switch (goal) {
      FitnessGoal.buildMuscle => 'Build muscle',
      FitnessGoal.loseFat => 'Lose fat',
      FitnessGoal.recomp => 'Recomp',
      FitnessGoal.generalFitness => 'General fitness',
    };
    return '$label · $days days/week';
  }

  String _titleCase(String s) {
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}
