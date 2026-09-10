import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../data/models/enums.dart';
import 'ai_prompts.dart';
import 'ai_service.dart';

/// Generic client for any provider that speaks the OpenAI Chat Completions
/// wire format (`POST {baseUrl}/chat/completions`).
///
/// This is what makes the app provider-agnostic: OpenAI, Groq, OpenRouter,
/// DeepSeek, Mistral, xAI, Together, Fireworks, Ollama, LM Studio and any
/// other OpenAI-compatible endpoint work through this single class. The
/// provider catalog (models.dev) supplies the base URL and model ids.
///
/// Prompts come from [AiTraining], so the trainer persona stays identical
/// no matter which provider the user picks — including prompt overrides
/// fetched from the AI proxy.
class OpenAiCompatAiService implements AiService {
  OpenAiCompatAiService({
    required String baseUrl,
    required String apiKey,
    required String textModel,
    String? visionModel,
    AiTraining? training,
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _client = client ?? http.Client(),
        _textModel = textModel,
        _visionModel = visionModel ?? textModel,
        _training = training ?? AiTraining.defaults();

  final String _baseUrl;
  final String _apiKey;
  final http.Client _client;
  final String _textModel;
  final String _visionModel;
  final AiTraining _training;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> _chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    bool json = false,
    double temperature = 0.3,
  }) async {
    if (_apiKey.isEmpty) throw AiNotConfiguredException();
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      if (json) 'response_format': {'type': 'json_object'},
    };

    const maxAttempts = 3;
    Object? lastErr;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final res = await _client.post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: _headers,
          body: jsonEncode(body),
        );
        if (res.statusCode == 429 || res.statusCode >= 500) {
          throw _RetryableError(res.statusCode, res.body);
        }
        if (res.statusCode >= 400) {
          throw AiException(_friendly(res.statusCode, res.body));
        }
        return jsonDecode(res.body) as Map<String, dynamic>;
      } on AiException {
        rethrow;
      } catch (e) {
        lastErr = e;
        if (attempt == maxAttempts - 1) break;
        final backoffMs = (600 * pow(2, attempt)).toInt();
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }
    throw AiException('AI request failed: $lastErr');
  }

  String _extract(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw AiException('Empty response from AI.');
    }
    final msg = (choices.first as Map)['message'] as Map?;
    final content = msg?['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }
    if (content is List) {
      final parts =
          content.whereType<Map>().map((p) => p['text']).whereType<String>();
      final joined = parts.join('\n').trim();
      if (joined.isNotEmpty) return joined;
    }
    throw AiException('Empty response from AI.');
  }

  String _friendly(int status, String body) {
    final lower = body.toLowerCase();
    if (status == 401 || status == 403) return 'AI key is invalid or revoked.';
    if (status == 429 ||
        lower.contains('rate limit') ||
        lower.contains('quota')) {
      return 'Daily AI limit reached. Try again later.';
    }
    return 'AI service error ($status).';
  }

  // --- AiService implementation -----------------------------------------

  @override
  Future<FoodAnalysis> analyzeFoodText(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) throw AiException('Empty input.');
    final response = await _chat(
      model: _textModel,
      json: true,
      temperature: 0.2,
      messages: [
        {'role': 'system', 'content': _training.foodAnalysis},
        {'role': 'user', 'content': trimmed},
      ],
    );
    return _parseFoodAnalysis(_extract(response));
  }

  @override
  Future<FoodAnalysis> analyzeFoodPhoto(List<int> imageBytes,
      {String? hint}) async {
    if (imageBytes.isEmpty) throw AiException('Empty photo.');
    final b64 = base64Encode(Uint8List.fromList(imageBytes));
    final response = await _chat(
      model: _visionModel,
      json: false, // many vision models don't honor json mode reliably
      temperature: 0.2,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': '${_training.foodAnalysis}\n\n'
                  '${_training.photoInstruction} ${hint ?? ''}'
                      .trim(),
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$b64'},
            },
          ],
        },
      ],
    );
    return _parseFoodAnalysis(_extract(response));
  }

  @override
  Future<List<String>> identifyExercise(
      {List<int>? imageBytes, String? hint}) async {
    final hasImg = imageBytes != null && imageBytes.isNotEmpty;
    final hasHint = hint != null && hint.trim().isNotEmpty;
    if (!hasImg && !hasHint) return const [];
    try {
      final prompt = buildIdentifyPrompt(hint);
      final Map<String, dynamic> response;
      if (hasImg) {
        final b64 = base64Encode(Uint8List.fromList(imageBytes));
        response = await _chat(
          model: _visionModel,
          temperature: 0.2,
          messages: [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                },
              ],
            },
          ],
        );
      } else {
        response = await _chat(
          model: _textModel,
          temperature: 0.2,
          messages: [
            {'role': 'user', 'content': prompt},
          ],
        );
      }
      return parseExerciseNames(_extract(response));
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<RoutinePlan> generateStarterRoutine({
    required FitnessGoal goal,
    required int trainingDaysPerWeek,
    required List<String> libraryExerciseNames,
    List<int> restWeekdays = const [],
    WorkoutType workoutType = WorkoutType.gym,
    int? preferredSets,
    int? preferredRepsLow,
    int? preferredRepsHigh,
  }) async {
    final goalLabel = switch (goal) {
      FitnessGoal.buildMuscle => 'build muscle (modest surplus)',
      FitnessGoal.loseFat => 'lose fat while preserving muscle',
      FitnessGoal.recomp => 'body recomposition (slow change)',
      FitnessGoal.generalFitness => 'general fitness and strength',
    };
    final typeNote = switch (workoutType) {
      WorkoutType.gym =>
        'The user trains at a gym with full equipment (barbells, cables, machines, dumbbells).',
      WorkoutType.homeWorkout =>
        'IMPORTANT: The user works out at HOME. Use BODYWEIGHT or light dumbbell exercises ONLY. No gym machines, no barbells, no cables.',
      WorkoutType.yoga =>
        'IMPORTANT: Build a YOGA routine. Use yoga poses, flows, and breathing exercises. No gym or weightlifting exercises.',
      WorkoutType.meditation =>
        'IMPORTANT: Build a MEDITATION and mindfulness routine. Include breathing exercises, body scans, and guided meditation sessions. No physical exercises.',
      WorkoutType.none =>
        'The user is mostly sedentary. Build a very light general wellness or stretching routine.',
    };
    const weekdayNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    // Enumerate exact training vs rest weekdays so the AI can't drift.
    final restSet = restWeekdays.toSet();
    final trainingDayNames = <String>[];
    final restDayNames = <String>[];
    for (int wd = 1; wd <= 7; wd++) {
      if (restSet.contains(wd)) {
        restDayNames.add(weekdayNames[wd]);
      } else {
        trainingDayNames.add(weekdayNames[wd]);
      }
    }
    final restLine = restDayNames.isEmpty
        ? 'Rest weekdays (is_rest:true, empty exercises): NONE — user trains every day.'
        : 'Rest weekdays (is_rest:true, empty exercises): ${restDayNames.join(', ')}.';
    final setsLine = preferredSets != null
        ? '  4. Every training-day exercise MUST have exactly `sets: $preferredSets` — do not vary it.'
        : '  4. Pick a sensible sets count (3 for beginners, 4 for intermediate) based on the goal.';
    final repsLine = (preferredRepsLow != null && preferredRepsHigh != null)
        ? '  5. Every exercise MUST use `reps_low: $preferredRepsLow` and `reps_high: $preferredRepsHigh` — do not vary.'
        : '  5. Pick a rep range that matches the goal (12–15 endurance, 8–12 muscle, 5–8 strength).';
    final prompt =
        'Build a workout routine for someone whose goal is $goalLabel.\n'
        '$typeNote\n'
        'Prefer exercises from this library when they fit:\n${libraryExerciseNames.join(', ')}.\n'
        '\n'
        'HARD REQUIREMENTS — response is REJECTED if any of these are broken:\n'
        '  1. Return EXACTLY 7 day entries, one per weekday (1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun). No weekday may be missing.\n'
        '  2. Training weekdays (is_rest:false, exercises non-empty): ${trainingDayNames.join(', ')}.\n'
        '  3. $restLine\n'
        '$setsLine\n'
        '$repsLine\n'
        '  6. Within any single training day, do NOT list the same exercise more than once.\n'
        '\n'
        'Return JSON only.';
    final response = await _chat(
      model: _textModel,
      json: true,
      temperature: 0.3,
      messages: [
        {'role': 'system', 'content': _training.routine},
        {'role': 'user', 'content': prompt},
      ],
    );
    return _parseRoutine(_extract(response));
  }

  @override
  Future<String> coachChat({
    required String userContext,
    required List<CoachMessage> history,
    required String latestUserMessage,
  }) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _training.coachPersona},
      {
        'role': 'system',
        'content': 'User profile and recent context:\n$userContext',
      },
      ...history.map((m) => {
            'role': m.fromUser ? 'user' : 'assistant',
            'content': m.text,
          }),
      {'role': 'user', 'content': latestUserMessage},
    ];
    final response = await _chat(
      model: _textModel,
      temperature: 0.6,
      messages: messages,
    );
    return _extract(response);
  }

  @override
  Future<String> weeklyReview({required String contextSummary}) async {
    final response = await _chat(
      model: _textModel,
      temperature: 0.4,
      messages: [
        {'role': 'system', 'content': _training.coachPersona},
        {
          'role': 'user',
          'content': '${_training.weeklyReview}\n\n$contextSummary',
        },
      ],
    );
    return _extract(response);
  }

  @override
  Future<String> targetsAdvisory({required String profileSummary}) async {
    final response = await _chat(
      model: _textModel,
      temperature: 0.3,
      messages: [
        {'role': 'system', 'content': _training.targetsAdvisory},
        {'role': 'user', 'content': profileSummary},
      ],
    );
    return _extract(response);
  }

  @override
  Future<List<MealSuggestion>> suggestMeals({
    required int caloriesRemaining,
    required int proteinGRemaining,
    required int carbsGRemaining,
    required int fatGRemaining,
    String? cuisineHint,
    List<String> recentFoodHistory = const [],
    String? dietPreference,
  }) async {
    final historyLine = recentFoodHistory.isEmpty
        ? ''
        : 'Foods they actually eat (most-frequent first — BUILD SUGGESTIONS '
            'FROM THIS LIST FIRST):\n${recentFoodHistory.take(20).join(", ")}\n';
    final dietLine = (dietPreference == null || dietPreference.isEmpty)
        ? ''
        : 'Diet preference (hard filter): $dietPreference\n';
    final countryLine = (cuisineHint == null || cuisineHint.isEmpty)
        ? ''
        : 'Country / region: $cuisineHint — anchor suggestions to local '
            'cuisine, not generic Western defaults.\n';
    final prompt = 'Suggest 3 simple meal ideas to fit roughly:\n'
        'Calories left: $caloriesRemaining kcal\n'
        'Protein left: ${proteinGRemaining}g\n'
        'Carbs left: ${carbsGRemaining}g\n'
        'Fat left: ${fatGRemaining}g\n'
        '$countryLine'
        '$dietLine'
        '$historyLine'
        'Return STRICT JSON only.';
    final response = await _chat(
      model: _textModel,
      json: true,
      temperature: 0.4,
      messages: [
        {'role': 'system', 'content': _training.mealSuggestions},
        {'role': 'user', 'content': prompt},
      ],
    );
    final text = _extract(response);
    final cleaned = _stripFences(text);
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    final list = (json['suggestions'] as List?) ?? const [];
    return list.whereType<Map>().map((m) {
      final mm = Map<String, dynamic>.from(m);
      return MealSuggestion(
        name: (mm['name'] as String?)?.trim() ?? 'meal',
        calories: _i(mm['calories']) ?? 0,
        proteinG: _i(mm['protein_g']) ?? 0,
        carbsG: _i(mm['carbs_g']),
        fatG: _i(mm['fat_g']),
        fiberG: _i(mm['fiber_g']),
        portion: (mm['portion'] as String?)?.trim(),
        note: (mm['note'] as String?)?.trim(),
      );
    }).toList();
  }

  // --- Parsing helpers ---------------------------------------------------

  FoodAnalysis _parseFoodAnalysis(String raw) {
    final cleaned = _stripFences(raw);
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('Could not parse AI response as JSON.');
    }
    // Clarification short-circuit: the model wasn't sure and is asking
    // for one short follow-up question before estimating.
    if (json['needs_clarification'] == true) {
      final q = (json['question'] as String?)?.trim();
      if (q != null && q.isNotEmpty) {
        return FoodAnalysis.clarification(q);
      }
    }
    final itemsJson = (json['items'] as List?) ?? const [];
    final items = itemsJson
        .whereType<Map>()
        .map((m) => _parseFoodItem(Map<String, dynamic>.from(m)))
        .toList();
    if (items.isEmpty) throw AiException('No foods recognized.');

    final totalsJson =
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    return FoodAnalysis(
      items: items,
      totalCalories: _i(totalsJson['calories']) ??
          items.fold<int>(0, (s, e) => s + e.calories),
      totalProteinG: _i(totalsJson['protein_g']) ??
          items.fold<int>(0, (s, e) => s + e.proteinG),
      totalCarbsG: _i(totalsJson['carbs_g']) ??
          items.fold<int>(0, (s, e) => s + e.carbsG),
      totalFatG: _i(totalsJson['fat_g']) ??
          items.fold<int>(0, (s, e) => s + e.fatG),
      totalFiberG: _i(totalsJson['fiber_g']) ??
          items.fold<int>(0, (s, e) => s + e.fiberG),
      totalSodiumMg: _i(totalsJson['sodium_mg']) ??
          items.fold<int>(0, (s, e) => s + e.sodiumMg),
    );
  }

  FoodItemAnalysis _parseFoodItem(Map<String, dynamic> m) {
    final c = (m['confidence'] as String?)?.toLowerCase();
    final conf = c == 'high'
        ? EstimateConfidence.high
        : c == 'low'
            ? EstimateConfidence.low
            : EstimateConfidence.medium;
    int? low, high;
    final range = m['range'];
    if (range is Map) {
      low = _i(range['calories_low']);
      high = _i(range['calories_high']);
    }
    final sanitised = _sanitiseMacros(
      calories: _i(m['calories']) ?? _i(m['kcal']) ?? 0,
      proteinG: _i(m['protein_g']) ?? _i(m['protein']) ?? 0,
      carbsG:
          _i(m['carbs_g']) ?? _i(m['carbs']) ?? _i(m['carbohydrates_g']) ?? 0,
      fatG: _i(m['fat_g']) ??
          _i(m['fat']) ??
          _i(m['fats_g']) ??
          _i(m['total_fat_g']) ??
          0,
      fiberG: _i(m['fiber_g']) ?? _i(m['fiber']) ?? _i(m['dietary_fiber_g']) ?? 0,
      sodiumMg: _i(m['sodium_mg']) ?? _i(m['sodium']) ?? 0,
    );
    return FoodItemAnalysis(
      name: (m['name'] as String?)?.trim() ?? 'food',
      quantity: (m['quantity'] as String?)?.trim() ?? '',
      calories: sanitised.calories,
      proteinG: sanitised.proteinG,
      carbsG: sanitised.carbsG,
      fatG: sanitised.fatG,
      fiberG: sanitised.fiberG,
      sodiumMg: sanitised.sodiumMg,
      confidence: conf,
      caloriesLow: low,
      caloriesHigh: high,
    );
  }

  RoutinePlan _parseRoutine(String raw) {
    final cleaned = _stripFences(raw);
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('Could not parse routine JSON.');
    }
    final name = (json['name'] as String?)?.trim() ?? 'My routine';
    final daysJson = (json['days'] as List?) ?? const [];
    final days = daysJson.whereType<Map>().map((d) {
      final m = Map<String, dynamic>.from(d);
      final exJson = (m['exercises'] as List?) ?? const [];
      final exercises = exJson.whereType<Map>().map((e) {
        final em = Map<String, dynamic>.from(e);
        return RoutinePlanExercise(
          name: (em['name'] as String?)?.trim() ?? 'Exercise',
          sets: _i(em['sets']) ?? 3,
          repsLow: _i(em['reps_low']) ?? 8,
          repsHigh: _i(em['reps_high']) ?? 12,
          notes: (em['notes'] as String?)?.trim(),
        );
      }).toList();
      return RoutinePlanDay(
        name: (m['name'] as String?)?.trim() ?? 'Day',
        weekday: _i(m['weekday']) ?? 0,
        isRest: (m['is_rest'] as bool?) ?? false,
        exercises: exercises,
      );
    }).toList();
    if (days.isEmpty) throw AiException('AI returned no training days.');
    return RoutinePlan(name: name, days: days);
  }

  int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
    return null;
  }

  String _stripFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      final firstNl = t.indexOf('\n');
      if (firstNl > 0) t = t.substring(firstNl + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  /// Safety net for LLM hallucinations like "1 fish-oil capsule → 1000 g
  /// fat". Two layers:
  ///   1) If macros imply 2.5× more kcal than what the model returned
  ///      (likely a unit slip — mg reported as g), scale all macros
  ///      down proportionally so they fit the calorie estimate.
  ///   2) Hard-cap each macro to a per-item ceiling no real single
  ///      food can plausibly exceed.
  _SanitisedMacros _sanitiseMacros({
    required int calories,
    required int proteinG,
    required int carbsG,
    required int fatG,
    required int fiberG,
    required int sodiumMg,
  }) {
    var p = proteinG;
    var c = carbsG;
    var f = fatG;
    final fb = fiberG;
    final s = sodiumMg;
    final expectedKcal = 9 * f + 4 * p + 4 * c;
    if (calories > 0 && expectedKcal > calories * 2.5) {
      final scale = calories / expectedKcal;
      p = (p * scale).round();
      c = (c * scale).round();
      f = (f * scale).round();
    }
    return _SanitisedMacros(
      calories: calories.clamp(0, 5000),
      proteinG: p.clamp(0, 200),
      carbsG: c.clamp(0, 400),
      fatG: f.clamp(0, 200),
      fiberG: fb.clamp(0, 80),
      sodiumMg: s.clamp(0, 10000),
    );
  }
}

class _SanitisedMacros {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int sodiumMg;
  const _SanitisedMacros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
  });
}

class _RetryableError implements Exception {
  final int status;
  final String body;
  _RetryableError(this.status, this.body);
  @override
  String toString() => 'Retryable($status): $body';
}
