import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores frozen per-day calorie/macro targets in SharedPreferences.
/// Written once from Firebase on cloud sync; after that the app shows
/// the snapshot instead of recalculating from the current profile.
class TargetSnapshotStore {
  static const _prefix = 'target_snap_';

  static String _key(String dateKey) => '$_prefix$dateKey';

  static Future<void> save({
    required String dateKey,
    required int calorieTarget,
    required int proteinTarget,
    required int carbTarget,
    required int fatTarget,
    int? fiberTarget,
    int? waterTarget,
    int? sodiumTarget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(dateKey),
      jsonEncode({
        'cal': calorieTarget,
        'pro': proteinTarget,
        'carb': carbTarget,
        'fat': fatTarget,
        'fib': ?fiberTarget,
        'water': ?waterTarget,
        'sodium': ?sodiumTarget,
      }),
    );
  }

  static Future<TargetSnapshot?> load(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(dateKey));
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return TargetSnapshot(
        calorieTarget: (m['cal'] as num).toInt(),
        proteinTarget: (m['pro'] as num).toInt(),
        carbTarget: (m['carb'] as num).toInt(),
        fatTarget: (m['fat'] as num).toInt(),
        fiberTarget: (m['fib'] as num?)?.toInt(),
        waterTarget: (m['water'] as num?)?.toInt(),
        sodiumTarget: (m['sodium'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> has(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key(dateKey));
  }
}

class TargetSnapshot {
  const TargetSnapshot({
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbTarget,
    required this.fatTarget,
    this.fiberTarget,
    this.waterTarget,
    this.sodiumTarget,
  });

  final int calorieTarget;
  final int proteinTarget;
  final int carbTarget;
  final int fatTarget;
  final int? fiberTarget;
  final int? waterTarget;
  final int? sodiumTarget;
}
