import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A model entry from the models.dev catalog.
class CatalogModel {
  final String id;
  final String name;
  final bool attachment; // supports image input (vision)
  final bool reasoning;

  const CatalogModel({
    required this.id,
    required this.name,
    this.attachment = false,
    this.reasoning = false,
  });
}

/// A provider entry from the models.dev catalog, reduced to what the app
/// can actually talk to: providers exposing an OpenAI-compatible endpoint.
class CatalogProvider {
  final String id;
  final String name;

  /// OpenAI-compatible base URL (e.g. `https://api.openai.com/v1`).
  final String api;
  final String doc;
  final List<CatalogModel> models;

  const CatalogProvider({
    required this.id,
    required this.name,
    required this.api,
    this.doc = '',
    this.models = const [],
  });
}

/// Fetches and caches the models.dev catalog (https://models.dev/api.json).
///
/// Only providers the app can drive through the generic OpenAI-compatible
/// client are surfaced: providers with an `api` base URL in the catalog,
/// plus a few well-known native providers whose OpenAI-compatible endpoints
/// are stable.
class ModelCatalogService {
  ModelCatalogService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _url = 'https://models.dev/api.json';
  static const _ttl = Duration(hours: 24);

  /// OpenAI-compatible endpoints for well-known providers whose catalog
  /// entry does not carry an `api` field.
  static const Map<String, String> _knownBaseUrls = {
    'openai': 'https://api.openai.com/v1',
    'anthropic': 'https://api.anthropic.com/v1',
    'google': 'https://generativelanguage.googleapis.com/v1beta/openai',
    'groq': 'https://api.groq.com/openai/v1',
    'mistral': 'https://api.mistral.ai/v1',
    'xai': 'https://api.x.ai/v1',
    'cerebras': 'https://api.cerebras.ai/v1',
  };

  /// Providers shown first in the picker.
  static const List<String> _popularOrder = [
    'openai',
    'anthropic',
    'google',
    'groq',
    'openrouter',
    'deepseek',
    'mistral',
    'xai',
    'cerebras',
    'together',
    'fireworks',
    'perplexity',
  ];

  List<CatalogProvider>? _memory;

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/models_dev_catalog.json');
  }

  /// Returns the provider list. Order of sources: memory → fresh disk cache
  /// → network (which updates the disk cache). On network failure a stale
  /// disk cache is still served; with no cache at all the error is rethrown
  /// so the UI can offer manual entry.
  Future<List<CatalogProvider>> load({bool force = false}) async {
    if (!force && _memory != null) return _memory!;

    File? file;
    try {
      file = await _cacheFile();
      if (file.existsSync()) {
        final age = DateTime.now()
            .difference(file.lastModifiedSync())
            .abs();
        if (!force && age < _ttl) {
          final parsed = _parse(file.readAsStringSync());
          if (parsed.isNotEmpty) {
            _memory = parsed;
            return parsed;
          }
        }
      }
    } catch (_) {
      // Cache read failed — fall through to the network.
    }

    try {
      final res = await _client
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('models.dev returned ${res.statusCode}');
      }
      final parsed = _parse(res.body);
      if (parsed.isEmpty) {
        throw const FormatException('models.dev catalog was empty');
      }
      _memory = parsed;
      try {
        await file?.writeAsString(res.body, flush: true);
      } catch (_) {
        // Cache write is best-effort.
      }
      return parsed;
    } catch (e) {
      // Network failed — serve a stale cache if we have one.
      try {
        if (file != null && file.existsSync()) {
          final parsed = _parse(file.readAsStringSync());
          if (parsed.isNotEmpty) {
            _memory = parsed;
            return parsed;
          }
        }
      } catch (_) {
        // Ignore and rethrow the original error.
      }
      rethrow;
    }
  }

  List<CatalogProvider> _parse(String body) {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) return const [];

    final providers = <CatalogProvider>[];
    root.forEach((id, raw) {
      if (raw is! Map) return;
      final m = Map<String, dynamic>.from(raw);
      final api = (m['api'] as String?)?.trim() ?? '';
      final resolvedApi =
          api.isNotEmpty ? api : (_knownBaseUrls[id] ?? '');
      if (resolvedApi.isEmpty) return; // protocol we can't speak

      final modelsRaw = m['models'];
      if (modelsRaw is! Map || modelsRaw.isEmpty) return;

      final models = <CatalogModel>[];
      modelsRaw.forEach((mid, mraw) {
        if (mraw is! Map) return;
        final mm = Map<String, dynamic>.from(mraw);
        if (mm['deprecated'] == true) return;
        models.add(CatalogModel(
          id: (mm['id'] as String?) ?? '$mid',
          name: (mm['name'] as String?) ?? '$mid',
          attachment: mm['attachment'] == true,
          reasoning: mm['reasoning'] == true,
        ));
      });
      if (models.isEmpty) return;
      models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      providers.add(CatalogProvider(
        id: id,
        name: (m['name'] as String?) ?? id,
        api: resolvedApi,
        doc: (m['doc'] as String?) ?? '',
        models: models,
      ));
    });

    int rank(CatalogProvider p) {
      final i = _popularOrder.indexOf(p.id);
      return i < 0 ? _popularOrder.length : i;
    }

    providers.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return providers;
  }
}
