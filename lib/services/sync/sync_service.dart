import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';

import '../settings/target_snapshot_store.dart';

import '../../data/db.dart';
import '../../data/models/body_measurement.dart';
import '../../data/models/custom_food.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/period_log.dart';
import '../../data/models/profile.dart';
import '../../data/models/routine.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/nutrition_repo.dart';
import '../../l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firestore layout (v4 — complete, industry-standard)
//
// users/{uid}
// ├── _v: 4 · email · displayName · uid · lastBackupAt
// │
// ├── profile/main
// │   ├── personal   {displayName, age, gender, country, dietPreference, cyclePhase}
// │   ├── body       {heightCm, weightKg, bmi, bmr, tdee, bodyFatPct, bodyFocusNotes}
// │   ├── goal       {fitnessGoal, activityLevel, trainingDaysPerWeek,
// │   │               cardioSessionsPerWeek, goesGym, gymStartDate}
// │   ├── activityBaseline {walkingKmPerDay, runningKmPerWeek, gymMinutesPerSession}
// │   ├── targets    {calories, proteinG, carbsG, fatG, fiberG, waterMl}
// │   ├── overrides  {calories?, proteinG?, carbsG?, fatG?, fiberG?, waterMl?}
// │   ├── effectiveTargets {calories, proteinG, carbsG, fatG, fiberG, waterMl}
// │   ├── schedule   {restDays, wakeTimeMin, sleepTimeMin, weighInCadence, …}
// │   ├── supplements {creatineGramsPerDay, proteinScoopsPerDay, multivitamin, otherNote}
// │   ├── health     {flags:[…]}
// │   └── meta       {createdAt, updatedAt}  ← Firestore Timestamps
// │
// ├── stats/summary
// │   ├── currentStreak · longestStreak · totalDaysLogged
// │   ├── totalFoodEntries · totalWorkoutSessions
// │   └── avgDailyCaloriesLast30Days · updatedAt
// │
// ├── weeks/W-YYYY-MM-DD  (Monday of that week)
// │   ├── weekKey · startDate · endDate · daysLogged
// │   ├── nutrition  {totalCalories, avgCalories, totalProteinG, avgProteinG,
// │   │               totalCarbsG, totalFatG, totalFiberG}
// │   └── training   {sessions, totalSets, totalVolumeKg, totalMinutes}
// │
// ├── months/M-YYYY-MM
// │   ├── monthKey · year · month · daysLogged
// │   ├── nutrition  {totalCalories, avgCalories, totalProteinG, avgProteinG,
// │   │               totalCarbsG, totalFatG}
// │   └── training   {sessions, totalVolumeKg}
// │
// ├── days/{dateKey}
// │   ├── dateKey · _v
// │   ├── consumed   {calories, proteinG, carbsG, fatG, fiberG, sodiumMg,
// │   │               waterMl, mealCount, itemCount}
// │   ├── target     {caloriesBase, caloriesAdjusted, activityBonusKcal,
// │   │               proteinG, carbsG, fatG, fiberG, waterMl}
// │   ├── activity   {walkingKm, runningKm, otherCardioMin, steps,
// │   │               heartRateAvg, note}
// │   ├── sleep      {minutes, hours}
// │   ├── water      {totalMl, entries:[{time, minutesOfDay, ml}]}
// │   ├── updatedAt  (Timestamp)
// │   │
// │   ├── meals/{n}   (one meal = one user input submission)
// │   │   ├── mealNumber · label · time · rawInput · itemCount
// │   │   ├── total  {calories, proteinG, carbsG, fatG, fiberG, sodiumMg}
// │   │   └── items  [{description, quantity, calories, proteinG, carbsG,
// │   │                fatG, fiberG, sodiumMg}]
// │   │
// │   └── foods/{isarId}
// │       ├── id · _v
// │       ├── meal       {number, label, time}
// │       ├── food       {description, rawInput, quantity, unit, photoPath?}
// │       ├── nutrition  {calories, proteinG, carbsG, fatG, fiberG, sodiumMg,
// │       │               caloriesLow, caloriesHigh}
// │       └── meta       {source, confidence, isFavorite, timestamp, dateKey}
// │
// ├── workoutSessions/{id}
// │   ├── id · _v · dateKey · routineName · routineDayName
// │   ├── startedAt · completedAt  (Timestamps)
// │   ├── duration   {minutes}
// │   ├── stats      {totalSets, totalReps, totalVolumeKg, uniqueExercises}
// │   ├── perceivedDifficulty · note
// │   └── sets       [{exerciseId, exerciseName, setNumber, weightKg, reps,
// │                    rpe, isWarmup, completedAt}]
// │
// ├── exercises/{id}   (all exercises including seeded)
// │   ├── id · _v · name · equipment · isSeeded · isBeginnerFriendly
// │   ├── muscleGroups · formCues · commonMistakes · defaultRestSeconds
// │   └── createdAt  (Timestamp)
// │
// ├── routines/{id}
// │   ├── id · _v · name · description · isActive
// │   ├── days  [{name, weekday, isRest, items:[{exerciseId, exerciseName,
// │   │           targetSets, targetRepsLow, targetRepsHigh, restSeconds, notes}]}]
// │   └── createdAt · updatedAt  (Timestamps)
// │
// ├── measurements/{id}
// │   ├── id · _v · date (Timestamp) · dateKey · weightKg · bodyFatPct
// │   ├── measurements  {waistCm, chestCm, hipsCm, thighCm, armCm, neckCm}
// │   ├── note
// │   └── createdAt  (Timestamp)
// │   (photoPath intentionally excluded — local device path only)
// │
// ├── periodLogs/{dateKey}
// │   ├── dateKey · _v · date (Timestamp)
// │   ├── flow · symptoms:[…]
// │   ├── notes
// │   └── createdAt · updatedAt  (Timestamps)
// │
// └── customFoods/{id}
// ─────────────────────────────────────────────────────────────────────────────

class SyncService {
  SyncService({
    required Db db,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = db,
        _fs = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final Db _db;
  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;

  static const int _v = 4;

  Isar get _isar => _db.isar;
  String? get _uid => _auth.currentUser?.uid;

  // --- Collection references ------------------------------------------------

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');
    return _fs.collection('users').doc(uid);
  }

  // Days
  CollectionReference<Map<String, dynamic>> _daysCol() =>
      _userDoc().collection('days');
  DocumentReference<Map<String, dynamic>> _dayDoc(String dk) =>
      _daysCol().doc(dk);
  CollectionReference<Map<String, dynamic>> _dayFoods(String dk) =>
      _dayDoc(dk).collection('foods');
  CollectionReference<Map<String, dynamic>> _dayMeals(String dk) =>
      _dayDoc(dk).collection('meals');

  // Aggregates
  CollectionReference<Map<String, dynamic>> _weeksCol() =>
      _userDoc().collection('weeks');
  CollectionReference<Map<String, dynamic>> _monthsCol() =>
      _userDoc().collection('months');
  DocumentReference<Map<String, dynamic>> _statsDoc() =>
      _userDoc().collection('stats').doc('summary');

  // Training
  CollectionReference<Map<String, dynamic>> _workoutSessionsCol() =>
      _userDoc().collection('workoutSessions');
  CollectionReference<Map<String, dynamic>> _exercisesCol() =>
      _userDoc().collection('exercises');
  CollectionReference<Map<String, dynamic>> _routinesCol() =>
      _userDoc().collection('routines');

  // Health
  CollectionReference<Map<String, dynamic>> _measurementsCol() =>
      _userDoc().collection('measurements');
  CollectionReference<Map<String, dynamic>> _periodLogsCol() =>
      _userDoc().collection('periodLogs');

  // Other
  DocumentReference<Map<String, dynamic>> _profileDoc() =>
      _userDoc().collection('profile').doc('main');
  CollectionReference<Map<String, dynamic>> _customFoodsCol() =>
      _userDoc().collection('customFoods');

  // --- Public API -----------------------------------------------------------

  Future<bool> cloudHasData() async {
    final p = await _profileDoc().get();
    if (p.exists) return true;
    final d = await _daysCol().limit(1).get();
    if (d.docs.isNotEmpty) return true;
    final f = await _userDoc().collection('foodEntries').limit(1).get();
    return f.docs.isNotEmpty;
  }

  Future<bool> localHasData() async {
    if (await _isar.profiles.count() > 0) return true;
    return await _isar.foodEntrys.count() > 0;
  }

  /// Push every local record to Firestore.
  Future<void> pushAll() async {
    final user = _auth.currentUser;
    final profile = await _isar.profiles.where().findFirst();

    // Root user doc: identity + schema version.
    await _userDoc().set({
      '_v': _v,
      'email': user?.email,
      'displayName': user?.displayName ?? profile?.displayName,
      'uid': user?.uid,
      'lastBackupAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (profile != null) {
      await _profileDoc().set(_profileToMap(profile));
    }

    // ── Food / nutrition ────────────────────────────────────────────────────
    final allEntries = await _isar.foodEntrys.where().findAll();
    final byDate = <String, List<FoodEntry>>{};
    for (final e in allEntries) {
      (byDate[e.dateKey] ??= []).add(e);
    }

    final allLogs = await _isar.dailyLogs.where().findAll();
    final logsByDate = {for (final l in allLogs) l.dateKey: l};
    final allDates = {...byDate.keys, ...logsByDate.keys};

    // ── Training ────────────────────────────────────────────────────────────
    final allSessions = await _isar.workoutSessions.where().findAll();
    final allExercises = await _isar.exercises.where().findAll();
    final allRoutines = await _isar.routines.where().findAll();

    // ── Health ──────────────────────────────────────────────────────────────
    final allMeasurements = await _isar.bodyMeasurements.where().findAll();
    final allPeriodLogs = await _isar.periodLogs.where().findAll();

    // ── Custom foods ────────────────────────────────────────────────────────
    final allCustomFoods = await _isar.customFoods.where().findAll();

    // Collect all (ref, data) write pairs; flush in 400-op batches.
    final writes =
        <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];

    // ── Day documents + meal summaries + food entries ────────────────────
    for (final dateKey in allDates) {
      final entries = byDate[dateKey] ?? [];
      final log = logsByDate[dateKey];
      final totals =
          NutritionRepo.sumEntries(entries, waterMl: log?.waterMl ?? 0);
      final mealGroups = _groupIntoMeals(entries);

      writes.add((
        _dayDoc(dateKey),
        _dayToMap(dateKey, log, totals, profile, mealGroups.length),
      ));

      for (var i = 0; i < mealGroups.length; i++) {
        final group = mealGroups[i];
        final mealNum = i + 1;
        final label = _mealLabel(group.first.timestamp);
        final timeStr = _fmtTime(group.first.timestamp);
        int mc = 0, mp = 0, mcarb = 0, mf = 0, mfib = 0, msodium = 0;
        for (final e in group) {
          mc += e.calories;
          mp += e.proteinG;
          mcarb += e.carbsG;
          mf += e.fatG;
          mfib += e.fiberG;
          msodium += e.sodiumMg;
        }
        writes.add((_dayMeals(dateKey).doc(_mealDocId(mealNum, group.first.rawInput)), {
          'mealNumber': mealNum,
          'label': label,
          'time': timeStr,
          // The original text the user typed — one submission = one meal.
          'rawInput': group.first.rawInput,
          'total': {
            'calories': mc,
            'proteinG': mp,
            'carbsG': mcarb,
            'fatG': mf,
            'fiberG': mfib,
            'sodiumMg': msodium,
          },
          // Each item from this submission with its own nutrients.
          'items': group
              .map((e) => {
                    'description': e.description,
                    'quantity': e.quantity,
                    'calories': e.calories,
                    'proteinG': e.proteinG,
                    'carbsG': e.carbsG,
                    'fatG': e.fatG,
                    'fiberG': e.fiberG,
                    'sodiumMg': e.sodiumMg,
                  })
              .toList(),
          'itemCount': group.length,
        }));

        for (final e in group) {
          writes.add((_dayFoods(dateKey).doc('${e.id}'),
              _foodEntryToMap(e,
                  mealNumber: mealNum,
                  mealLabel: label,
                  mealTime: timeStr)));
        }
      }
    }

    // ── Training ────────────────────────────────────────────────────────────
    for (final s in allSessions) {
      writes.add((_workoutSessionsCol().doc('${s.id}'),
          _workoutSessionToMap(s)));
    }
    for (final e in allExercises) {
      writes.add((_exercisesCol().doc('${e.id}'), _exerciseToMap(e)));
    }
    for (final r in allRoutines) {
      writes.add((_routinesCol().doc('${r.id}'), _routineToMap(r)));
    }

    // ── Health ──────────────────────────────────────────────────────────────
    for (final m in allMeasurements) {
      writes.add((_measurementsCol().doc('${m.id}'), _measurementToMap(m)));
    }
    for (final l in allPeriodLogs) {
      writes.add((_periodLogsCol().doc(l.dateKey), _periodLogToMap(l)));
    }

    // ── Custom foods ────────────────────────────────────────────────────────
    for (final c in allCustomFoods) {
      writes.add((_customFoodsCol().doc('${c.id}'), _customFoodToMap(c)));
    }

    // ── Aggregates ──────────────────────────────────────────────────────────
    _buildAggregates(byDate, logsByDate, allDates, allSessions, writes);
    _buildStats(allEntries, allSessions, byDate, writes);

    // ── Flush in 400-op chunks ───────────────────────────────────────────
    for (var i = 0; i < writes.length; i += 400) {
      final end = math.min(i + 400, writes.length);
      final batch = _fs.batch();
      for (var j = i; j < end; j++) {
        batch.set(writes[j].$1, writes[j].$2);
      }
      await batch.commit();
    }

    // ── Mirror deletions ─────────────────────────────────────────────────
    // pushAll only *writes* the records that still exist locally. Without
    // this step a routine/food/session the user deleted stays in Firestore
    // forever and pullAll (fresh install / new device / restore) brings it
    // back — the classic "I deleted it but it keeps coming back" bug. So we
    // remove any remote doc whose id is no longer present locally.
    await _reconcileDeletes(
        _routinesCol(), {for (final r in allRoutines) '${r.id}'});
    await _reconcileDeletes(
        _exercisesCol(), {for (final e in allExercises) '${e.id}'});
    await _reconcileDeletes(
        _workoutSessionsCol(), {for (final s in allSessions) '${s.id}'});
    await _reconcileDeletes(
        _customFoodsCol(), {for (final c in allCustomFoods) '${c.id}'});
    await _reconcileDeletes(
        _measurementsCol(), {for (final m in allMeasurements) '${m.id}'});
    await _reconcileDeletes(
        _periodLogsCol(), {for (final l in allPeriodLogs) l.dateKey});
  }

  /// Delete remote docs in [col] whose id isn't in [localIds] — mirrors local
  /// deletions to the cloud so removed records don't resurrect on restore.
  Future<void> _reconcileDeletes(
    CollectionReference<Map<String, dynamic>> col,
    Set<String> localIds,
  ) async {
    final remote = await col.get();
    final stale =
        remote.docs.where((d) => !localIds.contains(d.id)).toList();
    for (var i = 0; i < stale.length; i += 400) {
      final end = math.min(i + 400, stale.length);
      final batch = _fs.batch();
      for (var j = i; j < end; j++) {
        batch.delete(stale[j].reference);
      }
      await batch.commit();
    }
  }

  /// Pull everything from Firestore into local Isar.
  Future<void> pullAll() async {
    final pf = await _profileDoc().get();

    // ── Food entries + daily logs ────────────────────────────────────────
    final allEntries = <int, FoodEntry>{};
    final allLogs = <DailyLog>[];

    final dayDocs = await _daysCol().get();
    if (dayDocs.docs.isNotEmpty) {
      for (final dayDoc in dayDocs.docs) {
        final data = dayDoc.data();
        allLogs.add(_dailyLogFromMap(data));

        // Freeze the Firebase target as a local snapshot so the app always
        // shows what Firebase recorded, regardless of profile changes.
        final t = (data['target'] as Map<String, dynamic>?) ?? {};
        final cal = (t['caloriesAdjusted'] as num?)?.toInt();
        if (cal != null && dayDoc.id.isNotEmpty) {
          await TargetSnapshotStore.save(
            dateKey: dayDoc.id,
            calorieTarget: cal,
            proteinTarget: (t['proteinG'] as num?)?.toInt() ?? 0,
            carbTarget: (t['carbsG'] as num?)?.toInt() ?? 0,
            fatTarget: (t['fatG'] as num?)?.toInt() ?? 0,
            fiberTarget: (t['fiberG'] as num?)?.toInt(),
            waterTarget: (t['waterMl'] as num?)?.toInt(),
            sodiumTarget: (t['sodiumMg'] as num?)?.toInt(),
          );
        }

        final items = await dayDoc.reference.collection('foods').get();
        for (final item in items.docs) {
          final e = _foodEntryFromMap(item.data());
          allEntries[e.id] = e;
        }
      }
    } else {
      // Legacy: foodEntries/{dateKey}/items/{id} or foodEntries/{id}
      final oldCol = _userDoc().collection('foodEntries');
      for (final doc in (await oldCol.get()).docs) {
        final data = doc.data();
        if (data.containsKey('calories')) {
          final e = _foodEntryFromMap(data);
          allEntries.putIfAbsent(e.id, () => e);
        } else {
          for (final item in (await doc.reference.collection('items').get()).docs) {
            final e = _foodEntryFromMap(item.data());
            allEntries.putIfAbsent(e.id, () => e);
          }
        }
      }
      for (final d in (await _userDoc().collection('dailyLogs').get()).docs) {
        allLogs.add(_dailyLogFromMap(d.data()));
      }
    }

    // ── Training ────────────────────────────────────────────────────────────
    final sessionDocs = await _workoutSessionsCol().get();
    final exerciseDocs = await _exercisesCol().get();
    final routineDocs = await _routinesCol().get();

    // ── Health ──────────────────────────────────────────────────────────────
    final measurementDocs = await _measurementsCol().get();
    final periodLogDocs = await _periodLogsCol().get();

    // ── Custom foods ────────────────────────────────────────────────────────
    final customFoodDocs = await _customFoodsCol().get();

    await _isar.writeTxn(() async {
      if (pf.exists) {
        await _isar.profiles.put(_profileFromMap(pf.data()!));
      }
      for (final e in allEntries.values) {
        await _isar.foodEntrys.put(e);
      }
      for (final l in allLogs) {
        if (l.dateKey.isEmpty) continue;
        await _isar.dailyLogs.put(l);
      }
      for (final d in sessionDocs.docs) {
        await _isar.workoutSessions.put(_workoutSessionFromMap(d.data()));
      }
      for (final d in exerciseDocs.docs) {
        await _isar.exercises.put(_exerciseFromMap(d.data()));
      }
      for (final d in routineDocs.docs) {
        await _isar.routines.put(_routineFromMap(d.data()));
      }
      for (final d in measurementDocs.docs) {
        await _isar.bodyMeasurements.put(_measurementFromMap(d.data()));
      }
      for (final d in periodLogDocs.docs) {
        await _isar.periodLogs.put(_periodLogFromMap(d.data()));
      }
      for (final d in customFoodDocs.docs) {
        await _isar.customFoods.put(_customFoodFromMap(d.data()));
      }
    });
  }

  Future<DateTime?> lastBackupAt() async {
    try {
      final snap = await _userDoc().get();
      final ts = snap.data()?['lastBackupAt'];
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {}
    return null;
  }

  /// Removes only leftover v1/v2 legacy collections (dailyLogs, foodEntries)
  /// without touching the current v4 data.  Safe to call any time.
  Future<void> deleteLegacyCloudData() async {
    // v1 flat foodEntries docs.
    final feSnap = await _userDoc().collection('foodEntries').get();
    for (final doc in feSnap.docs) {
      // v2 stored items as a subcollection under each date doc.
      final itemsSnap = await doc.reference.collection('items').get();
      if (itemsSnap.docs.isNotEmpty) {
        await _deleteInBatches(
            itemsSnap.docs.map((d) => d.reference).toList());
      }
    }
    if (feSnap.docs.isNotEmpty) {
      await _deleteInBatches(feSnap.docs.map((d) => d.reference).toList());
    }

    final dlSnap = await _userDoc().collection('dailyLogs').get();
    if (dlSnap.docs.isNotEmpty) {
      await _deleteInBatches(dlSnap.docs.map((d) => d.reference).toList());
    }
  }

  /// Deletes every document in the user's Firestore subtree, including
  /// subcollections (foods/meals under each day).  Does NOT touch local data.
  Future<void> deleteAllCloudData() async {
    // Delete legacy collections first (including their subcollections).
    await deleteLegacyCloudData();

    // Top-level v4 flat collections (no subcollections).
    final flatCols = [
      _weeksCol(),
      _monthsCol(),
      _workoutSessionsCol(),
      _exercisesCol(),
      _routinesCol(),
      _measurementsCol(),
      _periodLogsCol(),
      _customFoodsCol(),
      _userDoc().collection('profile'),
      _userDoc().collection('stats'),
    ];

    // Delete days + their foods/meals subcollections.
    final dayDocs = await _daysCol().get();
    for (final dayDoc in dayDocs.docs) {
      final dk = dayDoc.id;
      final foods = await _dayFoods(dk).get();
      if (foods.docs.isNotEmpty) {
        await _deleteInBatches(foods.docs.map((d) => d.reference).toList());
      }
      final meals = await _dayMeals(dk).get();
      if (meals.docs.isNotEmpty) {
        await _deleteInBatches(meals.docs.map((d) => d.reference).toList());
      }
      await _deleteInBatches([dayDoc.reference]);
    }

    // Delete flat v4 collections.
    for (final col in flatCols) {
      final snap = await col.get();
      if (snap.docs.isNotEmpty) {
        await _deleteInBatches(snap.docs.map((d) => d.reference).toList());
      }
    }

    // Delete the root user doc itself.
    await _userDoc().delete();
  }

  Future<void> _deleteInBatches(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    for (var i = 0; i < refs.length; i += 400) {
      final chunk = refs.sublist(i, math.min(i + 400, refs.length));
      final b = _fs.batch();
      for (final r in chunk) {
        b.delete(r);
      }
      await b.commit();
    }
  }

  /// Wipes all cloud data then re-uploads every local record.
  Future<void> resetAndPushAll() async {
    await deleteAllCloudData();
    await pushAll();
  }

  Future<void> restoreDay(DateTime date) async {
    final dateKey = DailyLog.keyFor(date);

    final daySnap = await _dayDoc(dateKey).get();
    final foodsSnap = await _dayFoods(dateKey).get();

    var cloudEntries =
        foodsSnap.docs.map((d) => _foodEntryFromMap(d.data())).toList();
    DailyLog? cloudLog =
        daySnap.exists ? _dailyLogFromMap(daySnap.data()!) : null;

    if (cloudEntries.isEmpty) {
      final v3 = await _userDoc()
          .collection('foodEntries')
          .doc(dateKey)
          .collection('items')
          .get();
      if (v3.docs.isNotEmpty) {
        cloudEntries = v3.docs.map((d) => _foodEntryFromMap(d.data())).toList();
      } else {
        final v1 = await _userDoc().collection('foodEntries').get();
        cloudEntries = v1.docs
            .where((d) =>
                d.data().containsKey('calories') &&
                (d.data()['dateKey'] as String?) == dateKey)
            .map((d) => _foodEntryFromMap(d.data()))
            .toList();
      }
    }

    if (cloudLog == null) {
      final old =
          await _userDoc().collection('dailyLogs').doc(dateKey).get();
      if (old.exists) cloudLog = _dailyLogFromMap(old.data()!);
    }

    await _isar.writeTxn(() async {
      final localIds = (await _isar.foodEntrys
              .filter()
              .dateKeyEqualTo(dateKey)
              .findAll())
          .map((e) => e.id)
          .toList();
      await _isar.foodEntrys.deleteAll(localIds);
      for (final e in cloudEntries) {
        await _isar.foodEntrys.put(e);
      }
      final localLogIds = (await _isar.dailyLogs
              .filter()
              .dateKeyEqualTo(dateKey)
              .findAll())
          .map((l) => l.id)
          .toList();
      await _isar.dailyLogs.deleteAll(localLogIds);
      if (cloudLog != null) await _isar.dailyLogs.put(cloudLog);
    });
  }

  // --- Aggregate builders ---------------------------------------------------

  void _buildAggregates(
    Map<String, List<FoodEntry>> byDate,
    Map<String, DailyLog?> logsByDate,
    Set<String> allDates,
    List<WorkoutSession> allSessions,
    List<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
        writes,
  ) {
    final weekAcc = <String, Map<String, num>>{};
    final monthAcc = <String, Map<String, num>>{};

    for (final dateKey in allDates) {
      final entries = byDate[dateKey] ?? [];
      if (entries.isEmpty) continue;
      final totals = NutritionRepo.sumEntries(entries);
      final date = DateTime.parse(dateKey);
      final wk = _weekKey(date);
      final mk = _monthKey(date);

      void acc(Map<String, Map<String, num>> map, String key) {
        final a = map.putIfAbsent(key, () => {
              'days': 0,
              'cal': 0,
              'prot': 0,
              'carb': 0,
              'fat': 0,
              'fib': 0
            });
        a['days'] = (a['days'] ?? 0) + 1;
        a['cal'] = (a['cal'] ?? 0) + totals.calories;
        a['prot'] = (a['prot'] ?? 0) + totals.proteinG;
        a['carb'] = (a['carb'] ?? 0) + totals.carbsG;
        a['fat'] = (a['fat'] ?? 0) + totals.fatG;
        a['fib'] = (a['fib'] ?? 0) + totals.fiberG;
      }

      acc(weekAcc, wk);
      acc(monthAcc, mk);
    }

    // Add session data to week / month accumulators.
    final weekTrain = <String, Map<String, num>>{};
    final monthTrain = <String, Map<String, num>>{};

    for (final s in allSessions) {
      if (s.dateKey.isEmpty) continue;
      final date = DateTime.tryParse(s.dateKey);
      if (date == null) continue;
      final wk = _weekKey(date);
      final mk = _monthKey(date);
      final vol =
          s.sets.fold<double>(0, (acc, st) => acc + st.weightKg * st.reps);

      void accT(Map<String, Map<String, num>> map, String key) {
        final a = map.putIfAbsent(
            key, () => {'sessions': 0, 'sets': 0, 'vol': 0, 'min': 0});
        a['sessions'] = (a['sessions'] ?? 0) + 1;
        a['sets'] = (a['sets'] ?? 0) + s.sets.length;
        a['vol'] = (a['vol'] ?? 0) + vol.round();
        a['min'] = (a['min'] ?? 0) + s.duration.inMinutes;
      }

      accT(weekTrain, wk);
      accT(monthTrain, mk);
    }

    // Write week documents.
    for (final entry in weekAcc.entries) {
      final wk = entry.key;
      final a = entry.value;
      final t = weekTrain[wk] ?? {};
      final days = (a['days'] ?? 0).toInt();
      final mondayStr = wk.substring(2); // remove "W-"
      final monday = DateTime.parse(mondayStr);
      final sunday = monday.add(const Duration(days: 6));

      writes.add((_weeksCol().doc(wk), {
        '_v': _v,
        'weekKey': wk,
        'startDate': _dateStr(monday),
        'endDate': _dateStr(sunday),
        'daysLogged': days,
        'nutrition': {
          'totalCalories': a['cal'],
          'avgCalories': days > 0 ? (a['cal']! ~/ days) : 0,
          'totalProteinG': a['prot'],
          'avgProteinG': days > 0 ? (a['prot']! ~/ days) : 0,
          'totalCarbsG': a['carb'],
          'totalFatG': a['fat'],
          'totalFiberG': a['fib'],
        },
        'training': {
          'sessions': t['sessions'] ?? 0,
          'totalSets': t['sets'] ?? 0,
          'totalVolumeKg': t['vol'] ?? 0,
          'totalMinutes': t['min'] ?? 0,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }

    // Write month documents.
    for (final entry in monthAcc.entries) {
      final mk = entry.key;
      final a = entry.value;
      final t = monthTrain[mk] ?? {};
      final days = (a['days'] ?? 0).toInt();
      final parts = mk.substring(2).split('-');
      writes.add((_monthsCol().doc(mk), {
        '_v': _v,
        'monthKey': mk,
        'year': int.parse(parts[0]),
        'month': int.parse(parts[1]),
        'daysLogged': days,
        'nutrition': {
          'totalCalories': a['cal'],
          'avgCalories': days > 0 ? (a['cal']! ~/ days) : 0,
          'totalProteinG': a['prot'],
          'avgProteinG': days > 0 ? (a['prot']! ~/ days) : 0,
          'totalCarbsG': a['carb'],
          'totalFatG': a['fat'],
        },
        'training': {
          'sessions': t['sessions'] ?? 0,
          'totalVolumeKg': t['vol'] ?? 0,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
  }

  void _buildStats(
    List<FoodEntry> allEntries,
    List<WorkoutSession> allSessions,
    Map<String, List<FoodEntry>> byDate,
    List<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
        writes,
  ) {
    final loggedDays = allEntries.map((e) => e.dateKey).toSet();
    final today = DateTime.now();
    final todayKey = DailyLog.keyFor(today);

    // Current streak.
    int currentStreak = 0;
    var check = loggedDays.contains(todayKey)
        ? today
        : today.subtract(const Duration(days: 1));
    while (loggedDays.contains(DailyLog.keyFor(check))) {
      currentStreak++;
      check = check.subtract(const Duration(days: 1));
    }

    // Longest streak.
    final sorted = loggedDays.toList()..sort();
    int longest = sorted.isEmpty ? 0 : 1;
    int run = sorted.isEmpty ? 0 : 1;
    for (var i = 1; i < sorted.length; i++) {
      if (DateTime.parse(sorted[i])
              .difference(DateTime.parse(sorted[i - 1]))
              .inDays ==
          1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    // 30-day average calories.
    final cutoff = DailyLog.keyFor(today.subtract(const Duration(days: 30)));
    int recentCal = 0, recentDays = 0;
    for (final dk in loggedDays) {
      if (dk.compareTo(cutoff) >= 0) {
        recentCal +=
            (byDate[dk] ?? []).fold<int>(0, (s, e) => s + e.calories);
        recentDays++;
      }
    }

    writes.add((_statsDoc(), {
      '_v': _v,
      'currentStreak': currentStreak,
      'longestStreak': longest,
      'totalDaysLogged': loggedDays.length,
      'totalFoodEntries': allEntries.length,
      'totalWorkoutSessions': allSessions.length,
      'avgDailyCaloriesLast30Days':
          recentDays > 0 ? recentCal ~/ recentDays : 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  // --- Meal grouping helpers ------------------------------------------------

  /// Groups entries so that one user input submission = one meal group.
  /// All entries from the same submission share the same rawInput and are
  /// logged at virtually the same timestamp. We match on rawInput within a
  /// 5-minute window so a slow AI response doesn't split one meal into two.
  List<List<FoodEntry>> _groupIntoMeals(List<FoodEntry> entries) {
    if (entries.isEmpty) return const [];
    final sorted = List<FoodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final groups = <List<FoodEntry>>[];
    for (final e in sorted) {
      bool added = false;
      if (e.rawInput.isNotEmpty) {
        for (var i = groups.length - 1; i >= 0; i--) {
          final g = groups[i];
          final diff =
              e.timestamp.difference(g.first.timestamp).inMinutes.abs();
          if (diff > 5) break;
          if (g.first.rawInput == e.rawInput) {
            g.add(e);
            added = true;
            break;
          }
        }
      }
      if (!added) groups.add([e]);
    }
    return groups;
  }

  /// Builds a human-readable Firestore doc ID for a meal, e.g.
  /// "2_240g_dahi_120g_puwa_corn_50g_aalu" so it's identifiable at a glance.
  String _mealDocId(int mealNum, String rawInput) {
    final slug = rawInput
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final truncated = slug.length > 40 ? slug.substring(0, 40) : slug;
    return '${mealNum}_$truncated';
  }

  String _mealLabel(DateTime t) {
    final h = t.hour;
    if (h >= 4 && h < 10) return 'Breakfast';
    if (h >= 10 && h < 12) return 'Mid-Morning Snack';
    if (h >= 12 && h < 15) return 'Lunch';
    if (h >= 15 && h < 18) return 'Afternoon Snack';
    if (h >= 18 && h < 21) return 'Dinner';
    return 'Late Night';
  }

  String _fmtTime(DateTime t) {
    final h = t.hour;
    final p = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${t.minute.toString().padLeft(2, '0')} $p';
  }

  String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return 'W-${_dateStr(monday)}';
  }

  String _monthKey(DateTime d) =>
      'M-${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --- Date helper (reads Timestamp or ISO string) --------------------------

  DateTime _ts(dynamic v, [DateTime? fallback]) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? fallback ?? DateTime.now();
    return fallback ?? DateTime.now();
  }

  // --- Mappers --------------------------------------------------------------

  // ── Profile ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _profileToMap(Profile p) => {
        '_v': _v,
        'personal': {
          'displayName': p.displayName,
          'age': p.age,
          'gender': p.gender.name,
          'country': p.country,
          'dietPreference': p.dietPreference.name,
          'cyclePhase': p.cyclePhase.name,
        },
        'body': {
          'heightCm': p.heightCm,
          'weightKg': p.weightKg,
          'bmi': p.bmi,
          'bmr': p.bmr,
          'tdee': p.tdee,
          'bodyFatPct': p.bodyFatPct,
          'bodyFocusNotes': p.bodyFocusNotes,
        },
        'goal': {
          'fitnessGoal': p.goal.name,
          'activityLevel': p.activityLevel.name,
          'trainingDaysPerWeek': p.trainingDaysPerWeek,
          'cardioSessionsPerWeek': p.cardioSessionsPerWeek,
          'goesGym': p.goesGym,
          'workoutType': p.workoutType.name,
          'gymStartDate': p.gymStartDate != null
              ? Timestamp.fromDate(p.gymStartDate!)
              : null,
        },
        'activityBaseline': {
          'walkingKmPerDay': p.walkingKmPerDay,
          'runningKmPerWeek': p.runningKmPerWeek,
          'gymMinutesPerSession': p.gymMinutesPerSession,
        },
        'targets': {
          'calories': p.calorieTarget,
          'proteinG': p.proteinTargetG,
          'carbsG': p.carbTargetG,
          'fatG': p.fatTargetG,
          'fiberG': p.fiberTargetG,
          'waterMl': p.waterTargetMl,
        },
        'overrides': {
          'calories': p.calorieOverride,
          'proteinG': p.proteinOverride,
          'carbsG': p.carbOverride,
          'fatG': p.fatOverride,
          'fiberG': p.fiberOverride,
          'waterMl': p.waterOverride,
        },
        'effectiveTargets': {
          'calories': p.effectiveCalorieTarget,
          'proteinG': p.effectiveProteinTarget,
          'carbsG': p.effectiveCarbTarget,
          'fatG': p.effectiveFatTarget,
          'fiberG': p.effectiveFiberTarget,
          'waterMl': p.effectiveWaterTarget,
        },
        'schedule': {
          'restDays': p.restDays,
          'wakeTimeMin': p.wakeTimeMin,
          'sleepTimeMin': p.sleepTimeMin,
          'wakeMinByDay': p.wakeMinByDay,
          'sleepMinByDay': p.sleepMinByDay,
          'weighInCadence': p.weighInCadence.name,
          'weighInWeekday': p.weighInWeekday,
        },
        'supplements': {
          'creatineGramsPerDay': p.creatineGramsPerDay,
          'proteinScoopsPerDay': p.proteinScoopsPerDay,
          'proteinGramsPerDay': p.proteinGramsPerDay,
          'multivitamin': p.multivitamin,
          'otherNote': p.otherSupplementsNote,
        },
        'health': {
          'flags': p.healthFlags.map((f) => f.name).toList(),
        },
        'meta': {
          'createdAt': Timestamp.fromDate(p.createdAt),
          'updatedAt': Timestamp.fromDate(p.updatedAt),
        },
      };

  Profile _profileFromMap(Map<String, dynamic> m) {
    Map<String, dynamic> s(String k) =>
        (m[k] as Map<String, dynamic>?) ?? const {};
    final personal = s('personal');
    final body = s('body');
    final goal = s('goal');
    final baseline = s('activityBaseline');
    final targets = s('targets');
    final overrides = s('overrides');
    final schedule = s('schedule');
    final supps = s('supplements');
    final health = s('health');
    final meta = s('meta');

    dynamic nf(Map n, String nk, String fk) => n[nk] ?? m[fk];

    return Profile()
      ..id = 0
      ..displayName =
          (nf(personal, 'displayName', 'displayName') as String?) ?? ''
      ..age = (nf(personal, 'age', 'age') as num?)?.toInt() ?? 22
      ..gender = _enumFromName(
              Gender.values, nf(personal, 'gender', 'gender') as String?) ??
          Gender.male
      ..country = (nf(personal, 'country', 'country') as String?) ?? ''
      ..dietPreference = _enumFromName(DietPreference.values,
              nf(personal, 'dietPreference', 'dietPreference') as String?) ??
          DietPreference.omnivore
      ..cyclePhase = _enumFromName(CyclePhase.values,
              nf(personal, 'cyclePhase', 'cyclePhase') as String?) ??
          CyclePhase.unknown
      ..heightCm =
          (nf(body, 'heightCm', 'heightCm') as num?)?.toDouble() ?? 170
      ..weightKg =
          (nf(body, 'weightKg', 'weightKg') as num?)?.toDouble() ?? 70
      ..bmi = (nf(body, 'bmi', 'bmi') as num?)?.toDouble() ?? 22
      ..bmr = (nf(body, 'bmr', 'bmr') as num?)?.toDouble() ?? 0
      ..tdee = (nf(body, 'tdee', 'tdee') as num?)?.toDouble() ?? 0
      ..bodyFatPct =
          (nf(body, 'bodyFatPct', 'bodyFatPct') as num?)?.toDouble()
      ..bodyFocusNotes =
          (nf(body, 'bodyFocusNotes', 'bodyFocusNotes') as String?) ?? ''
      ..goal = _enumFromName(FitnessGoal.values,
              (goal['fitnessGoal'] ?? m['goal']) as String?) ??
          FitnessGoal.generalFitness
      ..activityLevel = _enumFromName(ActivityLevel.values,
              nf(goal, 'activityLevel', 'activityLevel') as String?) ??
          ActivityLevel.moderate
      ..trainingDaysPerWeek =
          (nf(goal, 'trainingDaysPerWeek', 'trainingDaysPerWeek') as num?)
                  ?.toInt() ??
              3
      ..cardioSessionsPerWeek =
          (nf(goal, 'cardioSessionsPerWeek', 'cardioSessionsPerWeek') as num?)
                  ?.toInt() ??
              0
      ..goesGym = (nf(goal, 'goesGym', 'goesGym') as bool?) ?? true
      ..workoutType = WorkoutType.values.firstWhere(
          (e) => e.name == (goal['workoutType'] as String? ?? ''),
          orElse: () => WorkoutType.gym)
      ..gymStartDate =
          goal['gymStartDate'] != null ? _ts(goal['gymStartDate']) : null
      ..walkingKmPerDay =
          (nf(baseline, 'walkingKmPerDay', 'walkingKmPerDay') as num?)
                  ?.toDouble() ??
              0
      ..runningKmPerWeek =
          (nf(baseline, 'runningKmPerWeek', 'runningKmPerWeek') as num?)
                  ?.toDouble() ??
              0
      ..gymMinutesPerSession =
          (nf(baseline, 'gymMinutesPerSession', 'gymMinutesPerSession') as num?)
                  ?.toInt() ??
              60
      ..calorieTarget =
          (nf(targets, 'calories', 'calorieTarget') as num?)?.toInt() ?? 2000
      ..proteinTargetG =
          (nf(targets, 'proteinG', 'proteinTargetG') as num?)?.toInt() ?? 120
      ..carbTargetG =
          (nf(targets, 'carbsG', 'carbTargetG') as num?)?.toInt() ?? 230
      ..fatTargetG =
          (nf(targets, 'fatG', 'fatTargetG') as num?)?.toInt() ?? 65
      ..fiberTargetG =
          (nf(targets, 'fiberG', 'fiberTargetG') as num?)?.toInt() ?? 28
      ..waterTargetMl =
          (nf(targets, 'waterMl', 'waterTargetMl') as num?)?.toInt() ?? 2500
      ..calorieOverride =
          (nf(overrides, 'calories', 'calorieOverride') as num?)?.toInt()
      ..proteinOverride =
          (nf(overrides, 'proteinG', 'proteinOverride') as num?)?.toInt()
      ..carbOverride =
          (nf(overrides, 'carbsG', 'carbOverride') as num?)?.toInt()
      ..fatOverride =
          (nf(overrides, 'fatG', 'fatOverride') as num?)?.toInt()
      ..fiberOverride =
          (nf(overrides, 'fiberG', 'fiberOverride') as num?)?.toInt()
      ..waterOverride =
          (nf(overrides, 'waterMl', 'waterOverride') as num?)?.toInt()
      ..restDays =
          ((nf(schedule, 'restDays', 'restDays') as List?) ?? [])
              .map((e) => (e as num).toInt())
              .toList()
      ..wakeTimeMin =
          (nf(schedule, 'wakeTimeMin', 'wakeTimeMin') as num?)?.toInt() ?? 420
      ..sleepTimeMin =
          (nf(schedule, 'sleepTimeMin', 'sleepTimeMin') as num?)?.toInt() ??
              1380
      ..wakeMinByDay =
          ((nf(schedule, 'wakeMinByDay', 'wakeMinByDay') as List?) ?? [])
              .map((e) => (e as num).toInt())
              .toList()
      ..sleepMinByDay =
          ((nf(schedule, 'sleepMinByDay', 'sleepMinByDay') as List?) ?? [])
              .map((e) => (e as num).toInt())
              .toList()
      ..weighInCadence = _enumFromName(WeighInCadence.values,
              nf(schedule, 'weighInCadence', 'weighInCadence') as String?) ??
          WeighInCadence.weekly
      ..weighInWeekday =
          (nf(schedule, 'weighInWeekday', 'weighInWeekday') as num?)?.toInt()
      ..creatineGramsPerDay =
          (nf(supps, 'creatineGramsPerDay', 'creatineGramsPerDay') as num?)
                  ?.toInt() ??
              0
      ..proteinScoopsPerDay =
          (nf(supps, 'proteinScoopsPerDay', 'proteinScoopsPerDay') as num?)
                  ?.toInt() ??
              0
      ..proteinGramsPerDay =
          (nf(supps, 'proteinGramsPerDay', 'proteinGramsPerDay') as num?)
                  ?.toInt() ??
              0
      ..multivitamin =
          (nf(supps, 'multivitamin', 'multivitamin') as bool?) ?? false
      ..otherSupplementsNote =
          (nf(supps, 'otherNote', 'otherSupplementsNote') as String?) ?? ''
      ..healthFlags =
          ((health['flags'] ?? m['healthFlags'] ?? []) as List)
              .map((e) => _enumFromName(HealthFlag.values, e as String?))
              .whereType<HealthFlag>()
              .toList()
      ..createdAt = _ts(meta['createdAt'] ?? m['createdAt'], DateTime.now())
      ..updatedAt = _ts(meta['updatedAt'] ?? m['updatedAt'], DateTime.now());
  }

  // ── Day / food entries ───────────────────────────────────────────────────

  Map<String, dynamic> _dayToMap(
    String dateKey,
    DailyLog? log,
    DailyTotals totals,
    Profile? profile,
    int mealCount,
  ) {
    final walkKm = log?.walkingKmToday ?? 0.0;
    final runKm = log?.runningKmToday ?? 0.0;
    final cardioMin = log?.otherCardioMinutes ?? 0;
    final wScale = (profile?.weightKg ?? 70) / 70.0;
    // Strip the profile's average walk/run burn so caloriesBase is
    // activity-neutral — transparent "base + today's activity = target".
    final profileWalkKcal = (profile?.walkingKmPerDay ?? 0) * 50 * wScale;
    final profileRunKcal = ((profile?.runningKmPerWeek ?? 0) / 7.0) * 70 * wScale;
    final base = ((profile?.effectiveCalorieTarget ?? 0) - profileWalkKcal - profileRunKcal).round();
    final bonus = ((walkKm * 50 + runKm * 70) * wScale +
            cardioMin.clamp(0, 240) * 9.0 * wScale)
        .round();

    final waterEntryMaps = (log?.waterEntries ?? []).map((e) {
      final h = e.minutesOfDay ~/ 60;
      final mn = e.minutesOfDay % 60;
      final p = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return {
        'time': '$h12:${mn.toString().padLeft(2, '0')} $p',
        'minutesOfDay': e.minutesOfDay,
        'ml': e.ml,
      };
    }).toList();

    return {
      '_v': _v,
      'dateKey': dateKey,
      'consumed': {
        'calories': totals.calories,
        'proteinG': totals.proteinG,
        'carbsG': totals.carbsG,
        'fatG': totals.fatG,
        'fiberG': totals.fiberG,
        'sodiumMg': totals.sodiumMg,
        'waterMl': totals.waterMl,
        'mealCount': mealCount,
        'itemCount': totals.entryCount,
      },
      'target': {
        'caloriesBase': base,
        'caloriesAdjusted': base + bonus,
        'activityBonusKcal': bonus,
        'proteinG': profile?.effectiveProteinTarget,
        'carbsG': profile?.effectiveCarbTarget,
        'fatG': profile?.effectiveFatTarget,
        'fiberG': profile?.effectiveFiberTarget,
        'waterMl': profile?.effectiveWaterTarget,
      },
      'activity': {
        'walkingKm': walkKm,
        'runningKm': runKm,
        'otherCardioMin': cardioMin,
        'steps': log?.steps,
        'heartRateAvg': log?.heartRateAvg,
        'note': log?.activityNote,
      },
      'sleep': {
        'minutes': log?.sleepMinutes,
        'hours': log?.sleepMinutes == null
            ? null
            : double.parse((log!.sleepMinutes! / 60.0).toStringAsFixed(1)),
      },
      'water': {'totalMl': log?.waterMl ?? 0, 'entries': waterEntryMaps},
      // Flat log fields preserved for DailyLog reconstruction.
      'waterMl': log?.waterMl ?? 0,
      'waterEntries': waterEntryMaps,
      'steps': log?.steps,
      'heartRateAvg': log?.heartRateAvg,
      'sleepMinutes': log?.sleepMinutes,
      'walkingKmToday': walkKm,
      'runningKmToday': runKm,
      'otherCardioMinutes': cardioMin,
      'activityNote': log?.activityNote,
      'updatedAt': Timestamp.fromDate(log?.updatedAt ?? DateTime.now()),
    };
  }

  Map<String, dynamic> _foodEntryToMap(
    FoodEntry e, {
    int mealNumber = 1,
    String mealLabel = '',
    String mealTime = '',
  }) =>
      {
        'id': e.id,
        '_v': _v,
        'meal': {'number': mealNumber, 'label': mealLabel, 'time': mealTime},
        'food': {
          'description': e.description,
          'rawInput': e.rawInput,
          'quantity': e.quantity,
          'unit': e.unit,
          if (e.photoPath != null) 'photoPath': e.photoPath,
        },
        'nutrition': {
          'calories': e.calories,
          'proteinG': e.proteinG,
          'carbsG': e.carbsG,
          'fatG': e.fatG,
          'fiberG': e.fiberG,
          'sodiumMg': e.sodiumMg,
          'caloriesLow': e.caloriesLow,
          'caloriesHigh': e.caloriesHigh,
        },
        'meta': {
          'source': e.source.name,
          'confidence': e.confidence.name,
          'isFavorite': e.isFavorite,
          'timestamp': Timestamp.fromDate(e.timestamp),
          'dateKey': e.dateKey,
        },
      };

  FoodEntry _foodEntryFromMap(Map<String, dynamic> m) {
    final food = (m['food'] as Map<String, dynamic>?) ?? const {};
    final nutrition = (m['nutrition'] as Map<String, dynamic>?) ?? const {};
    final meta = (m['meta'] as Map<String, dynamic>?) ?? const {};
    return FoodEntry()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..timestamp = _ts(meta['timestamp'] ?? m['timestamp'])
      ..dateKey = (meta['dateKey'] ?? m['dateKey'] ?? '') as String
      ..rawInput = (food['rawInput'] ?? m['rawInput'] ?? '') as String
      ..description = (food['description'] ?? m['description'] ?? '') as String
      ..quantity = (food['quantity'] ?? m['quantity'] ?? '') as String
      ..unit = (food['unit'] ?? m['unit'] ?? '') as String
      ..calories =
          ((nutrition['calories'] ?? m['calories']) as num?)?.toInt() ?? 0
      ..proteinG =
          ((nutrition['proteinG'] ?? m['proteinG']) as num?)?.toInt() ?? 0
      ..carbsG =
          ((nutrition['carbsG'] ?? m['carbsG']) as num?)?.toInt() ?? 0
      ..fatG = ((nutrition['fatG'] ?? m['fatG']) as num?)?.toInt() ?? 0
      ..fiberG =
          ((nutrition['fiberG'] ?? m['fiberG']) as num?)?.toInt() ?? 0
      ..sodiumMg =
          ((nutrition['sodiumMg'] ?? m['sodiumMg']) as num?)?.toInt() ?? 0
      ..source = _enumFromName(
              FoodSource.values, (meta['source'] ?? m['source']) as String?) ??
          FoodSource.aiText
      ..confidence = _enumFromName(EstimateConfidence.values,
              (meta['confidence'] ?? m['confidence']) as String?) ??
          EstimateConfidence.medium
      ..caloriesLow =
          ((nutrition['caloriesLow'] ?? m['caloriesLow']) as num?)?.toInt()
      ..caloriesHigh =
          ((nutrition['caloriesHigh'] ?? m['caloriesHigh']) as num?)?.toInt()
      ..isFavorite =
          (meta['isFavorite'] ?? m['isFavorite'] ?? false) as bool
      ..photoPath = (food['photoPath'] ?? m['photoPath']) as String?;
  }

  DailyLog _dailyLogFromMap(Map<String, dynamic> m) {
    final waterRaw = m['waterEntries'];
    final waterEntries = <WaterEntry>[];
    if (waterRaw is List) {
      for (final item in waterRaw) {
        if (item is Map) {
          waterEntries.add(WaterEntry()
            ..minutesOfDay = (item['minutesOfDay'] as num?)?.toInt() ?? 0
            ..ml = (item['ml'] as num?)?.toInt() ?? 0);
        }
      }
    }
    return DailyLog()
      ..dateKey = (m['dateKey'] as String?) ?? ''
      ..waterMl = (m['waterMl'] as num?)?.toInt() ?? 0
      ..steps = (m['steps'] as num?)?.toInt()
      ..heartRateAvg = (m['heartRateAvg'] as num?)?.toInt()
      ..sleepMinutes = (m['sleepMinutes'] as num?)?.toInt()
      ..walkingKmToday = (m['walkingKmToday'] as num?)?.toDouble() ?? 0
      ..runningKmToday = (m['runningKmToday'] as num?)?.toDouble() ?? 0
      ..otherCardioMinutes = (m['otherCardioMinutes'] as num?)?.toInt() ?? 0
      ..activityNote = m['activityNote'] as String?
      ..waterEntries = waterEntries
      ..updatedAt = _ts(m['updatedAt']);
  }

  // ── Workout ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _workoutSessionToMap(WorkoutSession s) {
    final totalSets = s.sets.length;
    final totalReps = s.sets.fold(0, (acc, st) => acc + st.reps);
    final totalVol =
        s.sets.fold(0.0, (acc, st) => acc + st.weightKg * st.reps);
    final uniqueEx = s.sets.map((st) => st.exerciseId).toSet().length;
    return {
      'id': s.id,
      '_v': _v,
      'dateKey': s.dateKey,
      'routineName': s.routineName,
      'routineDayName': s.routineDayName,
      'startedAt': Timestamp.fromDate(s.startedAt),
      'completedAt':
          s.completedAt != null ? Timestamp.fromDate(s.completedAt!) : null,
      'duration': {'minutes': s.duration.inMinutes},
      'stats': {
        'totalSets': totalSets,
        'totalReps': totalReps,
        'totalVolumeKg': totalVol.round(),
        'uniqueExercises': uniqueEx,
      },
      'perceivedDifficulty': s.perceivedDifficulty,
      'note': s.note,
      'sets': s.sets
          .map((st) => {
                'exerciseId': st.exerciseId,
                'exerciseName': st.exerciseName,
                'setNumber': st.setNumber,
                'weightKg': st.weightKg,
                'reps': st.reps,
                'rpe': st.rpe,
                'isWarmup': st.isWarmup,
                'completedAt': Timestamp.fromDate(st.completedAt),
              })
          .toList(),
    };
  }

  WorkoutSession _workoutSessionFromMap(Map<String, dynamic> m) {
    final sets = <SetEntry>[];
    for (final s in (m['sets'] as List?) ?? []) {
      if (s is Map<String, dynamic>) {
        sets.add(SetEntry()
          ..exerciseId = (s['exerciseId'] as num?)?.toInt() ?? 0
          ..exerciseName = (s['exerciseName'] as String?) ?? ''
          ..setNumber = (s['setNumber'] as num?)?.toInt() ?? 1
          ..weightKg = (s['weightKg'] as num?)?.toDouble() ?? 0
          ..reps = (s['reps'] as num?)?.toInt() ?? 0
          ..rpe = (s['rpe'] as num?)?.toDouble()
          ..isWarmup = (s['isWarmup'] as bool?) ?? false
          ..completedAt = _ts(s['completedAt']));
      }
    }
    return WorkoutSession()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..dateKey = (m['dateKey'] as String?) ?? ''
      ..startedAt = _ts(m['startedAt'])
      ..completedAt = m['completedAt'] != null ? _ts(m['completedAt']) : null
      ..routineName = (m['routineName'] as String?) ?? ''
      ..routineDayName = (m['routineDayName'] as String?) ?? ''
      ..perceivedDifficulty = (m['perceivedDifficulty'] as num?)?.toInt()
      ..note = m['note'] as String?
      ..sets = sets;
  }

  Map<String, dynamic> _exerciseToMap(Exercise e) => {
        'id': e.id,
        '_v': _v,
        'name': e.name,
        'muscleGroups': e.muscleGroups.map((g) => g.name).toList(),
        'equipment': e.equipment.name,
        'isBeginnerFriendly': e.isBeginnerFriendly,
        'isSeeded': e.isSeeded,
        'formCues': e.formCues,
        'commonMistakes': e.commonMistakes,
        'defaultRestSeconds': e.defaultRestSeconds,
        'createdAt': Timestamp.fromDate(e.createdAt),
      };

  Exercise _exerciseFromMap(Map<String, dynamic> m) => Exercise()
    ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
    ..name = (m['name'] as String?) ?? ''
    ..muscleGroups = ((m['muscleGroups'] as List?) ?? [])
        .map((g) => _enumFromName(MuscleGroup.values, g as String?))
        .whereType<MuscleGroup>()
        .toList()
    ..equipment =
        _enumFromName(Equipment.values, m['equipment'] as String?) ??
            Equipment.bodyweight
    ..isBeginnerFriendly = (m['isBeginnerFriendly'] as bool?) ?? true
    ..isSeeded = (m['isSeeded'] as bool?) ?? false
    ..formCues = ((m['formCues'] as List?) ?? []).cast<String>()
    ..commonMistakes = ((m['commonMistakes'] as List?) ?? []).cast<String>()
    ..defaultRestSeconds = (m['defaultRestSeconds'] as num?)?.toInt() ?? 90
    ..createdAt = _ts(m['createdAt']);

  Map<String, dynamic> _routineToMap(Routine r) => {
        'id': r.id,
        '_v': _v,
        'name': r.name,
        'description': r.description,
        'isActive': r.isActive,
        'days': r.days
            .map((d) => {
                  'name': d.name,
                  'weekday': d.weekday,
                  'isRest': d.isRest,
                  'items': d.items
                      .map((i) => {
                            'exerciseId': i.exerciseId,
                            'exerciseName': i.exerciseName,
                            'targetSets': i.targetSets,
                            'targetRepsLow': i.targetRepsLow,
                            'targetRepsHigh': i.targetRepsHigh,
                            'targetWeightKg': i.targetWeightKg,
                            'restSeconds': i.restSeconds,
                            'notes': i.notes,
                          })
                      .toList(),
                })
            .toList(),
        'createdAt': Timestamp.fromDate(r.createdAt),
        'updatedAt': Timestamp.fromDate(r.updatedAt),
      };

  Routine _routineFromMap(Map<String, dynamic> m) {
    final days = <RoutineDay>[];
    for (final d in (m['days'] as List?) ?? []) {
      if (d is Map<String, dynamic>) {
        final items = <RoutinePlanItem>[];
        for (final i in (d['items'] as List?) ?? []) {
          if (i is Map<String, dynamic>) {
            items.add(RoutinePlanItem()
              ..exerciseId = (i['exerciseId'] as num?)?.toInt() ?? 0
              ..exerciseName = (i['exerciseName'] as String?) ?? ''
              ..targetSets = (i['targetSets'] as num?)?.toInt() ?? 3
              ..targetRepsLow = (i['targetRepsLow'] as num?)?.toInt() ?? 8
              ..targetRepsHigh = (i['targetRepsHigh'] as num?)?.toInt() ?? 12
              ..targetWeightKg = (i['targetWeightKg'] as num?)?.toDouble()
              ..restSeconds = (i['restSeconds'] as num?)?.toInt() ?? 90
              ..notes = i['notes'] as String?);
          }
        }
        days.add(RoutineDay()
          ..name = (d['name'] as String?) ?? ''
          ..weekday = (d['weekday'] as num?)?.toInt() ?? 0
          ..isRest = (d['isRest'] as bool?) ?? false
          ..items = items);
      }
    }
    return Routine()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..name = (m['name'] as String?) ?? ''
      ..description = m['description'] as String?
      ..isActive = (m['isActive'] as bool?) ?? false
      ..days = days
      ..createdAt = _ts(m['createdAt'])
      ..updatedAt = _ts(m['updatedAt']);
  }

  // ── Body measurements ────────────────────────────────────────────────────

  Map<String, dynamic> _measurementToMap(BodyMeasurement m) => {
        'id': m.id,
        '_v': _v,
        'date': Timestamp.fromDate(m.date),
        'dateKey': DailyLog.keyFor(m.date),
        'weightKg': m.weightKg,
        'bodyFatPct': m.bodyFatPct,
        'measurements': {
          'waistCm': m.waistCm,
          'chestCm': m.chestCm,
          'hipsCm': m.hipsCm,
          'thighCm': m.thighCm,
          'armCm': m.armCm,
          'neckCm': m.neckCm,
        },
        'note': m.note,
        'createdAt': Timestamp.fromDate(m.createdAt),
        // photoPath intentionally excluded: local device path only.
      };

  BodyMeasurement _measurementFromMap(Map<String, dynamic> m) {
    final meas = (m['measurements'] as Map<String, dynamic>?) ?? const {};
    return BodyMeasurement()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..date = _ts(m['date'])
      ..weightKg = (m['weightKg'] as num?)?.toDouble() ?? 0
      ..bodyFatPct = (m['bodyFatPct'] as num?)?.toDouble()
      ..waistCm = (meas['waistCm'] as num?)?.toDouble()
      ..chestCm = (meas['chestCm'] as num?)?.toDouble()
      ..hipsCm = (meas['hipsCm'] as num?)?.toDouble()
      ..thighCm = (meas['thighCm'] as num?)?.toDouble()
      ..armCm = (meas['armCm'] as num?)?.toDouble()
      ..neckCm = (meas['neckCm'] as num?)?.toDouble()
      ..note = m['note'] as String?
      ..createdAt = _ts(m['createdAt']);
  }

  // ── Period logs ──────────────────────────────────────────────────────────

  Map<String, dynamic> _periodLogToMap(PeriodLog l) => {
        '_v': _v,
        'dateKey': l.dateKey,
        'date': Timestamp.fromDate(l.date),
        'flow': l.flow.name,
        'symptoms': l.symptoms.map((s) => s.name).toList(),
        'notes': l.notes,
        'createdAt': Timestamp.fromDate(l.createdAt),
        'updatedAt': Timestamp.fromDate(l.updatedAt),
      };

  PeriodLog _periodLogFromMap(Map<String, dynamic> m) => PeriodLog()
    ..dateKey = (m['dateKey'] as String?) ?? ''
    ..date = _ts(m['date'])
    ..flow =
        _enumFromName(MenstrualFlow.values, m['flow'] as String?) ??
            MenstrualFlow.none
    ..symptoms = ((m['symptoms'] as List?) ?? [])
        .map((s) => _enumFromName(PeriodSymptom.values, s as String?))
        .whereType<PeriodSymptom>()
        .toList()
    ..notes = (m['notes'] as String?) ?? ''
    ..createdAt = _ts(m['createdAt'])
    ..updatedAt = _ts(m['updatedAt']);

  // ── Custom foods ──────────────────────────────────────────────────────────

  Map<String, dynamic> _customFoodToMap(CustomFood c) => {
        'id': c.id,
        '_v': _v,
        'name': c.name,
        'servingSizeG': c.servingSizeG,
        'servingDescription': c.servingDescription,
        'caloriesPerServing': c.caloriesPerServing,
        'proteinGPerServing': c.proteinGPerServing,
        'carbsGPerServing': c.carbsGPerServing,
        'fatGPerServing': c.fatGPerServing,
        'fiberGPerServing': c.fiberGPerServing,
        'sodiumMgPerServing': c.sodiumMgPerServing,
        'ingredients': c.ingredients,
        'createdAt': Timestamp.fromDate(c.createdAt),
      };

  CustomFood _customFoodFromMap(Map<String, dynamic> m) => CustomFood()
    ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
    ..name = (m['name'] as String?) ?? ''
    ..servingSizeG = (m['servingSizeG'] as num?)?.toDouble() ?? 100
    ..servingDescription = (m['servingDescription'] as String?) ?? '1 serving'
    ..caloriesPerServing = (m['caloriesPerServing'] as num?)?.toInt() ?? 0
    ..proteinGPerServing = (m['prote                                                                                                            inGPerServing'] as num?)?.toInt() ?? 0
    ..carbsGPerServing = (m['carbsGPerServing'] as num?)?.toInt() ?? 0
    ..fatGPerServing = (m['fatGPerServing'] as num?)?.toInt() ?? 0
    ..fiberGPerServing = (m['fiberGPerServing'] as num?)?.toInt() ?? 0
    ..sodiumMgPerServing = (m['sodiumMgPerServing'] as num?)?.toInt() ?? 0
    ..ingredients = m['ingredients'] as String?
    ..createdAt = _ts(m['createdAt']);

  T? _enumFromName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
