import 'package:isar/isar.dart';

import '../../core/health_math.dart';
import '../db.dart';
import '../models/profile.dart';

class ProfileRepo {
  ProfileRepo(this._db);
  final Db _db;

  Isar get _isar => _db.isar;

  Future<Profile?> getCurrent() async {
    return _isar.profiles.where().findFirst();
  }

  Stream<Profile?> watch() {
    return _isar.profiles
        .where()
        .watch(fireImmediately: true)
        .map((all) => all.isEmpty ? null : all.first);
  }

  Future<void> save(Profile profile) async {
    profile.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.profiles.put(profile);
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.profiles.clear();
    });
  }

  /// One-time backfill for profiles created before `restDayCalorieTarget`
  /// existed. Recomputes the precise rest-day value from the profile's
  /// current data via [HealthMath.compute] and persists it, so runtime
  /// never has to fall back to the ~15% heuristic on those profiles.
  /// Safe to call on every app start — it's a no-op when the value is
  /// already populated.
  Future<void> backfillRestDayCalorieTarget() async {
    final p = await getCurrent();
    if (p == null) return;
    if (p.restDayCalorieTarget > 0) return;
    if (p.calorieTarget <= 0) return; // No baseline to derive from yet.
    final t = HealthMath.compute(
      gender: p.gender,
      age: p.age,
      weightKg: p.weightKg,
      heightCm: p.heightCm,
      activity: p.activityLevel,
      goal: p.goal,
      cardioSessionsPerWeek: p.cardioSessionsPerWeek,
      walkingKmPerDay: p.walkingKmPerDay,
      runningKmPerWeek: p.runningKmPerWeek,
      gymMinutesPerSession: p.goesGym ? p.gymMinutesPerSession : 0,
      strengthDaysPerWeek: p.goesGym ? p.trainingDaysPerWeek : 0,
      bodyFocusNotes: p.bodyFocusNotes,
      creatineGramsPerDay: p.creatineGramsPerDay,
      proteinScoopsPerDay: p.proteinScoopsPerDay,
      gymStartDate: p.gymStartDate,
      bodyFatPct: p.bodyFatPct,
      healthFlags: p.healthFlags,
      restDays: p.restDays,
      cyclePhase: p.cyclePhase,
    );
    p.restDayCalorieTarget = t.restDayCalorieTarget;
    await save(p);
  }
}
