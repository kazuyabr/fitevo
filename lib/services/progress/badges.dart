import 'package:flutter/material.dart';

import '../../data/models/food_entry.dart';
import '../../data/models/workout_session.dart';
import '../workout/pr_tracker.dart';
import 'streak_calc.dart';

class Badge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool earned;
  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earned,
  });
}

class BadgeEngine {
  static List<Badge> evaluate({
    required List<FoodEntry> foods,
    required List<WorkoutSession> sessions,
    required DateTime today,
  }) {
    final streak = StreakCalc.currentStreak(
      foodEntries: foods,
      sessions: sessions,
      today: today,
    );
    final prs = PrTracker.personalRecords(sessions);
    final hasPR = prs.isNotEmpty;
    final completedSessions =
        sessions.where((s) => s.completedAt != null).length;
    // Lifting milestones from logged working sets.
    double totalTonnage = 0;
    double bestE1RM = 0;
    for (final s in sessions) {
      for (final set in s.sets) {
        if (set.isWarmup) continue;
        totalTonnage += set.weightKg * set.reps;
        final e = PrTracker.estimatedFromSet(set);
        if (e > bestE1RM) bestE1RM = e;
      }
    }

    return [
      Badge(
        id: 'first_meal',
        name: 'First bite',
        description: 'Log your first meal.',
        icon: Icons.restaurant_rounded,
        earned: foods.isNotEmpty,
      ),
      Badge(
        id: 'first_workout',
        name: 'First lift',
        description: 'Finish your first workout.',
        icon: Icons.fitness_center_rounded,
        earned: completedSessions >= 1,
      ),
      Badge(
        id: 'first_pr',
        name: 'New PR',
        description: 'Hit your first personal record.',
        icon: Icons.emoji_events_rounded,
        earned: hasPR,
      ),
      Badge(
        id: 'streak_7',
        name: '7-day streak',
        description: 'Stay active 7 days in a row.',
        icon: Icons.local_fire_department_rounded,
        earned: streak >= 7,
      ),
      Badge(
        id: 'streak_30',
        name: '30-day streak',
        description: 'A full month of consistency.',
        icon: Icons.whatshot_rounded,
        earned: streak >= 30,
      ),
      Badge(
        id: 'ten_sessions',
        name: '10 sessions',
        description: 'Finish 10 workouts.',
        icon: Icons.military_tech_rounded,
        earned: completedSessions >= 10,
      ),
      Badge(
        id: 'fifty_sessions',
        name: '50 sessions',
        description: 'Finish 50 workouts.',
        icon: Icons.workspace_premium_rounded,
        earned: completedSessions >= 50,
      ),
      Badge(
        id: 'ten_prs',
        name: 'PR machine',
        description: 'Set 10 personal records.',
        icon: Icons.trending_up_rounded,
        earned: prs.length >= 10,
      ),
      Badge(
        id: 'century_club',
        name: 'Century club',
        description: 'Reach a 100 kg estimated 1RM on any lift.',
        icon: Icons.fitness_center_rounded,
        earned: bestE1RM >= 100,
      ),
      Badge(
        id: 'tonnage_100k',
        name: '100 tonnes',
        description: 'Move 100,000 kg of total volume.',
        icon: Icons.scale_rounded,
        earned: totalTonnage >= 100000,
      ),
      Badge(
        id: 'tonnage_500k',
        name: 'Half a million',
        description: 'Move 500,000 kg of total volume.',
        icon: Icons.diamond_rounded,
        earned: totalTonnage >= 500000,
      ),
    ];
  }
}
