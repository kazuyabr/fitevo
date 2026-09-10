import 'dart:convert';

import '../../data/models/enums.dart';

class RoutinePlanExercise {
  final String name;
  final int sets;
  final int repsLow;
  final int repsHigh;
  final String? notes;
  const RoutinePlanExercise({
    required this.name,
    required this.sets,
    required this.repsLow,
    required this.repsHigh,
    this.notes,
  });
}

class RoutinePlanDay {
  final String name;
  final int weekday; // 1=Mon..7=Sun, 0=unassigned
  final bool isRest;
  final List<RoutinePlanExercise> exercises;
  const RoutinePlanDay({
    required this.name,
    required this.weekday,
    required this.isRest,
    required this.exercises,
  });
}

class RoutinePlan {
  final String name;
  final List<RoutinePlanDay> days;
  const RoutinePlan({required this.name, required this.days});
}

class FoodItemAnalysis {
  final String name;
  final String quantity;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int sodiumMg;
  final EstimateConfidence confidence;
  final int? caloriesLow;
  final int? caloriesHigh;

  const FoodItemAnalysis({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
    required this.confidence,
    this.caloriesLow,
    this.caloriesHigh,
  });
}

class FoodAnalysis {
  final List<FoodItemAnalysis> items;
  final int totalCalories;
  final int totalProteinG;
  final int totalCarbsG;
  final int totalFatG;
  final int totalFiberG;
  final int totalSodiumMg;

  /// When set, the model didn't have enough info to log confidently and
  /// is asking for one short clarification (e.g. "How many eggs?").
  /// The UI shows this as an inline chip below the input — when the
  /// user answers, the AI is re-prompted with both the original input
  /// and the answer combined.
  final String? clarificationQuestion;

  /// True when the response is purely a clarification request — no
  /// items were estimated. Use this to skip logging entirely.
  bool get needsClarification =>
      clarificationQuestion != null && clarificationQuestion!.isNotEmpty;

  const FoodAnalysis({
    required this.items,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.totalFiberG,
    required this.totalSodiumMg,
    this.clarificationQuestion,
  });

  /// Convenience constructor for a clarification-only response — no
  /// estimates, just the question.
  factory FoodAnalysis.clarification(String question) => FoodAnalysis(
        items: const [],
        totalCalories: 0,
        totalProteinG: 0,
        totalCarbsG: 0,
        totalFatG: 0,
        totalFiberG: 0,
        totalSodiumMg: 0,
        clarificationQuestion: question,
      );
}

class CoachMessage {
  final bool fromUser;
  final String text;
  final DateTime timestamp;
  const CoachMessage({
    required this.fromUser,
    required this.text,
    required this.timestamp,
  });
}

class MealSuggestion {
  final String name;
  final int calories;
  final int proteinG;
  /// Optional macros — newer AI prompts return these too so the
  /// suggestion can be logged with the same fidelity as a manual
  /// food entry. Legacy responses leave them null.
  final int? carbsG;
  final int? fatG;
  final int? fiberG;
  /// Portion description — always grams now ("120g rice, 100g dal,
  /// 80g chicken curry"). Older responses may have plate/bowl
  /// language; the UI prefers structured fields when available.
  final String? portion;
  final String? note;
  const MealSuggestion({
    required this.name,
    required this.calories,
    required this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.portion,
    this.note,
  });
}

abstract class AiService {
  Future<FoodAnalysis> analyzeFoodText(String input, {String? userContext});
  Future<FoodAnalysis> analyzeFoodPhoto(List<int> imageBytes,
      {String? hint, String? userContext});
  Future<RoutinePlan> generateStarterRoutine({
    required FitnessGoal goal,
    required int trainingDaysPerWeek,
    required List<String> libraryExerciseNames,
    List<int> restWeekdays = const [],
    WorkoutType workoutType = WorkoutType.gym,
    int? preferredSets,
    int? preferredRepsLow,
    int? preferredRepsHigh,
  });
  Future<String> coachChat({
    required String userContext,
    required List<CoachMessage> history,
    required String latestUserMessage,
  });
  Future<String> weeklyReview({
    required String contextSummary,
  });
  Future<String> targetsAdvisory({
    required String profileSummary,
  });
  Future<List<MealSuggestion>> suggestMeals({
    required int caloriesRemaining,
    required int proteinGRemaining,
    required int carbsGRemaining,
    required int fatGRemaining,
    String? cuisineHint,
    /// Foods the user actually eats often, most-frequent first. The
    /// model should build suggestions FROM this list before adding
    /// anything new — "healthy people eat the same things every day"
    /// and an out-of-context suggestion (tuna pasta for a Nepali user)
    /// just gets ignored. Empty means no history yet.
    List<String> recentFoodHistory = const [],
    /// Dietary preference verbatim ("omnivore", "vegetarian", "vegan",
    /// "halal", etc). Used as a hard filter — vegan never gets meat,
    /// halal never gets pork, etc.
    String? dietPreference,
    /// Optional user context for personalised suggestions (diet, goals,
    /// current intake, etc.).  Built by [UserContextBuilder].
    String? userContext,
  });

  /// Identify a gym exercise/machine from a photo and/or a short text hint.
  /// Returns candidate common exercise names (most likely first), or an
  /// empty list when the provider can't identify it — callers fall back to
  /// manual browse. Implementations must never throw; return `[]` on error.
  Future<List<String>> identifyExercise({List<int>? imageBytes, String? hint});
}

/// Prompt shared by every provider for exercise identification.
String buildIdentifyPrompt(String? hint) {
  final h = (hint == null || hint.trim().isEmpty)
      ? ''
      : ' The user also describes it: "${hint.trim()}".';
  return 'You identify gym exercises and machines. From the image and/or '
      'description, name the most likely exercise(s).$h Respond ONLY with '
      'JSON: {"names":["Lat Pulldown","Seated Cable Row"]} — up to 4 common '
      'gym exercise names, most likely first. No prose.';
}

/// Parses candidate exercise names from a model reply — accepts
/// `{"names":[...]}`, a bare JSON array, or a loose newline/comma list.
List<String> parseExerciseNames(String raw) {
  var s = raw.trim();
  s = s.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '').trim();
  try {
    final j = jsonDecode(s);
    if (j is Map && j['names'] is List) {
      return (j['names'] as List)
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(6)
          .toList();
    }
    if (j is List) {
      return j
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(6)
          .toList();
    }
  } catch (_) {}
  return s
      .split(RegExp(r'[\n,]'))
      .map((e) => e.replaceAll(RegExp(r'^[-*\d.\)\s]+'), '').trim())
      .where((e) => e.isNotEmpty && e.length <= 60)
      .take(6)
      .toList();
}

class AiException implements Exception {
  final String message;
  AiException(this.message);

  @override
  String toString() => message;
}

class AiNotConfiguredException extends AiException {
  AiNotConfiguredException()
      : super(
            'AI is not configured. Add your free Groq API key (console.groq.com) or Gemini key (aistudio.google.com) to enable logging.');
}
