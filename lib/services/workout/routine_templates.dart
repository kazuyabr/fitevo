import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../data/models/routine.dart';
import '../../data/repositories/exercise_repo.dart';
import '../../data/repositories/workout_repo.dart';

/// One exercise line in a template.
class TemplateExercise {
  final String name;
  final int sets;
  final int repsLow;
  final int repsHigh;
  const TemplateExercise(this.name, this.sets, this.repsLow, this.repsHigh);
}

class TemplateDay {
  final String name;
  final int weekday; // 1=Mon..7=Sun
  final List<TemplateExercise> exercises;
  const TemplateDay(this.name, this.weekday, this.exercises);
}

class RoutineTemplate {
  final String id;
  final String name;
  final String subtitle;
  final int daysPerWeek;
  final List<TemplateDay> days; // training days only; rest fills the gaps
  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.daysPerWeek,
    required this.days,
  });
}

/// Proven, ready-made splits users can pick instead of AI generation.
class RoutineTemplates {
  static const List<RoutineTemplate> all = [
    RoutineTemplate(
      id: 'ppl',
      name: 'Push / Pull / Legs',
      subtitle: '6 days · hypertrophy classic',
      daysPerWeek: 6,
      days: [
        TemplateDay('Push', 1, [
          TemplateExercise('Barbell Bench Press', 4, 6, 10),
          TemplateExercise('Overhead Press', 3, 8, 12),
          TemplateExercise('Incline Dumbbell Press', 3, 8, 12),
          TemplateExercise('Lateral Raise', 3, 12, 15),
          TemplateExercise('Triceps Pushdown', 3, 10, 15),
        ]),
        TemplateDay('Pull', 2, [
          TemplateExercise('Deadlift', 3, 5, 6),
          TemplateExercise('Pull-up', 3, 6, 10),
          TemplateExercise('Barbell Row', 3, 8, 12),
          TemplateExercise('Face Pull', 3, 12, 15),
          TemplateExercise('Barbell Curl', 3, 10, 15),
        ]),
        TemplateDay('Legs', 3, [
          TemplateExercise('Barbell Squat', 4, 6, 10),
          TemplateExercise('Romanian Deadlift', 3, 8, 12),
          TemplateExercise('Leg Press', 3, 10, 15),
          TemplateExercise('Leg Curl', 3, 10, 15),
          TemplateExercise('Calf Raise', 4, 12, 20),
        ]),
        TemplateDay('Push', 4, [
          TemplateExercise('Overhead Press', 4, 6, 10),
          TemplateExercise('Incline Dumbbell Press', 3, 8, 12),
          TemplateExercise('Cable Fly', 3, 12, 15),
          TemplateExercise('Lateral Raise', 3, 12, 15),
          TemplateExercise('Triceps Pushdown', 3, 10, 15),
        ]),
        TemplateDay('Pull', 5, [
          TemplateExercise('Barbell Row', 4, 6, 10),
          TemplateExercise('Lat Pulldown', 3, 8, 12),
          TemplateExercise('Seated Cable Row', 3, 10, 15),
          TemplateExercise('Face Pull', 3, 12, 15),
          TemplateExercise('Dumbbell Curl', 3, 10, 15),
        ]),
        TemplateDay('Legs', 6, [
          TemplateExercise('Barbell Squat', 4, 8, 12),
          TemplateExercise('Leg Press', 3, 10, 15),
          TemplateExercise('Leg Curl', 3, 10, 15),
          TemplateExercise('Leg Extension', 3, 12, 15),
          TemplateExercise('Calf Raise', 4, 12, 20),
        ]),
      ],
    ),
    RoutineTemplate(
      id: 'ul',
      name: 'Upper / Lower',
      subtitle: '4 days · balanced strength',
      daysPerWeek: 4,
      days: [
        TemplateDay('Upper', 1, [
          TemplateExercise('Barbell Bench Press', 4, 6, 8),
          TemplateExercise('Barbell Row', 4, 6, 8),
          TemplateExercise('Overhead Press', 3, 8, 12),
          TemplateExercise('Lat Pulldown', 3, 10, 12),
          TemplateExercise('Barbell Curl', 3, 10, 15),
          TemplateExercise('Triceps Pushdown', 3, 10, 15),
        ]),
        TemplateDay('Lower', 2, [
          TemplateExercise('Barbell Squat', 4, 6, 8),
          TemplateExercise('Romanian Deadlift', 3, 8, 10),
          TemplateExercise('Leg Press', 3, 10, 15),
          TemplateExercise('Leg Curl', 3, 10, 15),
          TemplateExercise('Calf Raise', 4, 12, 20),
        ]),
        TemplateDay('Upper', 4, [
          TemplateExercise('Overhead Press', 4, 6, 8),
          TemplateExercise('Pull-up', 4, 6, 10),
          TemplateExercise('Incline Dumbbell Press', 3, 8, 12),
          TemplateExercise('Seated Cable Row', 3, 10, 12),
          TemplateExercise('Lateral Raise', 3, 12, 15),
          TemplateExercise('Dumbbell Curl', 3, 10, 15),
        ]),
        TemplateDay('Lower', 5, [
          TemplateExercise('Deadlift', 3, 4, 6),
          TemplateExercise('Barbell Squat', 3, 8, 12),
          TemplateExercise('Leg Extension', 3, 12, 15),
          TemplateExercise('Leg Curl', 3, 10, 15),
          TemplateExercise('Calf Raise', 4, 12, 20),
        ]),
      ],
    ),
    RoutineTemplate(
      id: 'stronglifts',
      name: '5×5 Strength',
      subtitle: '3 days · barbell basics',
      daysPerWeek: 3,
      days: [
        TemplateDay('Workout A', 1, [
          TemplateExercise('Barbell Squat', 5, 5, 5),
          TemplateExercise('Barbell Bench Press', 5, 5, 5),
          TemplateExercise('Barbell Row', 5, 5, 5),
        ]),
        TemplateDay('Workout B', 3, [
          TemplateExercise('Barbell Squat', 5, 5, 5),
          TemplateExercise('Overhead Press', 5, 5, 5),
          TemplateExercise('Deadlift', 1, 5, 5),
        ]),
        TemplateDay('Workout A', 5, [
          TemplateExercise('Barbell Squat', 5, 5, 5),
          TemplateExercise('Barbell Bench Press', 5, 5, 5),
          TemplateExercise('Barbell Row', 5, 5, 5),
        ]),
      ],
    ),
    RoutineTemplate(
      id: 'fullbody',
      name: 'Full Body',
      subtitle: '3 days · time-efficient',
      daysPerWeek: 3,
      days: [
        TemplateDay('Full Body A', 1, [
          TemplateExercise('Barbell Squat', 3, 6, 10),
          TemplateExercise('Barbell Bench Press', 3, 6, 10),
          TemplateExercise('Barbell Row', 3, 8, 12),
          TemplateExercise('Overhead Press', 3, 8, 12),
          TemplateExercise('Barbell Curl', 2, 10, 15),
        ]),
        TemplateDay('Full Body B', 3, [
          TemplateExercise('Deadlift', 3, 5, 6),
          TemplateExercise('Overhead Press', 3, 6, 10),
          TemplateExercise('Lat Pulldown', 3, 8, 12),
          TemplateExercise('Leg Press', 3, 10, 15),
          TemplateExercise('Triceps Pushdown', 2, 10, 15),
        ]),
        TemplateDay('Full Body C', 5, [
          TemplateExercise('Barbell Squat', 3, 8, 12),
          TemplateExercise('Incline Dumbbell Press', 3, 8, 12),
          TemplateExercise('Pull-up', 3, 6, 10),
          TemplateExercise('Leg Curl', 3, 10, 15),
          TemplateExercise('Lateral Raise', 2, 12, 15),
        ]),
      ],
    ),
  ];

  /// Builds a [Routine] from a template, resolving exercises against the
  /// library (creating any that don't exist), persists it, and activates.
  static Future<Routine> applyTemplate(
    RoutineTemplate template, {
    required ExerciseRepo exercises,
    required WorkoutRepo workouts,
  }) async {
    final library = await exercises.all();
    final byName = {for (final e in library) e.name.toLowerCase().trim(): e};

    Future<Exercise> resolve(String name) async {
      final key = name.toLowerCase().trim();
      final hit = byName[key];
      if (hit != null) return hit;
      final created = Exercise()
        ..name = name
        ..isSeeded = false
        ..equipment = Equipment.other;
      await exercises.save(created);
      byName[key] = created;
      return created;
    }

    final routine = Routine()
      ..name = template.name
      ..description = template.subtitle;

    final trainingByWeekday = {for (final d in template.days) d.weekday: d};
    for (var wd = 1; wd <= 7; wd++) {
      final td = trainingByWeekday[wd];
      final day = RoutineDay()
        ..name = td?.name ?? 'Rest'
        ..weekday = wd
        ..isRest = td == null;
      if (td != null) {
        for (final ex in td.exercises) {
          final match = await resolve(ex.name);
          day.items.add(RoutinePlanItem()
            ..exerciseId = match.id
            ..exerciseName = match.name
            ..targetSets = ex.sets
            ..targetRepsLow = ex.repsLow
            ..targetRepsHigh = ex.repsHigh
            ..restSeconds = match.defaultRestSeconds);
        }
      }
      routine.days.add(day);
    }

    final saved = await workouts.saveRoutine(routine);
    await workouts.activateRoutine(saved.id);
    return saved;
  }
}
