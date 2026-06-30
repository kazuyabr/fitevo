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

/// Firestore layout (as of v3):
///
/// users/{uid}
/// ├── email, displayName, uid, lastBackupAt
/// ├── profile/main          ← all targets & body stats
/// ├── days/{dateKey}        ← one document per calendar day
/// │   ├── consumed: {calories, proteinG, carbsG, fatG, fiberG, sodiumMg, items}
/// │   ├── target:   {calories, proteinG, carbsG, fatG, fiberG, waterMl}
/// │   ├── waterMl, walkingKmToday, runningKmToday, otherCardioMinutes,
/// │   │   steps, sleepMinutes, heartRateAvg, activityNote, waterEntries
/// │   └── foods/            ← sub-collection: one doc per food entry
/// │       └── {isarId}: {description, calories, proteinG, carbsG, …}
/// └── customFoods/{id}
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

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');
    return _fs.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _daysCol() =>
      _userDoc().collection('days');
  DocumentReference<Map<String, dynamic>> _dayDoc(String dateKey) =>
      _daysCol().doc(dateKey);
  CollectionReference<Map<String, dynamic>> _dayFoods(String dateKey) =>
      _dayDoc(dateKey).collection('foods');

  DocumentReference<Map<String, dynamic>> _profileDoc() =>
      _userDoc().collection('profile').doc('main');
  CollectionReference<Map<String, dynamic>> _customFoods() =>
      _userDoc().collection('customFoods');

  Future<bool> cloudHasData() async {
    final p = await _profileDoc().get();
    if (p.exists) return true;
    final d = await _daysCol().limit(1).get();
    if (d.docs.isNotEmpty) return true;
    // Legacy collection check
    final f = await _userDoc().collection('foodEntries').limit(1).get();
    return f.docs.isNotEmpty;
  }

  Future<bool> localHasData() async {
    final p = await _isar.profiles.count();
    if (p > 0) return true;
    final f = await _isar.foodEntrys.count();
    return f > 0;
  }

  /// Push everything in Isar to Firestore. Groups food entries under
  /// their date so the console shows one folder per day.
  Future<void> pushAll() async {
    final user = _auth.currentUser;
    final profile = await _isar.profiles.where().findFirst();

    // Store user identity so it's visible in the console.
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

    // Collect all (ref, data) pairs then flush in 400-op batches
    // (Firestore hard limit is 500 per batch).
    final writes =
        <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];

    for (final dateKey in allDates) {
      final entries = byDate[dateKey] ?? [];
      final log = logsByDate[dateKey];
      final totals =
          NutritionRepo.sumEntries(entries, waterMl: log?.waterMl ?? 0);
      writes.add((_dayDoc(dateKey), _dayToMap(dateKey, log, totals, profile)));
      for (final e in entries) {
        writes.add(
            (_dayFoods(dateKey).doc(e.id.toString()), _foodEntryToMap(e)));
      }
    }

    final foods = await _isar.customFoods.where().findAll();
    for (final c in foods) {
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
  /// Reads new `days/` structure first; falls back to legacy collections.
  Future<void> pullAll() async {
    final pf = await _profileDoc().get();

    final allEntries = <int, FoodEntry>{};
    final allLogs = <DailyLog>[];

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
      // Legacy: foodEntries/{dateKey}/items/{id}  OR  foodEntries/{id}
      final oldCol = _userDoc().collection('foodEntries');
      final oldDocs = await oldCol.get();
      for (final doc in oldDocs.docs) {
        final data = doc.data();
        if (data.containsKey('calories')) {
          // Oldest flat structure
          final e = _foodEntryFromMap(data);
          allEntries.putIfAbsent(e.id, () => e);
        } else {
          // v2 nested structure
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

    final customFoods = await _customFoods().get();

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
      for (final d in customFoods.docs) {
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

  /// Restore a single day from Firestore into local Isar.
  /// Tries new structure first, then legacy structures.
  Future<void> restoreDay(DateTime date) async {
    final dateKey = DailyLog.keyFor(date);

    final daySnap = await _dayDoc(dateKey).get();
    final foodsSnap = await _dayFoods(dateKey).get();

    var cloudEntries =
        foodsSnap.docs.map((d) => _foodEntryFromMap(d.data())).toList();
    DailyLog? cloudLog =
        daySnap.exists ? _dailyLogFromMap(daySnap.data()!) : null;

    // Fallback: v2 nested
    if (cloudEntries.isEmpty) {
      final v2 = await _userDoc()
          .collection('foodEntries')
          .doc(dateKey)
          .collection('items')
          .get();
      if (v2.docs.isNotEmpty) {
        cloudEntries = v2.docs.map((d) => _foodEntryFromMap(d.data())).toList();
      } else {
        // Fallback: v1 flat
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
      final oldLog =
          await _userDoc().collection('dailyLogs').doc(dateKey).get();
      if (oldLog.exists) cloudLog = _dailyLogFromMap(oldLog.data()!);
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

  // --- mappers -----------------------------------------------------------

  /// Day document: consumed totals + profile targets snapshot + log data.
  /// The log fields (waterMl, walkingKmToday, etc.) are at the top level
  /// so _dailyLogFromMap can read this document directly.
  Map<String, dynamic> _dayToMap(
    String dateKey,
    DailyLog? log,
    DailyTotals totals,
    Profile? profile,
  ) =>
      {
        'dateKey': dateKey,
        'consumed': {
          'calories': totals.calories,
          'proteinG': totals.proteinG,
          'carbsG': totals.carbsG,
          'fatG': totals.fatG,
          'fiberG': totals.fiberG,
          'sodiumMg': totals.sodiumMg,
          'items': totals.entryCount,
        },
        'target': {
          'calories': profile?.effectiveCalorieTarget,
          'proteinG': profile?.effectiveProteinTarget,
          'carbsG': profile?.effectiveCarbTarget,
          'fatG': profile?.effectiveFatTarget,
          'fiberG': profile?.effectiveFiberTarget,
          'waterMl': profile?.effectiveWaterTarget,
        },
        // Log fields — also readable by _dailyLogFromMap
        'waterMl': log?.waterMl ?? 0,
        'waterEntries': (log?.waterEntries ?? [])
            .map((e) => {'minutesOfDay': e.minutesOfDay, 'ml': e.ml})
            .toList(),
        'steps': log?.steps,
        'heartRateAvg': log?.heartRateAvg,
        'sleepMinutes': log?.sleepMinutes,
        'walkingKmToday': log?.walkingKmToday ?? 0,
        'runningKmToday': log?.runningKmToday ?? 0,
        'otherCardioMinutes': log?.otherCardioMinutes ?? 0,
        'activityNote': log?.activityNote,
        'updatedAt': (log?.updatedAt ?? DateTime.now()).toIso8601String(),
      };

  Map<String, dynamic> _profileToMap(Profile p) => {
        'displayName': p.displayName,
        'age': p.age,
        'gender': p.gender.name,
        'heightCm': p.heightCm,
        'weightKg': p.weightKg,
        'activityLevel': p.activityLevel.name,
        'goal': p.goal.name,
        'trainingDaysPerWeek': p.trainingDaysPerWeek,
        'bmr': p.bmr,
        'tdee': p.tdee,
        'calorieTarget': p.calorieTarget,
        'proteinTargetG': p.proteinTargetG,
        'carbTargetG': p.carbTargetG,
        'fatTargetG': p.fatTargetG,
        'fiberTargetG': p.fiberTargetG,
        'waterTargetMl': p.waterTargetMl,
        'bmi': p.bmi,
        'calorieOverride': p.calorieOverride,
        'proteinOverride': p.proteinOverride,
        'carbOverride': p.carbOverride,
        'fatOverride': p.fatOverride,
        'fiberOverride': p.fiberOverride,
        'waterOverride': p.waterOverride,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
      };

  Profile _profileFromMap(Map<String, dynamic> m) {
    return Profile()
      ..id = 0
      ..displayName = (m['displayName'] as String?) ?? ''
      ..age = (m['age'] as num?)?.toInt() ?? 22
      ..gender =
          _enumFromName(Gender.values, m['gender'] as String?) ?? Gender.male
      ..heightCm = (m['heightCm'] as num?)?.toDouble() ?? 170
      ..weightKg = (m['weightKg'] as num?)?.toDouble() ?? 70
      ..activityLevel =
          _enumFromName(ActivityLevel.values, m['activityLevel'] as String?) ??
              ActivityLevel.moderate
      ..goal = _enumFromName(FitnessGoal.values, m['goal'] as String?) ??
          FitnessGoal.generalFitness
      ..trainingDaysPerWeek = (m['trainingDaysPerWeek'] as num?)?.toInt() ?? 3
      ..bmr = (m['bmr'] as num?)?.toDouble() ?? 0
      ..tdee = (m['tdee'] as num?)?.toDouble() ?? 0
      ..calorieTarget = (m['calorieTarget'] as num?)?.toInt() ?? 2000
      ..proteinTargetG = (m['proteinTargetG'] as num?)?.toInt() ?? 120
      ..carbTargetG = (m['carbTargetG'] as num?)?.toInt() ?? 230
      ..fatTargetG = (m['fatTargetG'] as num?)?.toInt() ?? 65
      ..fiberTargetG = (m['fiberTargetG'] as num?)?.toInt() ?? 28
      ..waterTargetMl = (m['waterTargetMl'] as num?)?.toInt() ?? 2500
      ..bmi = (m['bmi'] as num?)?.toDouble() ?? 22
      ..calorieOverride = (m['calorieOverride'] as num?)?.toInt()
      ..proteinOverride = (m['proteinOverride'] as num?)?.toInt()
      ..carbOverride = (m['carbOverride'] as num?)?.toInt()
      ..fatOverride = (m['fatOverride'] as num?)?.toInt()
      ..fiberOverride = (m['fiberOverride'] as num?)?.toInt()
      ..waterOverride = (m['waterOverride'] as num?)?.toInt()
      ..createdAt =
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now()
      ..updatedAt =
          DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now();
  }

  Map<String, dynamic> _foodEntryToMap(FoodEntry e) => {
        'id': e.id,
        'timestamp': e.timestamp.toIso8601String(),
        'dateKey': e.dateKey,
        'rawInput': e.rawInput,
        'description': e.description,
        'quantity': e.quantity,
        'unit': e.unit,
        'calories': e.calories,
        'proteinG': e.proteinG,
        'carbsG': e.carbsG,
        'fatG': e.fatG,
        'fiberG': e.fiberG,
        'sodiumMg': e.sodiumMg,
        'source': e.source.name,
        'confidence': e.confidence.name,
        'caloriesLow': e.caloriesLow,
        'caloriesHigh': e.caloriesHigh,
        'isFavorite': e.isFavorite,
      };

  FoodEntry _foodEntryFromMap(Map<String, dynamic> m) {
    return FoodEntry()
      ..id = (m['id'] as num?)?.toInt() ?? Isar.autoIncrement
      ..timestamp =
          DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now()
      ..dateKey = (m['dateKey'] as String?) ?? ''
      ..rawInput = (m['rawInput'] as String?) ?? ''
      ..description = (m['description'] as String?) ?? ''
      ..quantity = (m['quantity'] as String?) ?? ''
      ..unit = (m['unit'] as String?) ?? ''
      ..calories = (m['calories'] as num?)?.toInt() ?? 0
      ..proteinG = (m['proteinG'] as num?)?.toInt() ?? 0
      ..carbsG = (m['carbsG'] as num?)?.toInt() ?? 0
      ..fatG = (m['fatG'] as num?)?.toInt() ?? 0
      ..fiberG = (m['fiberG'] as num?)?.toInt() ?? 0
      ..sodiumMg = (m['sodiumMg'] as num?)?.toInt() ?? 0
      ..source =
          _enumFromName(FoodSource.values, m['source'] as String?) ??
              FoodSource.aiText
      ..confidence =
          _enumFromName(EstimateConfidence.values, m['confidence'] as String?) ??
              EstimateConfidence.medium
      ..caloriesLow = (m['caloriesLow'] as num?)?.toInt()
      ..caloriesHigh = (m['caloriesHigh'] as num?)?.toInt()
      ..isFavorite = (m['isFavorite'] as bool?) ?? false;
  }

  /// Reads a DailyLog from either an old `dailyLogs/{dateKey}` document
  /// or from the new `days/{dateKey}` document — field names are identical.
  DailyLog _dailyLogFromMap(Map<String, dynamic> m) {
    final weRaw = m['waterEntries'];
    final waterEntries = <WaterEntry>[];
    if (weRaw is List) {
      for (final item in weRaw) {
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
      ..servingDescription = (m['servingDescription'] as String?) ?? '1 serving'
      ..caloriesPerServing = (m['caloriesPerServing'] as num?)?.toInt() ?? 0
      ..proteinGPerServing = (m['proteinGPerServing'] as num?)?.toInt() ?? 0
      ..carbsGPerServing = (m['carbsGPerServing'] as num?)?.toInt() ?? 0
      ..fatGPerServing = (m['fatGPerServing'] as num?)?.toInt() ?? 0
      ..fiberGPerServing = (m['fiberGPerServing'] as num?)?.toInt() ?? 0
      ..sodiumMgPerServing = (m['sodiumMgPerServing'] as num?)?.toInt() ?? 0
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
