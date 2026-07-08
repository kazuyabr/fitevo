import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/body_measurement.dart';
import 'models/cardio_session.dart';
import 'models/custom_food.dart';
import 'models/daily_log.dart';
import 'models/exercise.dart';
import 'models/food_combo.dart';
import 'models/food_entry.dart';
import 'models/period_log.dart';
import 'models/profile.dart';
import 'models/routine.dart';
import 'models/soreness_log.dart';
import 'models/workout_session.dart';

class Db {
  Db._(this.isar);
  final Isar isar;

  static Db? _instance;
  static Db get instance {
    final db = _instance;
    if (db == null) {
      throw StateError('Db.init() must be called before accessing Db.instance');
    }
    return db;
  }

  /// Wipes every collection. Used by the account-deletion flow so a
  /// user who hits "Delete account" leaves no local trace behind.
  /// Does not close or reset the Isar instance — the app keeps running.
  Future<void> wipeAll() async {
    await isar.writeTxn(() async {
      await isar.profiles.clear();
      await isar.dailyLogs.clear();
      await isar.foodEntrys.clear();
      await isar.customFoods.clear();
      await isar.foodCombos.clear();
      await isar.exercises.clear();
      await isar.routines.clear();
      await isar.workoutSessions.clear();
      await isar.cardioSessions.clear();
      await isar.sorenessLogs.clear();
      await isar.bodyMeasurements.clear();
      await isar.periodLogs.clear();
    });
  }

  static Future<Db> init() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        ProfileSchema,
        DailyLogSchema,
        FoodEntrySchema,
        CustomFoodSchema,
        FoodComboSchema,
        ExerciseSchema,
        RoutineSchema,
        WorkoutSessionSchema,
        CardioSessionSchema,
        SorenessLogSchema,
        BodyMeasurementSchema,
        PeriodLogSchema,
      ],
      directory: dir.path,
      name: 'fitevo',
    );
    await _selfHealSchema(isar);
    _instance = Db._(isar);
    return _instance!;
  }

  /// One-time recovery for the embedded-schema change on [SetEntry] (added
  /// setType / feeling / supersetGroup). Isar stores embedded objects
  /// inline and can't always migrate their byte layout, so reading old
  /// workout sessions throws a RangeError. We probe each collection whose
  /// embedded shape changed; if it can't be read, we drop just that
  /// collection so the app recovers instead of hard-failing on every read.
  ///
  /// Only `workoutSessions` embeds a changed object, so only it is at risk.
  /// Cardio / soreness are brand-new (no legacy rows). Runs once — after a
  /// clear the probe read succeeds and nothing else is touched.
  static Future<void> _selfHealSchema(Isar isar) async {
    try {
      // Deserializes real rows; throws if the inline layout is stale.
      await isar.workoutSessions.where().findFirst();
    } catch (_) {
      try {
        await isar.writeTxn(() async {
          await isar.workoutSessions.clear();
        });
      } catch (_) {
        // If even clear() fails the file is beyond in-place repair; leave
        // it so the error still surfaces rather than masking a deeper issue.
      }
    }
  }
}
