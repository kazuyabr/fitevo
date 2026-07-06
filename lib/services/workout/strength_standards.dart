import '../../data/models/enums.dart';

/// Broad strength tiers, mapped from an estimated 1RM relative to
/// bodyweight. Ratios are approximate, blended from common strength-level
/// charts (ExRx / StrengthLevel) — enough to tell a user "you're roughly
/// intermediate on bench", not to certify a powerlifting total.
enum StrengthLevel { untrained, novice, intermediate, advanced, elite }

class StrengthStandards {
  /// Bodyweight multipliers per lift for MEN, at the *floor* of each level
  /// (novice, intermediate, advanced, elite). Untrained is anything below
  /// novice. Keyed by a normalized lift bucket.
  static const Map<String, List<double>> _male = {
    'bench': [0.75, 1.0, 1.5, 2.0],
    'squat': [1.0, 1.5, 2.0, 2.5],
    'deadlift': [1.25, 1.75, 2.25, 2.75],
    'ohp': [0.55, 0.75, 1.0, 1.25],
    'row': [0.7, 1.0, 1.4, 1.8],
  };

  /// Women's ratios run roughly 0.55–0.7× the male numbers.
  static const Map<String, List<double>> _female = {
    'bench': [0.4, 0.6, 0.9, 1.2],
    'squat': [0.7, 1.1, 1.5, 1.9],
    'deadlift': [0.9, 1.3, 1.7, 2.1],
    'ohp': [0.35, 0.5, 0.7, 0.9],
    'row': [0.4, 0.6, 0.9, 1.2],
  };

  /// Maps an exercise name to a standards bucket, or null if it isn't one
  /// of the benchmarked compound lifts.
  static String? bucketFor(String exerciseName) {
    final n = exerciseName.toLowerCase();
    if (n.contains('deadlift')) return 'deadlift';
    if (n.contains('squat')) return 'squat';
    if (n.contains('bench')) return 'bench';
    if ((n.contains('overhead') || n.contains('shoulder')) &&
        n.contains('press')) {
      return 'ohp';
    }
    if (n.contains('ohp') || n.contains('military press')) return 'ohp';
    if (n.contains('row')) return 'row';
    return null;
  }

  /// Classifies an [estimated1RM] for [exerciseName] against [bodyweightKg].
  /// Returns null when the lift isn't benchmarked or inputs are missing.
  static StrengthAssessment? assess({
    required String exerciseName,
    required double estimated1RM,
    required double bodyweightKg,
    required Gender gender,
  }) {
    if (estimated1RM <= 0 || bodyweightKg <= 0) return null;
    final bucket = bucketFor(exerciseName);
    if (bucket == null) return null;
    final table = gender == Gender.female ? _female : _male;
    final ratios = table[bucket]!;
    final ratio = estimated1RM / bodyweightKg;

    StrengthLevel level;
    if (ratio < ratios[0]) {
      level = StrengthLevel.untrained;
    } else if (ratio < ratios[1]) {
      level = StrengthLevel.novice;
    } else if (ratio < ratios[2]) {
      level = StrengthLevel.intermediate;
    } else if (ratio < ratios[3]) {
      level = StrengthLevel.advanced;
    } else {
      level = StrengthLevel.elite;
    }

    // Weight needed to reach the next tier (null at elite).
    double? nextTierKg;
    final idx = level.index; // 0..4
    if (idx < ratios.length) {
      nextTierKg = ratios[idx] * bodyweightKg;
    }

    return StrengthAssessment(
      level: level,
      bodyweightRatio: ratio,
      nextTier1RMKg: nextTierKg,
    );
  }

  static String label(StrengthLevel l) => switch (l) {
        StrengthLevel.untrained => 'Untrained',
        StrengthLevel.novice => 'Novice',
        StrengthLevel.intermediate => 'Intermediate',
        StrengthLevel.advanced => 'Advanced',
        StrengthLevel.elite => 'Elite',
      };
}

class StrengthAssessment {
  final StrengthLevel level;
  final double bodyweightRatio;

  /// Estimated 1RM (kg) needed to reach the next tier; null at elite.
  final double? nextTier1RMKg;

  const StrengthAssessment({
    required this.level,
    required this.bodyweightRatio,
    required this.nextTier1RMKg,
  });
}
