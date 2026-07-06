import 'package:isar/isar.dart';

import 'enums.dart';

part 'cardio_session.g.dart';

/// A logged cardio / conditioning bout. Unlike a [WorkoutSession] there
/// are no sets/reps/weight — cardio is measured by time, optional
/// distance, and energy burned, which feeds into the day's calorie math.
@collection
class CardioSession {
  Id id = Isar.autoIncrement;

  @Index()
  late String dateKey;

  @Enumerated(EnumType.name)
  CardioType type = CardioType.run;

  DateTime startedAt = DateTime.now();

  /// Duration of the bout in seconds.
  int durationSeconds = 0;

  /// Distance in kilometres — only meaningful for distance modalities
  /// (run/walk/cycle/row/swim). Null for duration-only work like HIIT.
  double? distanceKm;

  /// Energy burned. Either user-entered or estimated from MET × weight ×
  /// time when the user leaves it blank.
  int calories = 0;

  /// Optional average heart rate (bpm) for users who track it.
  int? avgHeartRate;

  String? note;

  @ignore
  Duration get duration => Duration(seconds: durationSeconds);

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
