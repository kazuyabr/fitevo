enum Gender { male, female, other }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum FitnessGoal { buildMuscle, loseFat, recomp, generalFitness }

enum FoodSource { aiText, aiPhoto, usdaVerified, custom, favorite }

enum EstimateConfidence { high, medium, low }

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  quads,
  hamstrings,
  glutes,
  calves,
  core,
  cardio,
  fullBody,
}

/// Health & medical context. Some of these (pregnant, breastfeeding,
/// eating-disorder history, T1 diabetes) trigger a "talk to a pro" card
/// during onboarding and soften the math. Others (PCOS, hypothyroid, T2
/// diabetes) just adjust calorie / macro defaults and feed the AI coach.
enum HealthFlag {
  pregnant,
  breastfeeding,
  eatingDisorderHistory,
  recoveringFromInjury,
  t1Diabetes,
  t2Diabetes,
  pcos,
  hypothyroid,
}

/// How often the app should nudge the user to log weight. Stored
/// alongside an optional preferred weekday (1 = Mon … 7 = Sun) so the
/// reminder lands on a specific day each cycle.
enum WeighInCadence { daily, everyOtherDay, twiceAWeek, weekly }

/// Dietary preference for food suggestions and AI advice. Affects which
/// proteins the coach recommends, which cuisines are surfaced, and what
/// gets flagged as off-plan.
enum DietPreference {
  omnivore,
  vegetarian,
  vegan,
  pescatarian,
  keto,
  halal,
  kosher,
  jain,
}

/// Menstrual-cycle phase (female users only). Affects water retention,
/// hunger, and lifting performance. Tracked manually for now via a quick
/// picker; could be derived from a logged period start date later.
enum CyclePhase {
  unknown,
  menstrual, // days 1-5
  follicular, // days 6-14
  ovulation, // days 14-16
  luteal, // days 17-28
}

/// Per-day flow level for menstrual cycle logging. Spotting is its own
/// category (not just "light") so cycle math can distinguish a real
/// period day from inter-cycle spotting when estimating cycle length.
enum MenstrualFlow {
  none,
  spotting,
  light,
  medium,
  heavy,
}

/// Common cycle-related symptoms the user can tag onto a period day.
/// Names are normalized for storage; the UI maps to user-facing labels.
enum PeriodSymptom {
  cramps,
  headache,
  bloating,
  fatigue,
  moodSwings,
  backPain,
  breastTenderness,
  nausea,
  acne,
  cravings,
  insomnia,
}

enum Equipment {
  bodyweight,
  dumbbell,
  barbell,
  machine,
  cable,
  kettlebell,
  band,
  smith,
  other,
}

/// How the user prefers to work out. Drives AI routine generation and
/// controls which onboarding fields are shown.
enum WorkoutType {
  gym,
  homeWorkout,
  yoga,
  meditation,
  none,
}

/// The kind of a logged set. `normal` is a regular working set; the rest
/// change how the set is treated in PR / volume math and how it renders
/// in the logger:
///   • warmup   — excluded from PR + working-volume calculations
///   • dropSet  — a reduced-weight continuation right after a working set
///   • amrap    — "as many reps as possible" (usually the last set)
///   • failure  — taken to muscular failure
enum SetType {
  normal,
  warmup,
  dropSet,
  amrap,
  failure,
}

/// How a set felt, captured on the rest screen right after the set. This
/// is a subjective read the AI coach uses for better advice — effort plus
/// an explicit pain/caution flag that RPE alone can't express.
///   • easy   — too light, left a lot in the tank
///   • good   — dialed in, challenging but clean
///   • hard   — a real grind
///   • brutal — at or near failure
///   • pain   — something hurt (joint/tweak) — coach should back off
enum SetFeeling {
  unset,
  easy,
  good,
  hard,
  brutal,
  pain,
}

/// Cardio / conditioning modality. Distance-based ones (run, walk, cycle,
/// row, swim) surface a distance field; the rest are duration-only.
enum CardioType {
  run,
  walk,
  cycle,
  row,
  swim,
  elliptical,
  stairs,
  hiit,
  jumpRope,
  other,
}
