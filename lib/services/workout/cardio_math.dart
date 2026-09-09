import 'package:flutter/material.dart';

import '../../data/models/enums.dart';

/// MET values + calorie estimation for cardio modalities. 1 MET burns
/// roughly 1 kcal per kg of bodyweight per hour, so
/// kcal ≈ MET × bodyweightKg × (minutes / 60).
class CardioMath {
  static const Map<CardioType, double> _met = {
    CardioType.run: 9.8,
    CardioType.walk: 3.5,
    CardioType.cycle: 7.5,
    CardioType.row: 7.0,
    CardioType.swim: 7.0,
    CardioType.elliptical: 5.0,
    CardioType.stairs: 8.0,
    CardioType.hiit: 8.0,
    CardioType.jumpRope: 11.0,
    CardioType.other: 6.0,
  };

  /// Estimated calories for a time-based bout (swim/cycle/row/HIIT/…).
  /// Falls back to a 75 kg default when bodyweight is unknown.
  static int estimateCalories({
    required CardioType type,
    required int minutes,
    required double bodyweightKg,
  }) {
    final kg = bodyweightKg > 0 ? bodyweightKg : 75;
    final met = _met[type] ?? 6.0;
    return (met * kg * (minutes / 60.0)).round();
  }

  /// Distance-based calories for running/walking — pace-independent and
  /// far more accurate than time for these. Matches the home model:
  /// running ≈ 1.0 kcal/kg/km, walking ≈ 0.71 kcal/kg/km.
  static int distanceCalories({
    required bool isRun,
    required double km,
    required double bodyweightKg,
  }) {
    final kg = bodyweightKg > 0 ? bodyweightKg : 75;
    final perKm = (isRun ? 70.0 : 50.0) * (kg / 70.0);
    return (perKm * km).round();
  }

  /// The "Other" (time-based) modalities — run/walk are handled by
  /// distance and get their own dedicated fields.
  static const List<CardioType> otherTypes = [
    CardioType.cycle,
    CardioType.row,
    CardioType.swim,
    CardioType.elliptical,
    CardioType.stairs,
    CardioType.jumpRope,
    CardioType.other,
  ];

  /// Whether this modality is measured by distance (shows a km field).
  static bool hasDistance(CardioType t) =>
      t == CardioType.run ||
      t == CardioType.walk ||
      t == CardioType.cycle ||
      t == CardioType.row ||
      t == CardioType.swim;

  static String label(CardioType t) => switch (t) {
        CardioType.run => 'Run',
        CardioType.walk => 'Walk',
        CardioType.cycle => 'Cycle',
        CardioType.row => 'Row',
        CardioType.swim => 'Swim',
        CardioType.elliptical => 'Elliptical',
        CardioType.stairs => 'Stairs',
        CardioType.hiit => 'HIIT',
        CardioType.jumpRope => 'Jump rope',
        CardioType.other => 'Other',
      };

  static IconData icon(CardioType t) => switch (t) {
        CardioType.run => Icons.directions_run_rounded,
        CardioType.walk => Icons.directions_walk_rounded,
        CardioType.cycle => Icons.directions_bike_rounded,
        CardioType.row => Icons.rowing_rounded,
        CardioType.swim => Icons.pool_rounded,
        CardioType.elliptical => Icons.fitness_center_rounded,
        CardioType.stairs => Icons.stairs_rounded,
        CardioType.hiit => Icons.bolt_rounded,
        CardioType.jumpRope => Icons.sports_gymnastics_rounded,
        CardioType.other => Icons.favorite_rounded,
      };
}
