import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/enums.dart';

/// A browsable exercise from the free-exercise-db catalog — name, the muscle
/// groups it trains (mapped to the app's [MuscleGroup]s), equipment, and CDN
/// image URLs. Used to let the user find an exercise by sight when they don't
/// know its name.
class CatalogExercise {
  final String name;
  final List<MuscleGroup> muscles;
  final Equipment equipment;
  final List<String> imageUrls;
  final List<String> instructions;
  const CatalogExercise({
    required this.name,
    required this.muscles,
    required this.equipment,
    required this.imageUrls,
    this.instructions = const [],
  });
}

/// Fetches exercise images from the yuhonas/free-exercise-db GitHub CDN.
///
/// The index JSON (~800 exercises) is loaded once per app session and
/// kept in memory. Individual results are cached so repeated calls for
/// the same exercise are instant.
class ExerciseImageService {
  static const _base =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main';

  List<_ExEntry>? _index;
  final Map<String, List<String>> _cache = {};

  /// Returns up to [max] CDN image URLs for the given exercise name.
  /// Falls back to an empty list when no match is found or the network
  /// is unavailable. Results are cached for the session lifetime.
  ///
  /// The cache stores the FULL URL list per exercise; [max] is applied on
  /// read so a `firstImageFor` call (max=1) doesn't poison the cache for
  /// a later detail-page call (max=2).
  Future<List<String>> imagesFor(String exerciseName, {int max = 2}) async {
    final key = _norm(exerciseName);
    final cached = _cache[key];
    if (cached != null) return cached.take(max).toList();
    await _loadIndex();
    final all = _matchImages(key);
    _cache[key] = all;
    return all.take(max).toList();
  }

  Future<String?> firstImageFor(String exerciseName) async {
    final list = await imagesFor(exerciseName, max: 1);
    return list.isNotEmpty ? list.first : null;
  }

  Future<void> _loadIndex() async {
    if (_index != null) return;
    try {
      final resp = await http
          .get(Uri.parse('$_base/dist/exercises.json'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final raw = jsonDecode(resp.body) as List;
        _index = raw.map((m) {
          final map = m as Map<String, dynamic>;
          final imgs = (map['images'] as List?)?.cast<String>() ?? const [];
          final name = map['name'] as String? ?? '';
          final primary =
              (map['primaryMuscles'] as List?)?.cast<String>() ?? const [];
          final secondary =
              (map['secondaryMuscles'] as List?)?.cast<String>() ?? const [];
          final muscles = <MuscleGroup>[];
          for (final raw in [...primary, ...secondary]) {
            final mg = _mapMuscle(raw);
            if (mg != null && !muscles.contains(mg)) muscles.add(mg);
          }
          return _ExEntry(
            name: name,
            norm: _norm(name),
            urls: imgs.map((p) => '$_base/exercises/$p').toList(),
            muscles: muscles,
            equipment: _mapEquipment(map['equipment'] as String?),
            instructions:
                (map['instructions'] as List?)?.cast<String>() ?? const [],
          );
        }).toList();
      } else {
        _index = const [];
      }
    } catch (_) {
      _index = const [];
    }
  }

  List<String> _matchImages(String key) {
    final idx = _index;
    if (idx == null || idx.isEmpty) return const [];

    // 1. Exact match.
    for (final e in idx) {
      if (e.norm == key) return e.urls;
    }

    // 2. One string fully contains the other.
    for (final e in idx) {
      if (e.norm.contains(key) || key.contains(e.norm)) return e.urls;
    }

    // 3. Best word-overlap score (require at least 2 meaningful words shared).
    final words = key.split(' ').where((w) => w.length > 3).toSet();
    _ExEntry? best;
    int bestScore = 1;
    for (final e in idx) {
      final eWords = e.norm.split(' ').toSet();
      final score = words.intersection(eWords).length;
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best?.urls ?? const [];
  }

  /// The full browsable catalog (loads the index on first use). Only
  /// exercises that have images are included. Empty when the network is
  /// unavailable — callers fall back to the seeded library.
  Future<List<CatalogExercise>> catalog() async {
    await _loadIndex();
    final idx = _index;
    if (idx == null) return const [];
    final out = <CatalogExercise>[];
    for (final e in idx) {
      if (e.name.isEmpty || e.urls.isEmpty) continue;
      out.add(CatalogExercise(
        name: e.name,
        muscles: e.muscles,
        equipment: e.equipment,
        imageUrls: e.urls,
        instructions: e.instructions,
      ));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static MuscleGroup? _mapMuscle(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'chest':
        return MuscleGroup.chest;
      case 'shoulders':
        return MuscleGroup.shoulders;
      case 'triceps':
        return MuscleGroup.triceps;
      case 'biceps':
        return MuscleGroup.biceps;
      case 'forearms':
        return MuscleGroup.forearms;
      case 'lats':
      case 'middle back':
      case 'lower back':
      case 'traps':
      case 'neck':
        return MuscleGroup.back;
      case 'abdominals':
      case 'obliques':
        return MuscleGroup.core;
      case 'quadriceps':
        return MuscleGroup.quads;
      case 'hamstrings':
        return MuscleGroup.hamstrings;
      case 'glutes':
      case 'adductors':
      case 'abductors':
        return MuscleGroup.glutes;
      case 'calves':
        return MuscleGroup.calves;
      case 'cardiovascular':
        return MuscleGroup.cardio;
      default:
        return null;
    }
  }

  static Equipment _mapEquipment(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'barbell':
      case 'e-z curl bar':
        return Equipment.barbell;
      case 'dumbbell':
        return Equipment.dumbbell;
      case 'cable':
        return Equipment.cable;
      case 'machine':
        return Equipment.machine;
      case 'body only':
        return Equipment.bodyweight;
      case 'kettlebells':
        return Equipment.kettlebell;
      case 'bands':
        return Equipment.band;
      default:
        return Equipment.other;
    }
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ExEntry {
  final String name;
  final String norm;
  final List<String> urls;
  final List<MuscleGroup> muscles;
  final Equipment equipment;
  final List<String> instructions;
  const _ExEntry({
    required this.name,
    required this.norm,
    required this.urls,
    required this.muscles,
    required this.equipment,
    required this.instructions,
  });
}
