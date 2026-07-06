import 'package:isar/isar.dart';

import 'enums.dart';

part 'soreness_log.g.dart';

/// A per-day recovery check-in: how sore each trained muscle feels. Used
/// to decide whether today's scheduled day is a good idea or whether the
/// user should swap in something that hits fresher muscles.
@collection
class SorenessLog {
  Id id = Isar.autoIncrement;

  /// One check-in per calendar day; latest write for a day wins.
  @Index(unique: true, replace: true)
  late String dateKey;

  List<MuscleSoreness> entries = [];

  DateTime createdAt = DateTime.now();

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Soreness for a single muscle group. [level] is 0 (fresh) → 4 (very
/// sore / can barely move it).
@embedded
class MuscleSoreness {
  @Enumerated(EnumType.name)
  MuscleGroup muscle = MuscleGroup.fullBody;

  int level = 0;
}
