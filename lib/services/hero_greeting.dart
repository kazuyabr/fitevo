/// Picks an app-appropriate hero greeting based on context (time of day,
/// today's calorie progress, current streak, and whether a workout was
/// completed today).
///
/// Priority (most specific wins): workout done → target hit → strong
/// streak → time-of-day with progress hint.
import 'package:vivasaudavel/l10n/app_localizations.dart';

class HeroGreeting {
  final String phrase;
  final bool emphasiseStreak;
  const HeroGreeting({required this.phrase, this.emphasiseStreak = false});

  static HeroGreeting build({
    required AppLocalizations loc,
    required DateTime now,
    required int caloriesConsumed,
    required int calorieTarget,
    required int streakDays,
    required bool workoutCompletedToday,
  }) {
    if (workoutCompletedToday) {
      return HeroGreeting(phrase: loc.heroRecoverWell);
    }
    if (calorieTarget > 0 && caloriesConsumed >= calorieTarget) {
      return HeroGreeting(phrase: loc.heroYouHitIt);
    }
    if (streakDays >= 7) {
      return HeroGreeting(
          phrase: '${loc.heroDayStrong} $streakDays', emphasiseStreak: true);
    }

    final h = now.hour;
    final pct = calorieTarget > 0 ? caloriesConsumed / calorieTarget : 0.0;

    if (h < 5) return HeroGreeting(phrase: loc.heroGetSomeRest);
    if (h < 9) return HeroGreeting(phrase: loc.heroLetsFuelUp);
    if (h < 12) {
      return HeroGreeting(
        phrase: pct > 0.2 ? loc.heroStrongStart : loc.heroLightUpDay,
      );
    }
    if (h < 17) {
      if (pct > 0.4 && pct < 0.7) {
        return HeroGreeting(phrase: loc.heroHalfwayThere);
      }
      return HeroGreeting(
        phrase: pct < 0.2 ? loc.heroTimeToFuel : loc.heroKeepItGoing,
      );
    }
    if (h < 21) {
      if (pct > 0.85) return HeroGreeting(phrase: loc.heroAlmostThere);
      if (pct < 0.4) return HeroGreeting(phrase: loc.heroPlentyLeft);
      return HeroGreeting(phrase: loc.heroWindDownWell);
    }
    return HeroGreeting(phrase: loc.heroWindDown);
  }
}
