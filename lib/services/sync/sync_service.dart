import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';

import '../../data/db.dart';
import '../../data/models/custom_food.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/nutrition_repo.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Firestore layout (v4 — fully organised, industry-standard)
///
/// users/{uid}
/// ├── email          "user@gmail.com"
/// ├── displayName    "Rajendra Pandey"
/// ├── uid            "32u4X…"
/// ├── lastBackupAt   Timestamp
/// │
/// ├── profile/main
/// │   ├── personal   { displayName, age, gender, country, dietPreference,
/// │   │                cyclePhase }
/// │   ├── body       { heightCm, weightKg, bmi, bmr, tdee, bodyFatPct,
/// │   │                bodyFocusNotes }
/// │   ├── goal       { fitnessGoal, activityLevel, trainingDaysPerWeek,
/// │   │                cardioSessionsPerWeek, goesGym, gymStartDate }
/// │   ├── activityBaseline { walkingKmPerDay, runningKmPerWeek,
/// │   │                      gymMinutesPerSession }
/// │   ├── targets    { calories, proteinG, carbsG, fatG, fiberG, waterMl }
/// │   ├── overrides  { calories?, proteinG?, carbsG?, fatG?, fiberG?, waterMl? }
/// │   ├── effectiveTargets { calories, proteinG, carbsG, fatG, fiberG, waterMl }
/// │   ├── schedule   { restDays, wakeTimeMin, sleepTimeMin,
/// │   │                wakeMinByDay, sleepMinByDay,
/// │   │                weighInCadence, weighInWeekday }
/// │   ├── supplements { creatineGramsPerDay, proteinScoopsPerDay,
/// │   │                 multivitamin, otherNote }
/// │   ├── health     { flags: [...], bodyFocusNotes }
/// │   └── meta       { createdAt, updatedAt }
/// │
/// ├── days/{dateKey}   e.g. "2026-06-29"
/// │   ├── dateKey      "2026-06-29"
/// │   ├── consumed     { calories, proteinG, carbsG, fatG, fiberG, sodiumMg,
/// │   │                  waterMl, mealCount, itemCount }
/// │   ├── target       { caloriesBase, caloriesAdjusted, activityBonusKcal,
/// │   │                  proteinG, carbsG, fatG, fiberG, waterMl }
/// │   ├── activity     { walkingKm, runningKm, otherCardioMin, steps,
/// │   │                  heartRateAvg, note }
/// │   ├── sleep        { minutes, hours }
/// │   ├── water        { totalMl, entries: [{time, minutesOfDay, ml}] }
/// │   ├── updatedAt
/// │   │
/// │   ├── meals/{n}    Meal summary (1-based)
/// │   │   ├── mealNumber, label (Breakfast/Lunch/…), time ("7:10 AM")
/// │   │   ├── calories, proteinG, carbsG, fatG, fiberG, itemCount
/// │   │   └── rawInputs: ["172g cheura and 138g dahi…"]
/// │   │
/// │   └── foods/{isarId}   Individual food entry
/// │       ├── id, meal: {number, label, time}
/// │       ├── food: {description, rawInput, quantity, unit}
/// │       ├── nutrition: {calories, proteinG, carbsG, fatG, fiberG, sodiumMg,
/// │       │               caloriesLow, caloriesHigh}
/// │       └── meta: {source, confidence, isFavorite, timestamp, dateKey}
/// │
/// └── customFoods/{id}
///     └── { name, servingSizeG, servingDescription, caloriesPerServing,
///            proteinGPerServing, carbsGPerServing, fatGPerServing,
///            fiberGPerServing, sodiumMgPerServing, ingredients, createdAt }
/// ─────────────────────────────────────────────────────────────────────────────
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

  Isar get _isar => _db.isar;
  String? get _uid => _auth.currentUser?.uid;

  // --- Collection references ------------------------------------------------

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');
    return _fs.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _daysCol() =>
      _userDoc().collection('days');
  DocumentReference<Map<String, dynamic>> _dayDoc(String dk) =>
      _daysCol().doc(dk);
  CollectionReference<Map<String, dynamic>> _dayFoods(String dk) =>
      _dayDoc(dk).collection('foods');
  CollectionReference<Map<String, dynamic>> _dayMeals(String dk) =>
      _dayDoc(dk).collection('meals');
  DocumentReference<Map<String, dynamic>> _profileDoc() =>
      _userDoc().collection('profile').doc('main');
  CollectionReference<Map<String, dynamic>> _customFoods() =>
      _userDoc().collection('customFoods');

  // --- Public API -----------------------------------------------------------

  Future<bool> cloudHasData() async {
    final p = await _profileDoc().get();
    if (p.exists) return true;
    final d = await _daysCol().limit(1).get();
    if (d.docs.isNotEmpty) return true;
    // Legacy check
    final f = await _userDoc().collection('foodEntries').limit(1).get();
    return f.docs.isNotEmpty;
  }

  Future<bool> localHasData() async {
    if (await _isar.profiles.count() > 0) return true;
    return await _isar.foodEntrys.count() > 0;
  }

  /// Push every local record to Firestore. Groups food entries by date and
  /// by meal (30-minute proximity window) so the console is human-readable.
  Future<void> pushAll() async {
    final user = _auth.currentUser;
    final profile = await _isar.profiles.where().findFirst();

    // User identity — visible at the root of the document tree.
    await _userDoc().set({
      'email': user?.email,
      'displayName': user?.displayName ?? profile?.displayName,
      'uid': user?.uid,
      'lastBackupAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (profile != null) {
      await _profileDoc().set(_profileToMap(profile));
    }

    // Group food entries by date.
    final allEntries = await _isar.foodEntrys.where().findAll();
    final byDate = <String, List<FoodEntry>>{};
    for (final e in allEntries) {
      (byDate[e.dateKey] ??= []).add(e);
    }

    final allLogs = await _isar.dailyLogs.where().findAll();
    final logsByDate = {for (final l in allLogs) l.dateKey: l};

    final allDates = {...byDate.keys, ...logsByDate.keys};

    // Collect (ref, data) pairs; flush in 400-op chunks (Firestore limit 500).
    final writes =
        <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];

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
        final firstTs = group.first.timestamp;
        final label = _mealLabel(firstTs);
        final timeStr = _fmtTime(firstTs);

        // Meal summary document.
        int mc = 0, mp = 0, mCarb = 0, mf = 0, mfib = 0;
        for (final e in group) {
          mc += e.calories;
          mp += e.proteinG;
          mCarb += e.carbsG;
          mf += e.fatG;
          mfib += e.fiberG;
        }
        writes.add((_dayMeals(dateKey).doc(mealNum.toString()), {
          'mealNumber': mealNum,
          'label': label,
          'time': timeStr,
          'calories': mc,
          'proteinG': mp,
          'carbsG': mCarb,
          'fatG': mf,
          'fiberG': mfib,
          'itemCount': group.length,
          'rawInputs': group
              .map((e) => e.rawInput)
              .toSet()
              .where((s) => s.isNotEmpty)
              .toList(),
        }));

        // Individual food entries under their meal.
        for (final e in group) {
          writes.add((_dayFoods(dateKey).doc(e.id.toString()),
              _foodEntryToMap(e,
                  mealNumber: mealNum,
                  mealLabel: label,
                  mealTime: timeStr)));
        }
      }
    }

    final customFoods = await _isar.customFoods.where().findAll();
    for (final c in customFoods) {
      writes.add((_customFoods().doc(c.id.toString()), _customFoodToMap(c)));
    }

    for (var i = 0; i < writes.length; i += 400) {
      final end = math.min(i + 400, writes.length);
      final batch = _fs.batch();
      for (var j = i; j < end; j++) {
        batch.set(writes[j].$1, writes[j].$2);
      }
      await batch.commit();
    }
  }

  /// Pull everything from Firestore into local Isar.
  /// Reads the current v4 structure; falls back to older layouts automatically.
  Future<void> pullAll() async {
    final pf = await _profileDoc().get();

    final allEntries = <int, FoodEntry>{};
    final allLogs = <DailyLog>[];

    // v4 structure: days/{dateKey}/foods/
    final dayDocs = await _daysCol().get();
    if (dayDocs.docs.isNotEmpty) {
      for (final dayDoc in dayDocs.docs) {
        allLogs.add(_dailyLogFromMap(dayDoc.data()));
        final items = await dayDoc.reference.collection('foods').get();
        for (final item in items.docs) {
          final e = _foodEntryFromMap(item.data());
          allEntries[e.id] = e;
        }
      }
    } else {
      // v3 legacy: foodEntries/{dateKey}/items/{id}  or  foodEntries/{id}
      final oldCol = _userDoc().collection('foodEntries');
      final oldDocs = await oldCol.get();
      for (final doc in oldDocs.docs) {
        final data = doc.data();
        if (data.containsKey('calories')) {
          final e = _foodEntryFromMap(data);
          allEntries.putIfAbsent(e.id, () => e);
        } else {
          final items = await doc.reference.collection('items').get();
          for (final item in items.docs) {
            final e = _foodEntryFromMap(item.data());
            allEntries.putIfAbsent(e.id, () => e);
          }
        }
      }
      final oldLogs = await _userDoc().collection('dailyLogs').get();
      for (final d in oldLogs.docs) {
        allLogs.add(_dailyLogFromMap(d.data()));
      }
    }

    final customFoodsSnap = await _customFoods().get();

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
      for (final d in customFoodsSnap.docs) {
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

  /// Restore a single day's food + activity from Firestore into local Isar.
  /// Tries v4 structure first, then falls back to legacy paths.
  Future<void> restoreDay(DateTime date) async {
    final dateKey = DailyLog.keyFor(date);

    final daySnap = await _dayDoc(dateKey).get();
    final foodsSnap = await _dayFoods(dateKey).get();

    var cloudEntries =
        foodsSnap.docs.map((d) => _foodEntryFromMap(d.data())).toList();
    DailyLog? cloudLog =
        daySnap.exists ? _dailyLogFromMap(daySnap.data()!) : null;

    // Fallback: v3 nested items
    if (cloudEntries.isEmpty) {
      final v3 = await _userDoc()
          .collection('foodEntries')
          .doc(dateKey)
          .collection('items')
          .get();
      if (v3.docs.isNotEmpty) {
        cloudEntries =
            v3.docs.map((d) => _foodEntryFromMap(d.data())).toList();
      } else {
        // Fallback: v1 flat list
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
      if (cloudLog != null) {
        await _isar.dailyLogs.put(cloudLog);
      }
    });
  }

  // --- Meal grouping --------------------------------------------------------

  /// Two entries belong to the same meal when the gap from the previous
  /// entry is ≤ 30 minutes.
  List<List<FoodEntry>> _groupIntoMeals(List<FoodEntry> entries) {
    if (entries.isEmpty) return const [];
    final sorted = List<FoodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final groups = <List<FoodEntry>>[];
    for (final e in sorted) {
      if (groups.isEmpty ||
          e.timestamp
                  .difference(groups.last.last.timestamp)
                  .inMinutes
                  .abs() >
              30) {
        groups.add([e]);
      } else {
        groups.last.add(e);
      }
    }
    return groups;
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
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${t.minute.toString().padLeft(2, '0')} $period';
  }

  // --- Mappers --------------------------------------------------------------

  /// Full profile with every onboarding field, organised into sections.
  Map<String, dynamic> _profileToMap(Profile p) => {
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
          'gymStartDate': p.gymStartDate?.toIso8601String(),
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
          'multivitamin': p.multivitamin,
          'otherNote': p.otherSupplementsNote,
        },
        'health': {
          'flags': p.healthFlags.map((f) => f.name).toList(),
        },
        'meta': {
          'createdAt': p.createdAt.toIso8601String(),
          'updatedAt': p.updatedAt.toIso8601String(),
        },
      };

  /// Reads from the v4 nested sections; falls back to flat keys for any
  /// field missing from an older backup document.
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

    // Helper: nested value ?? flat fallback
    dynamic nf(Map n, String nk, String fk) => n[nk] ?? m[fk];

    return Profile()
      ..id = 0
      ..displayName =
          (nf(personal, 'displayName', 'displayName') as String?) ?? ''
      ..age = (nf(personal, 'age', 'age') as num?)?.toInt() ?? 22
      ..gender = _enumFromName(
              Gender.values, nf(personal, 'gender', 'gender') as String?) ??
          Gender.male
      ..country =
          (nf(personal, 'country', 'country') as String?) ?? ''
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
      ..gymStartDate = DateTime.tryParse(
          (nf(goal, 'gymStartDate', 'gymStartDate') as String?) ?? '')
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
      ..restDays = ((nf(schedule, 'restDays', 'restDays') as List?) ?? [])
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
      ..multivitamin =
          (nf(supps, 'multivitamin', 'multivitamin') as bool?) ?? false
      ..otherSupplementsNote =
          (nf(supps, 'otherNote', 'otherSupplementsNote') as String?) ?? ''
      ..healthFlags =
          ((health['flags'] ?? m['healthFlags'] ?? []) as List)
              .map((e) => _enumFromName(HealthFlag.values, e as String?))
              .whereType<HealthFlag>()
              .toList()
      ..createdAt =
          DateTime.tryParse((meta['createdAt'] ?? m['createdAt'] ?? '') as String) ??
              DateTime.now()
      ..updatedAt =
          DateTime.tryParse((meta['updatedAt'] ?? m['updatedAt'] ?? '') as String) ??
              DateTime.now();
  }

  /// Day document: consumed totals, targets, activity, sleep, water.
  /// Flat log fields are preserved alongside the nested maps so that
  /// _dailyLogFromMap can reconstruct a DailyLog from this document
  /// without needing to know the nested structure.
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
    final baseTarget = profile?.effectiveCalorieTarget ?? 0;
    final wScale = (profile?.weightKg ?? 70) / 70.0;
    final bonus = (((walkKm - (profile?.walkingKmPerDay ?? 0)).clamp(0, 30) *
                50 *
                wScale) +
            ((runKm - ((profile?.runningKmPerWeek ?? 0) / 7.0))
                    .clamp(0, 50) *
                70 *
                wScale) +
            (cardioMin.clamp(0, 240) * 9.0 * wScale))
        .round();

    final waterEntryMaps = (log?.waterEntries ?? []).map((e) {
      final h = e.minutesOfDay ~/ 60;
      final min = e.minutesOfDay % 60;
      final p = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return {
        'time': '$h12:${min.toString().padLeft(2, '0')} $p',
        'minutesOfDay': e.minutesOfDay,
        'ml': e.ml,
      };
    }).toList();

    return {
      'dateKey': dateKey,

      // ── Readable nested summary ──────────────────────────────────────────
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
        'caloriesBase': baseTarget,
        'caloriesAdjusted': baseTarget + bonus,
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
      'water': {
        'totalMl': log?.waterMl ?? 0,
        'entries': waterEntryMaps,
      },

      // ── Flat fields for DailyLog reconstruction ──────────────────────────
      'waterMl': log?.waterMl ?? 0,
      'waterEntries': waterEntryMaps,
      'steps': log?.steps,
      'heartRateAvg': log?.heartRateAvg,
      'sleepMinutes': log?.sleepMinutes,
      'walkingKmToday': walkKm,
      'runningKmToday': runKm,
      'otherCardioMinutes': cardioMin,
      'activityNote': log?.activityNote,
      'updatedAt': (log?.updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Food entry with meal context and organised nutrition block.
  Map<String, dynamic> _foodEntryToMap(
    FoodEntry e, {
    int mealNumber = 1,
    String mealLabel = '',
    String mealTime = '',
  }) =>
      {
        'id': e.id,
        'meal': {
          'number': mealNumber,
          'label': mealLabel,
          'time': mealTime,
        },
        'food': {
          'description': e.description,
          'rawInput': e.rawInput,
          'quantity': e.quantity,
          'unit': e.unit,
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
          'timestamp': e.timestamp.toIso8601String(),
          'dateKey': e.dateKey,
        },
      };

  /// Reads from v4 nested structure; falls back to flat keys for any field
  /// that was written by an older version of the app.
  FoodEntry _foodEntryFromMap(Map<String, dynamic> m) {
    final food = (m['food'] as Map<String, dynamic>?) ?? const {};
    final nutrition = (m['nutrition'] as Map<String, dynamic>?) ?? const {};
    final meta = (m['meta'] as Map<String, dynamic>?) ?? const {};

    return FoodEntry()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..timestamp = DateTime.tryParse(
              (meta['timestamp'] ?? m['timestamp'] ?? '') as String) ??
          DateTime.now()
      ..dateKey = (meta['dateKey'] ?? m['dateKey'] ?? '') as String
      ..rawInput = (food['rawInput'] ?? m['rawInput'] ?? '') as String
      ..description =
          (food['description'] ?? m['description'] ?? '') as String
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
              FoodSource.values,
              (meta['source'] ?? m['source']) as String?) ??
          FoodSource.aiText
      ..confidence = _enumFromName(EstimateConfidence.values,
              (meta['confidence'] ?? m['confidence']) as String?) ??
          EstimateConfidence.medium
      ..caloriesLow =
          ((nutrition['caloriesLow'] ?? m['caloriesLow']) as num?)?.toInt()
      ..caloriesHigh =
          ((nutrition['caloriesHigh'] ?? m['caloriesHigh']) as num?)?.toInt()
      ..isFavorite =
          (meta['isFavorite'] ?? m['isFavorite'] ?? false) as bool;
  }

  /// Works for both legacy `dailyLogs/{dateKey}` documents and the new
  /// `days/{dateKey}` documents — both store the log fields flat.
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
      ..updatedAt =
          DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now();
  }

  Map<String, dynamic> _customFoodToMap(CustomFood c) => {
        'id': c.id,
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
        'createdAt': c.createdAt.toIso8601String(),
      };

  CustomFood _customFoodFromMap(Map<String, dynamic> m) {
    return CustomFood()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..name = (m['name'] as String?) ?? ''
      ..servingSizeG = (m['servingSizeG'] as num?)?.toDouble() ?? 100
      ..servingDescription =
          (m['servingDescription'] as String?) ?? '1 serving'
      ..caloriesPerServing =
          (m['caloriesPerServing'] as num?)?.toInt() ?? 0
      ..proteinGPerServing =
          (m['proteinGPerServing'] as num?)?.toInt() ?? 0
      ..carbsGPerServing = (m['carbsGPerServing'] as num?)?.toInt() ?? 0
      ..fatGPerServing = (m['fatGPerServing'] as num?)?.toInt() ?? 0
      ..fiberGPerServing = (m['fiberGPerServing'] as num?)?.toInt() ?? 0
      ..sodiumMgPerServing =
          (m['sodiumMgPerServing'] as num?)?.toInt() ?? 0
      ..ingredients = m['ingredients'] as String?
      ..createdAt =
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now();
  }

  T? _enumFromName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
