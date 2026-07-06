import 'dart:convert';

import 'package:http/http.dart' as http;

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
          return _ExEntry(
            norm: _norm(map['name'] as String? ?? ''),
            urls: imgs.map((p) => '$_base/exercises/$p').toList(),
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

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ExEntry {
  final String norm;
  final List<String> urls;
  const _ExEntry({required this.norm, required this.urls});
}
