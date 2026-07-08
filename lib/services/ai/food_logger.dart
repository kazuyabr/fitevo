import '../../data/models/daily_log.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_entry.dart';
import '../../data/repositories/nutrition_repo.dart';
import '../nutrition/usda_service.dart';
import 'ai_service.dart';

class FoodLogger {
  FoodLogger({
    required this.ai,
    required this.nutrition,
    required this.usda,
  });

  final AiService ai;
  final NutritionRepo nutrition;
  final UsdaService usda;

  Future<LogResult> logFromText(String input, {DateTime? targetDate}) async {
    final analysis = await ai.analyzeFoodText(input);
    if (analysis.needsClarification) {
      return LogResult.clarification(analysis.clarificationQuestion!);
    }
    return _persistAnalysis(analysis,
        rawInput: input, source: FoodSource.aiText, targetDate: targetDate);
  }

  Future<LogResult> logFromPhoto(List<int> bytes,
      {String? hint, String? photoPath, DateTime? targetDate}) async {
    final analysis = await ai.analyzeFoodPhoto(bytes, hint: hint);
    if (analysis.needsClarification) {
      return LogResult.clarification(analysis.clarificationQuestion!);
    }
    return _persistAnalysis(
      analysis,
      rawInput: hint ?? '(photo)',
      source: FoodSource.aiPhoto,
      photoPath: photoPath,
      targetDate: targetDate,
    );
  }

  /// Estimate a reusable custom food's per-serving nutrition from a plain
  /// description. The user states what they know ("1 scoop whey, 24g protein,
  /// 2g carb") and the AI fills the rest, or estimates everything when they
  /// give no numbers ("4 boiled eggs"). Returns null when the model can't
  /// produce an estimate (e.g. offline) so the form falls back to manual entry.
  ///
  /// Built on top of [AiService.analyzeFoodText] so it works with every
  /// provider (proxy / Gemini / Groq) without adding to the interface. The
  /// analyzer already honors stated macros in the text and sums composite
  /// items ("scoop whey with 150ml milk" → one combined serving).
  Future<CustomFoodEstimate?> estimateCustomFood(String description) async {
    final text = description.trim();
    if (text.isEmpty) return null;
    var analysis = await ai.analyzeFoodText(text);
    // For a saved staple we want a best-effort estimate, not a question —
    // if the model asks to clarify, nudge it to assume a typical serving.
    if (analysis.needsClarification) {
      analysis = await ai.analyzeFoodText(
          '$text (estimate one typical serving; do not ask questions)');
    }
    if (analysis.items.isEmpty && analysis.totalCalories == 0) return null;
    // Collapse whatever the analyzer returned into a single serving. Multi-item
    // descriptions ("whey + milk") get summed; the first item names it.
    final name = analysis.items.isNotEmpty
        ? analysis.items.first.name.trim()
        : text;
    return CustomFoodEstimate(
      name: name,
      calories: analysis.totalCalories,
      proteinG: analysis.totalProteinG,
      carbsG: analysis.totalCarbsG,
      fatG: analysis.totalFatG,
      fiberG: analysis.totalFiberG,
      sodiumMg: analysis.totalSodiumMg,
    );
  }

  /// Analyse a food photo WITHOUT persisting — used by the review flow so
  /// the user can see the AI's read of the plate and confirm or correct it
  /// before anything is logged. Pass the user's correction as [hint] to
  /// re-estimate.
  Future<FoodAnalysis> analyzePhoto(List<int> bytes, {String? hint}) {
    return ai.analyzeFoodPhoto(bytes, hint: hint);
  }

  /// Persist a photo analysis the user has already reviewed/confirmed in the
  /// review sheet.
  Future<LogResult> logAnalyzedPhoto(
    FoodAnalysis analysis, {
    String? photoPath,
    String? rawInput,
    DateTime? targetDate,
  }) {
    return _persistAnalysis(
      analysis,
      rawInput: rawInput ?? '(photo)',
      source: FoodSource.aiPhoto,
      photoPath: photoPath,
      targetDate: targetDate,
    );
  }

  Future<LogResult> _persistAnalysis(
    FoodAnalysis analysis, {
    required String rawInput,
    required FoodSource source,
    String? photoPath,
    DateTime? targetDate,
  }) async {
    final DateTime timestamp;
    final String dateKey;
    if (targetDate != null) {
      dateKey = DailyLog.keyFor(targetDate);
      timestamp = DateTime(
          targetDate.year, targetDate.month, targetDate.day, 12, 0);
    } else {
      final now = DateTime.now();
      dateKey = DailyLog.keyFor(now);
      timestamp = now;
    }

    int totalKcal = 0;
    final entries = <FoodEntry>[];
    for (final item in analysis.items) {
      final adjusted = await _maybeCrossCheckUsda(item);
      final entry = FoodEntry()
        ..timestamp = timestamp
        ..dateKey = dateKey
        ..rawInput = rawInput
        ..description = adjusted.name
        ..quantity = adjusted.quantity
        ..calories = adjusted.calories
        ..proteinG = adjusted.proteinG
        ..carbsG = adjusted.carbsG
        ..fatG = adjusted.fatG
        ..fiberG = adjusted.fiberG
        ..sodiumMg = adjusted.sodiumMg
        ..confidence = adjusted.confidence
        ..caloriesLow = adjusted.caloriesLow
        ..caloriesHigh = adjusted.caloriesHigh
        ..source = source
        ..photoPath = photoPath;
      entries.add(entry);
      totalKcal += entry.calories;
      await nutrition.addFoodEntry(entry);
    }

    return LogResult(
      entries: entries,
      totalCalories: totalKcal,
      hasLowConfidence:
          entries.any((e) => e.confidence == EstimateConfidence.low),
    );
  }

  Future<FoodItemAnalysis> _maybeCrossCheckUsda(FoodItemAnalysis item) async {
    if (item.confidence != EstimateConfidence.low) return item;
    if (!usda.isConfigured) return item;
    final words = item.name.trim().split(RegExp(r'\s+'));
    if (words.length > 4) return item;
    final hit = await usda.searchSingleFood(item.name);
    if (hit == null) return item;
    // Without a parsed gram weight we can't recompute exactly; just nudge
    // confidence up to medium when USDA confirms the food exists.
    return FoodItemAnalysis(
      name: item.name,
      quantity: item.quantity,
      calories: item.calories,
      proteinG: item.proteinG,
      carbsG: item.carbsG,
      fatG: item.fatG,
      fiberG: item.fiberG,
      sodiumMg: item.sodiumMg,
      confidence: EstimateConfidence.medium,
      caloriesLow: item.caloriesLow,
      caloriesHigh: item.caloriesHigh,
    );
  }
}

class LogResult {
  final List<FoodEntry> entries;
  final int totalCalories;
  final bool hasLowConfidence;
  /// When set, the AI asked for one short clarification instead of
  /// estimating. No entries were persisted — the caller should show
  /// the question and re-call logFromText with the combined input.
  final String? clarificationQuestion;

  const LogResult({
    required this.entries,
    required this.totalCalories,
    required this.hasLowConfidence,
    this.clarificationQuestion,
  });

  /// Convenience constructor for a "AI asked a question" outcome.
  /// hasLowConfidence is false; entries is empty.
  factory LogResult.clarification(String question) => LogResult(
        entries: const [],
        totalCalories: 0,
        hasLowConfidence: false,
        clarificationQuestion: question,
      );

  bool get isClarification =>
      clarificationQuestion != null && clarificationQuestion!.isNotEmpty;
}

/// AI's per-serving estimate for a reusable custom food. Used to pre-fill the
/// custom-food form — the user can still edit every field afterward.
class CustomFoodEstimate {
  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int sodiumMg;
  const CustomFoodEstimate({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
  });
}
