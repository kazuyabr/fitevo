import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/app_settings.dart';
import 'ai_prompts.dart';

/// Fetches the "training package" (system prompts / persona / context) from
/// the AI proxy and keeps [AiTraining] up to date.
///
/// The proxy is the single source of truth for the trainer's personality:
/// even when the user runs inference on their own provider (OpenAI,
/// OpenRouter, Groq, ...), the app calls `GET {proxyUrl}/training` and
/// injects the returned prompts, so the model answers with the same
/// personality and knowledge everywhere.
///
/// Endpoint contract:
///   GET {baseUrl}/training
///   200 → { "version": 1, "prompts": { "coachPersona": "...", ... } }
///   Any non-200 / network error → keep the cached package (or the bundled
///   defaults from [AiPrompts]).
class TrainingService {
  TrainingService({
    required AppSettings settings,
    required String proxyUrl,
    http.Client? client,
  })  : _settings = settings,
        _proxyUrl = proxyUrl,
        _client = client ?? http.Client();

  final AppSettings _settings;
  final String _proxyUrl;
  final http.Client _client;

  static const _ttl = Duration(hours: 24);

  final AiTraining _training = AiTraining.defaults();

  /// The effective prompts. Services hold this instance and always read the
  /// latest values, so background refreshes apply without a rebuild.
  AiTraining get current => _training;

  bool _refreshing = false;

  /// Loads cached overrides (if any) and refreshes from the proxy when the
  /// cache is stale or [force] is true. Safe to call repeatedly.
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (_proxyUrl.isEmpty) return;

      // 1) Cached package first — instant and offline-friendly.
      final cached = _settings.aiTrainingJson;
      if (cached.isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is Map<String, dynamic>) {
            _training.applyOverrides(
              Map<String, dynamic>.from(
                  decoded['prompts'] as Map? ?? const {}),
              version:
                  decoded['version'] is int ? decoded['version'] as int : 0,
            );
          }
        } catch (_) {
          // Corrupt cache — ignore and fall through to defaults/network.
        }
      }

      final age = DateTime.now().millisecondsSinceEpoch -
          _settings.aiTrainingFetchedAt;
      if (!force &&
          _settings.aiTrainingFetchedAt > 0 &&
          age < _ttl.inMilliseconds) {
        return; // Fresh enough — no network needed.
      }

      // 2) Network refresh.
      final res = await _client
          .get(Uri.parse('$_proxyUrl/training'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      _training.applyOverrides(
        Map<String, dynamic>.from(decoded['prompts'] as Map? ?? const {}),
        version: decoded['version'] is int ? decoded['version'] as int : 0,
      );
      await _settings.setAiTraining(
        jsonEncode(_training.toJson()),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Network/parse failure — keep cache/defaults silently.
    } finally {
      _refreshing = false;
    }
  }
}
