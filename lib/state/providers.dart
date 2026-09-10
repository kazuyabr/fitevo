import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/models/custom_food.dart';
import '../data/models/food_combo.dart';
import '../data/models/daily_log.dart';
import '../data/models/enums.dart';
import '../data/models/food_entry.dart';
import '../data/models/profile.dart';
import '../data/models/body_measurement.dart';
import '../data/models/cardio_session.dart';
import '../data/models/exercise.dart';
import '../data/models/routine.dart';
import '../data/models/soreness_log.dart';
import '../data/models/workout_session.dart';
import '../data/repositories/cardio_repo.dart';
import '../data/repositories/exercise_repo.dart';
import '../data/repositories/measurement_repo.dart';
import '../data/repositories/nutrition_repo.dart';
import '../data/repositories/period_repo.dart';
import '../data/models/period_log.dart';
import '../data/repositories/profile_repo.dart';
import '../data/repositories/soreness_repo.dart';
import '../data/repositories/workout_repo.dart';
import '../services/data/data_export_service.dart';
import '../services/progress/adaptive_targets.dart';
import '../services/progress/weight_trend.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/food_logger.dart';
import '../services/ai/gemini_ai_service.dart';
import '../services/ai/groq_ai_service.dart';
import '../services/ai/proxy_ai_service.dart';
import '../services/workout/exercise_image_service.dart';
import '../services/workout/exercise_video_service.dart';
import '../services/workout/routine_generator.dart';
import '../services/auth/auth_service.dart';
import '../services/nutrition/usda_service.dart';
import '../services/settings/app_settings.dart';
import '../services/sync/auto_backup_service.dart';
import '../services/sync/sync_service.dart';

const String _kGeminiApiKeyDefault =
    String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
const String _kGroqApiKeyDefault =
    String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
const String _kUsdaApiKeyDefault =
    String.fromEnvironment('USDA_API_KEY', defaultValue: '');
const String _kAiProxyUrlDefault =
    String.fromEnvironment('AI_PROXY_URL', defaultValue: '');

String _resolvedUsdaKey(Ref ref) {
  final stored = ref.read(appSettingsProvider).usdaApiKey;
  return stored.isNotEmpty ? stored : _kUsdaApiKeyDefault;
}

final dbProvider = Provider<Db>((ref) {
  throw UnimplementedError('dbProvider must be overridden at app start');
});

final appSettingsProvider = Provider<AppSettings>((ref) {
  throw UnimplementedError(
      'appSettingsProvider must be overridden at app start');
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(appSettingsProvider).themeMode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class UnitsNotifier extends Notifier<UnitSystem> {
  @override
  UnitSystem build() => ref.watch(appSettingsProvider).units;
}

final unitsProvider = NotifierProvider<UnitsNotifier, UnitSystem>(
  UnitsNotifier.new,
);

final profileRepoProvider = Provider<ProfileRepo>((ref) {
  return ProfileRepo(ref.watch(dbProvider));
});

final nutritionRepoProvider = Provider<NutritionRepo>((ref) {
  return NutritionRepo(ref.watch(dbProvider));
});

final profileStreamProvider = StreamProvider<Profile?>((ref) {
  return ref.watch(profileRepoProvider).watch();
});

final todayProvider = Provider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

final todayEntriesProvider = StreamProvider<List<FoodEntry>>((ref) {
  final repo = ref.watch(nutritionRepoProvider);
  return repo.watchEntriesForDate(ref.watch(todayProvider));
});

final todayLogProvider = StreamProvider<DailyLog?>((ref) {
  final repo = ref.watch(nutritionRepoProvider);
  return repo.watchDailyLog(ref.watch(todayProvider));
});

final todayTotalsProvider = Provider<DailyTotals>((ref) {
  final entries = ref.watch(todayEntriesProvider).value ?? const [];
  final log = ref.watch(todayLogProvider).value;
  return NutritionRepo.sumEntries(entries, waterMl: log?.waterMl ?? 0);
});

final customFoodsProvider = StreamProvider<List<CustomFood>>((ref) {
  return ref.watch(nutritionRepoProvider).watchCustomFoods();
});

final foodCombosProvider = StreamProvider<List<FoodCombo>>((ref) {
  return ref.watch(nutritionRepoProvider).watchCombos();
});

final periodRepoProvider = Provider<PeriodRepo>((ref) {
  return PeriodRepo(ref.watch(dbProvider));
});

final todayPeriodLogProvider = StreamProvider<PeriodLog?>((ref) {
  return ref.watch(periodRepoProvider).watchForDate(ref.watch(todayProvider));
});

final recentPeriodLogsProvider = StreamProvider<List<PeriodLog>>((ref) {
  return ref.watch(periodRepoProvider).watchRecent();
});

final cycleInsightProvider = Provider<CycleInsight>((ref) {
  final recent = ref.watch(recentPeriodLogsProvider).value ?? const [];
  return CycleInsight.from(recent, ref.watch(todayProvider));
});

final exerciseRepoProvider = Provider<ExerciseRepo>((ref) {
  return ExerciseRepo(ref.watch(dbProvider));
});

final workoutRepoProvider = Provider<WorkoutRepo>((ref) {
  return WorkoutRepo(ref.watch(dbProvider));
});

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepoProvider).watchAll();
});

final activeRoutineProvider = StreamProvider<Routine?>((ref) {
  return ref.watch(workoutRepoProvider).watchActiveRoutine();
});

final recentSessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutRepoProvider).watchRecentSessions();
});

final allSessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(workoutRepoProvider).watchAllSessions();
});

// ---- Cardio --------------------------------------------------------------

final cardioRepoProvider = Provider<CardioRepo>((ref) {
  return CardioRepo(ref.watch(dbProvider));
});

/// Cardio bouts logged today — feeds the day's calorie-burn total.
final todayCardioProvider = StreamProvider<List<CardioSession>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(cardioRepoProvider).watchOnDate(today);
});

final allCardioProvider = StreamProvider<List<CardioSession>>((ref) {
  return ref.watch(cardioRepoProvider).watchAll();
});

// ---- Recovery / soreness -------------------------------------------------

final sorenessRepoProvider = Provider<SorenessRepo>((ref) {
  return SorenessRepo(ref.watch(dbProvider));
});

/// Today's soreness check-in, if the user has done one.
final todaySorenessProvider = StreamProvider<SorenessLog?>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(sorenessRepoProvider).watchForDate(today);
});

final measurementRepoProvider = Provider<MeasurementRepo>((ref) {
  return MeasurementRepo(ref.watch(dbProvider));
});

final measurementsProvider = StreamProvider<List<BodyMeasurement>>((ref) {
  return ref.watch(measurementRepoProvider).watchAll();
});

final weightTrendProvider = Provider<WeightTrend>((ref) {
  final ms = ref.watch(measurementsProvider).value ??
      const <BodyMeasurement>[];
  final profile = ref.watch(profileStreamProvider).value;
  return WeightTrend.compute(ms, profile?.goal ?? FitnessGoal.generalFitness);
});

final adaptiveTargetsProvider = Provider<AdaptiveTargets>((ref) {
  return AdaptiveTargets(
    profileRepo: ref.watch(profileRepoProvider),
    measurementRepo: ref.watch(measurementRepoProvider),
  );
});

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(ref.watch(dbProvider));
});

/// All food entries across all dates — used for trend charts and streak.
final allFoodEntriesProvider = StreamProvider<List<FoodEntry>>((ref) {
  return ref.watch(nutritionRepoProvider).watchAllEntries();
});

final allDailyLogsProvider = StreamProvider<List<DailyLog>>((ref) {
  return ref.watch(nutritionRepoProvider).watchAllLogs();
});

final todaysRoutineDayProvider =
    FutureProvider.autoDispose<RoutineDay?>((ref) async {
  ref.watch(activeRoutineProvider);
  final today = ref.watch(todayProvider);
  // Profile's restDays is the source of truth for "is today rest?".
  // Pass it into the repo so an AI-generated routine whose rest weekday
  // disagrees with the user's setting can't override the user.
  final profile = ref.watch(profileStreamProvider).value;
  final restWeekdays = profile?.restDays.toSet();
  return ref
      .read(workoutRepoProvider)
      .resolveTodaysDay(today, restWeekdays: restWeekdays);
});

final routineGeneratorProvider = Provider<RoutineGenerator>((ref) {
  return RoutineGenerator(
    ai: ref.watch(aiServiceProvider),
    exercises: ref.watch(exerciseRepoProvider),
    workouts: ref.watch(workoutRepoProvider),
  );
});

final exerciseImageServiceProvider = Provider<ExerciseImageService>((ref) {
  return ExerciseImageService();
});

final exerciseVideoServiceProvider = Provider<ExerciseVideoService>((ref) {
  return ExerciseVideoService();
});

final aiServiceProvider = Provider<AiService>((ref) {
  // 1) Explicit in-app configuration wins: the user's own keys always
  //    override whatever was shipped at build time.
  // 2) Otherwise fall back to build-time defaults (Proxy → Groq → Gemini),
  //    e.g. the app-provided Cloudflare Worker that holds the key
  //    server-side.
  final settings = ref.read(appSettingsProvider);
  if (settings.aiProxyUrl.isNotEmpty) {
    return ProxyAiService(baseUrl: settings.aiProxyUrl);
  }
  if (settings.groqApiKey.isNotEmpty) {
    return GroqAiService(apiKey: settings.groqApiKey);
  }
  if (settings.geminiApiKey.isNotEmpty) {
    return GeminiAiService(apiKey: settings.geminiApiKey);
  }
  if (_kAiProxyUrlDefault.isNotEmpty) {
    return ProxyAiService(baseUrl: _kAiProxyUrlDefault);
  }
  if (_kGroqApiKeyDefault.isNotEmpty) {
    return GroqAiService(apiKey: _kGroqApiKeyDefault);
  }
  return GeminiAiService(apiKey: _kGeminiApiKeyDefault);
});

final usdaServiceProvider = Provider<UsdaService>((ref) {
  return UsdaService(apiKey: _resolvedUsdaKey(ref));
});

final foodLoggerProvider = Provider<FoodLogger>((ref) {
  return FoodLogger(
    ai: ref.watch(aiServiceProvider),
    nutrition: ref.watch(nutritionRepoProvider),
    usda: ref.watch(usdaServiceProvider),
  );
});

/// Check if any AI key is configured (reads from AppSettings + env vars).
/// This is a top-level function because WidgetRef can't be passed as Ref.
bool checkAiConfigured(AppSettings settings) {
  final groq = settings.groqApiKey;
  final gemini = settings.geminiApiKey;
  final proxy = settings.aiProxyUrl;
  return groq.isNotEmpty ||
      gemini.isNotEmpty ||
      proxy.isNotEmpty ||
      _kGroqApiKeyDefault.isNotEmpty ||
      _kGeminiApiKeyDefault.isNotEmpty ||
      _kAiProxyUrlDefault.isNotEmpty;
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(db: ref.watch(dbProvider));
});

/// Background auto-backup. Singleton — created once, lifecycle managed
/// by [autoBackupLifecycleProvider] which starts/stops it as the user
/// signs in or out.
final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  final svc = AutoBackupService(
    db: ref.watch(dbProvider),
    sync: ref.watch(syncServiceProvider),
  );
  ref.onDispose(svc.stop);
  return svc;
});

/// Watches auth state and starts/stops the auto-backup service for
/// non-anonymous users. Wired up by an app-level ConsumerWidget so the
/// service spins up once after Firebase finishes restoring the session.
final autoBackupLifecycleProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).value;
  final svc = ref.watch(autoBackupServiceProvider);
  if (user != null && !user.isAnonymous) {
    svc.start();
  } else {
    // Fire-and-forget; safe to call when not started.
    svc.stop();
  }
});

/// Runs once per uid on sign-in: pulls cloud → local if local is empty,
/// pushes local → cloud if cloud is empty.
final initialSyncProvider = FutureProvider.family<void, String>((ref, uid) async {
  final sync = ref.watch(syncServiceProvider);
  final hasLocal = await sync.localHasData();
  final hasCloud = await sync.cloudHasData();
  if (!hasLocal && hasCloud) {
    await sync.pullAll();
  } else if (hasLocal && !hasCloud) {
    await sync.pushAll();
  }
});
