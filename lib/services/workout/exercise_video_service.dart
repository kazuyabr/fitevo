import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resolves a playable video URL for an exercise. Two tiers:
///   1. Curated Pexels stock CDN clips (instant, high quality) for the
///      handful of exercises we've mapped by hand.
///   2. YouTube search + stream extraction via `youtube_explode_dart` for
///      everything else — gives us in-app coverage for any exercise
///      without manual curation.
///
/// Stream URLs from YouTube expire after a few hours, so results are
/// cached in memory and re-fetched when they age out.
class ExerciseVideoService {
  /// Exercise-name (normalized) → Pexels CDN URL. Fuzzy-matched.
  static const Map<String, String> _pexels = {
    'cable fly':
        'https://videos.pexels.com/video-files/31105899/13291065_1920_1080_30fps.mp4',
    'cable chest fly':
        'https://videos.pexels.com/video-files/31105899/13291065_1920_1080_30fps.mp4',
    'bench press':
        'https://videos.pexels.com/video-files/5320001/5320001-uhd_2560_1440_25fps.mp4',
    'dumbbell bench press':
        'https://videos.pexels.com/video-files/5320001/5320001-uhd_2560_1440_25fps.mp4',
    'barbell bench press':
        'https://videos.pexels.com/video-files/5320001/5320001-uhd_2560_1440_25fps.mp4',
  };

  // Cache: exercise name (normalized) → (resolved URL, fetched at).
  // YouTube stream URLs expire, so we re-fetch after 1 hour.
  final Map<String, _CachedUrl> _cache = {};
  static const _ttl = Duration(hours: 1);

  /// Returns a curated Pexels URL for [exerciseName] or `null`. Used by
  /// the image/video toggle in `_FramesRow` (which needs a synchronous
  /// answer — it doesn't want to wait on a network search).
  String? urlFor(String exerciseName) => _lookup(exerciseName, _pexels);

  /// Resolves a playable video URL for [exerciseName]:
  ///   1. Curated Pexels URL if we have one → returned immediately.
  ///   2. Cached YouTube result if fresh.
  ///   3. Live search + stream extraction from YouTube.
  ///
  /// Returns `null` when nothing works (offline / YouTube blocked etc.).
  Future<String?> resolveStreamUrl(String exerciseName) async {
    final pexels = urlFor(exerciseName);
    if (pexels != null) return pexels;

    final key = _norm(exerciseName);
    final cached = _cache[key];
    if (cached != null && !cached.isStale) return cached.url;

    final yt = YoutubeExplode();
    try {
      final results =
          await yt.search.search('$exerciseName how to proper form technique');
      if (results.isEmpty) return null;
      final videoId = results.first.id;
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      // Muxed streams contain video+audio in one file — perfect for
      // Flutter's video_player which can't merge separate tracks.
      final muxed = manifest.muxed.toList();
      if (muxed.isEmpty) return null;
      final stream = muxed.reduce(
          (a, b) => a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond
              ? a
              : b);
      final url = stream.url.toString();
      _cache[key] = _CachedUrl(url, DateTime.now());
      return url;
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }

  static String? _lookup(String name, Map<String, String> map) {
    final key = _norm(name);
    if (map.containsKey(key)) return map[key];
    for (final entry in map.entries) {
      if (entry.key.contains(key) || key.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _CachedUrl {
  final String url;
  final DateTime fetchedAt;
  const _CachedUrl(this.url, this.fetchedAt);
  bool get isStale =>
      DateTime.now().difference(fetchedAt) >
      ExerciseVideoService._ttl;
}
