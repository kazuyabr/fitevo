import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import 'strength_standards.dart';

/// First-session weight suggestions.
///
/// Once a user has logged an exercise, their own history (via
/// [OverloadAdvisor] / [ProgressionCoach]) drives every future number. This
/// only fills the *very first* time an exercise is trained, from the user's
/// bodyweight, sex and how long they've been in the gym ([Profile.gymStartDate]).
///
/// It is deliberately conservative — a light, controllable starting load the
/// user ramps up from, never a max. Better to start 5 kg too light than to
/// hand a beginner a weight they can't handle.
class StartingWeight {
  /// Coarse training experience from how long ago the user started training.
  /// null start date (never lifted) → untrained.
  static StrengthLevel experienceFrom(DateTime? gymStartDate) {
    if (gymStartDate == null) return StrengthLevel.untrained;
    final months = DateTime.now().difference(gymStartDate).inDays / 30.44;
    if (months < 3) return StrengthLevel.novice;
    if (months < 18) return StrengthLevel.intermediate;
    return StrengthLevel.advanced;
  }

  /// Suggested first working weight in kg, or null when there's no external
  /// load to suggest (bodyweight / band moves) or bodyweight is unknown.
  /// The number aims at the middle of a hypertrophy range (~8–12 reps),
  /// not a 1RM.
  static double? suggestKg({
    required Exercise exercise,
    required double bodyweightKg,
    required Gender gender,
    required DateTime? gymStartDate,
  }) {
    if (bodyweightKg <= 0) return null;
    if (exercise.equipment == Equipment.bodyweight ||
        exercise.equipment == Equipment.band) {
      return null; // progress these by reps, not load
    }

    // Base working weight as a fraction of bodyweight for a MALE NOVICE on a
    // barbell, keyed off the movement's primary muscle.
    final primary = exercise.muscleGroups.isNotEmpty
        ? exercise.muscleGroups.first
        : MuscleGroup.fullBody;

    // Dumbbell weights are entered per hand; cables / kettlebells / smith run
    // lighter than a loaded straight bar for the same movement.
    final equip = switch (exercise.equipment) {
      Equipment.barbell => 1.0,
      Equipment.machine => 1.0,
      Equipment.smith => 0.9,
      Equipment.cable => 0.6,
      Equipment.dumbbell => 0.42, // per hand
      Equipment.kettlebell => 0.4,
      _ => 0.7,
    };

    final exp = switch (experienceFrom(gymStartDate)) {
      StrengthLevel.untrained => 0.8,
      StrengthLevel.novice => 1.0,
      StrengthLevel.intermediate => 1.5,
      StrengthLevel.advanced => 2.0,
      StrengthLevel.elite => 2.4,
    };

    final sex = switch (gender) {
      Gender.female => 0.6,
      Gender.other => 0.8,
      Gender.male => 1.0,
    };

    // Bias ~10% light so the opening set is never a grind.
    var kg = bodyweightKg * _baseFraction(primary) * equip * exp * sex * 0.9;
    kg = (kg / 2.5).round() * 2.5; // round to the smallest common plate jump

    final minKg = exercise.equipment == Equipment.dumbbell ? 2.5 : 5.0;
    if (kg < minKg) kg = minKg;
    final cap = (bodyweightKg * 3 / 2.5).round() * 2.5;
    if (kg > cap) kg = cap;
    return kg;
  }

  /// Working-weight fraction of bodyweight for a male-novice barbell lift.
  static double _baseFraction(MuscleGroup m) => switch (m) {
        MuscleGroup.glutes => 0.85,
        MuscleGroup.quads => 0.75,
        MuscleGroup.hamstrings => 0.70,
        MuscleGroup.calves => 0.60,
        MuscleGroup.chest => 0.55,
        MuscleGroup.back => 0.50,
        MuscleGroup.fullBody => 0.40,
        MuscleGroup.shoulders => 0.35,
        MuscleGroup.triceps => 0.22,
        MuscleGroup.biceps => 0.18,
        MuscleGroup.core => 0.15,
        MuscleGroup.forearms => 0.12,
        MuscleGroup.cardio => 0.30,
      };
}
