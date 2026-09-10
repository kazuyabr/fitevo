import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_math.dart';
import '../../data/models/enums.dart';
import '../../data/models/profile.dart';
import '../../services/notifications/notification_service.dart';
import '../../state/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/body_focus_grid.dart';
import '../workout/workout_type_picker.dart';

class _Draft {
  String name = '';
  int age = 22;
  Gender gender = Gender.male;
  double heightCm = 172;
  double weightKg = 68;
  ActivityLevel activity = ActivityLevel.moderate;
  FitnessGoal goal = FitnessGoal.generalFitness;
  int trainingDays = 3;
  int cardioDays = 0;
  double walkingKmPerDay = 0;
  double runningKmPerWeek = 0;
  int gymMinutesPerSession = 60;
  String focusNotes = '';
  int wakeMin = 420; // 7:00 AM
  int sleepMin = 1380; // 11:00 PM
  // Per-day schedule. False = single wake/sleep applies to every day.
  // When true, [wakeMinByDay] / [sleepMinByDay] hold 7 entries each,
  // index 0 = Monday … 6 = Sunday.
  bool perDaySchedule = false;
  List<int> wakeMinByDay = List<int>.filled(7, 420);
  List<int> sleepMinByDay = List<int>.filled(7, 1380);
  bool takesSupplements = false;
  int creatineG = 0;
  int proteinScoops = 0;
  int proteinGrams = 0;
  bool multivitamin = false;
  String otherSupp = '';
  // Months since gym start (0 = "just started", null = "never lifted").
  // We store as months-ago rather than a date so the picker is friendlier;
  // the date is reconstructed at save time.
  int? gymMonthsAgo;

  // Phase 5 additions — health context + scheduling.
  double? bodyFatPct;
  List<HealthFlag> healthFlags = [];
  List<int> restDays = []; // 1=Mon..7=Sun, typically Sat in NP
  WeighInCadence weighInCadence = WeighInCadence.weekly;
  int? weighInWeekday;

  // How the user prefers to work out.
  WorkoutType workoutType = WorkoutType.gym;

  // Derived — true only for gym users (backward compat with downstream checks).
  bool get goesGym => workoutType == WorkoutType.gym;
  // True for types that have structured training days (gym, home, yoga).
  bool get showsTrainingDays =>
      workoutType == WorkoutType.gym ||
      workoutType == WorkoutType.homeWorkout ||
      workoutType == WorkoutType.yoga;

  // Daily running km — the user enters a typical per-day value; the
  // home page lets them log actual km on the day they run.
  double runningKmPerDay = 0;

  // Region + diet for culturally-aware AI suggestions.
  String country = '';
  DietPreference dietPreference = DietPreference.omnivore;
}

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pc = PageController();
  final _draft = _Draft();
  int _page = 0;
  bool _saving = false;
  static const _totalPages = 6;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final dn = user?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) {
      _draft.name = dn;
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  /// Convert "months ago" into an approximate gym-start date so the math
  /// layer (which thinks in dates) can compute newbie status. Null when
  /// the user said they've never lifted.
  DateTime? _gymStartDate(int? monthsAgo) {
    if (monthsAgo == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month - monthsAgo, now.day);
  }

  void _back() {
    if (_page == 0) return;
    _pc.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final gymStart = _draft.goesGym ? _gymStartDate(_draft.gymMonthsAgo) : null;
    final runningKmPerWeek = (_draft.runningKmPerDay * 7).roundToDouble();
    final t = HealthMath.compute(
      gender: _draft.gender,
      age: _draft.age,
      weightKg: _draft.weightKg,
      heightCm: _draft.heightCm,
      activity: _draft.activity,
      goal: _draft.goal,
      cardioSessionsPerWeek: _draft.cardioDays,
      walkingKmPerDay: _draft.walkingKmPerDay,
      runningKmPerWeek: runningKmPerWeek,
      gymMinutesPerSession:
          _draft.goesGym ? _draft.gymMinutesPerSession : 0,
      strengthDaysPerWeek: _draft.goesGym ? _draft.trainingDays : 0,
      bodyFocusNotes: _draft.focusNotes,
      creatineGramsPerDay: _draft.goesGym ? _draft.creatineG : 0,
      proteinScoopsPerDay: _draft.goesGym ? _draft.proteinScoops : 0,
      gymStartDate: gymStart,
      bodyFatPct: _draft.bodyFatPct,
      healthFlags: _draft.healthFlags,
      restDays: _draft.restDays,
    );
    final p = Profile()
      ..displayName = _draft.name.trim()
      ..age = _draft.age
      ..gender = _draft.gender
      ..heightCm = _draft.heightCm
      ..weightKg = _draft.weightKg
      ..activityLevel = _draft.activity
      ..goal = _draft.goal
      ..trainingDaysPerWeek = _draft.goesGym ? _draft.trainingDays : 0
      ..cardioSessionsPerWeek = _draft.cardioDays
      ..walkingKmPerDay = _draft.walkingKmPerDay
      ..runningKmPerWeek = runningKmPerWeek
      ..gymMinutesPerSession =
          _draft.goesGym ? _draft.gymMinutesPerSession : 0
      ..goesGym = _draft.goesGym
      ..workoutType = _draft.workoutType
      ..country = _draft.country
      ..dietPreference = _draft.dietPreference
      ..wakeTimeMin = _draft.wakeMin
      ..sleepTimeMin = _draft.sleepMin
      ..wakeMinByDay =
          _draft.perDaySchedule ? List<int>.from(_draft.wakeMinByDay) : []
      ..sleepMinByDay =
          _draft.perDaySchedule ? List<int>.from(_draft.sleepMinByDay) : []
      ..creatineGramsPerDay = _draft.takesSupplements ? _draft.creatineG : 0
      ..proteinScoopsPerDay =
          _draft.takesSupplements ? _draft.proteinScoops : 0
      ..proteinGramsPerDay =
          _draft.takesSupplements ? _draft.proteinGrams : 0
      ..multivitamin = _draft.takesSupplements && _draft.multivitamin
      ..otherSupplementsNote =
          _draft.takesSupplements ? _draft.otherSupp.trim() : ''
      ..bodyFocusNotes = _draft.focusNotes.trim()
      ..gymStartDate = gymStart
      ..bodyFatPct = _draft.bodyFatPct
      ..healthFlags = _draft.healthFlags
      ..restDays = _draft.restDays
      ..weighInCadence = _draft.weighInCadence
      ..weighInWeekday = _draft.weighInWeekday
      ..bmr = t.bmr
      ..tdee = t.tdee
      ..calorieTarget = t.calorieTarget
      ..restDayCalorieTarget = t.restDayCalorieTarget
      ..proteinTargetG = t.proteinG
      ..carbTargetG = t.carbG
      ..fatTargetG = t.fatG
      ..fiberTargetG = t.fiberG
      ..waterTargetMl = t.waterMl
      ..bmi = t.bmi;
    await ref.read(profileRepoProvider).save(p);
    // Kick off weigh-in reminders so the adaptive engine has data fast.
    try {
      await NotificationService.instance.scheduleWeighInReminders(
        cadence: _draft.weighInCadence,
        preferredWeekday: _draft.weighInWeekday,
      );
    } catch (_) {
      // Non-critical — user can re-enable from Reminders later.
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(page: _page, total: _totalPages, onBack: _back),
            Expanded(
              child: PageView(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _StepWelcome(onStart: _next),
                  _StepAbout(
                      draft: _draft, onChanged: () => setState(() {})),
                  _StepBody(
                      draft: _draft, onChanged: () => setState(() {})),
                  _StepGoal(
                      draft: _draft, onChanged: () => setState(() {})),
                  _StepLifestyle(
                      draft: _draft, onChanged: () => setState(() {})),
                  _StepReview(draft: _draft),
                ],
              ),
            ),
            if (_page > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _PrimaryButton(
                  label: _page == _totalPages - 1
                      ? loc.startTracking
                      : loc.continueBtn,
                  loading: _saving,
                  onTap: _saving ? null : _next,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int page;
  final int total;
  final VoidCallback onBack;
  const _TopBar({required this.page, required this.total, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: page == 0 ? null : onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: page == 0
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                final active = i <= page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: i == page ? 28 : 18,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _StepWelcome extends StatelessWidget {
  final VoidCallback onStart;
  const _StepWelcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Image.asset(
            'assets/logo/logo.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 24),
          Text(
            loc.onboardingWelcome,
            style: AppText.giantNumber.copyWith(
              fontSize: 38,
              height: 1.1,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.onboardingWelcomeSub,
            style: AppText.body.copyWith(fontSize: 15),
          ),
          const Spacer(flex: 2),
          _PrimaryButton(label: loc.getStarted, onTap: onStart),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StepAbout extends StatefulWidget {
  final _Draft draft;
  final VoidCallback onChanged;
  const _StepAbout({required this.draft, required this.onChanged});

  @override
  State<_StepAbout> createState() => _StepAboutState();
}

class _StepAboutState extends State<_StepAbout> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.aboutYouTitle, style: _StepStyles.title),
          const SizedBox(height: 8),
          Text(loc.aboutYouSubtitle,
              style: AppText.body),
          const SizedBox(height: 28),
          Text(loc.yourName, style: AppText.label),
          const SizedBox(height: 10),
          _NameField(
            controller: _name,
            onChanged: (v) {
              widget.draft.name = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 28),
          Text(loc.ageField, style: AppText.label),
          const SizedBox(height: 6),
          _BigValue(value: '${widget.draft.age}', unit: loc.years),
          _Slider(
            value: widget.draft.age.toDouble(),
            min: 13,
            max: 80,
            divisions: 67,
            onChanged: (v) {
              widget.draft.age = v.round();
              widget.onChanged();
            },
          ),
          const SizedBox(height: 24),
          Text(loc.genderField, style: AppText.label),
          const SizedBox(height: 10),
          _SegmentedRow<Gender>(
            value: widget.draft.gender,
            options: [
              (Gender.male, loc.male),
              (Gender.female, loc.female),
              (Gender.other, loc.other),
            ],
            onChanged: (g) {
              widget.draft.gender = g;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 24),
          Text(loc.countryField, style: AppText.label),
          const SizedBox(height: 6),
          Text(
              loc.coachSuggests,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          _CountryPicker(
            value: widget.draft.country,
            onChanged: (c) {
              widget.draft.country = c;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 24),
          Text(loc.dietField, style: AppText.label),
          const SizedBox(height: 10),
          _DietPicker(
            value: widget.draft.dietPreference,
            onChanged: (d) {
              widget.draft.dietPreference = d;
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  final _Draft draft;
  final VoidCallback onChanged;
  const _StepBody({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.bodyAndActivity, style: _StepStyles.title),
          const SizedBox(height: 8),
          Text(loc.bodyAndActivitySub,
              style: AppText.body),
          const SizedBox(height: 28),
          Text(loc.heightField, style: AppText.label),
          const SizedBox(height: 6),
          _BigValue(value: draft.heightCm.round().toString(), unit: loc.centimeters),
          _Slider(
            value: draft.heightCm,
            min: 130,
            max: 220,
            divisions: 90,
            onChanged: (v) {
              draft.heightCm = v;
              onChanged();
            },
          ),
          const SizedBox(height: 22),
          Text(loc.weightField, style: AppText.label),
          const SizedBox(height: 6),
          _BigValue(value: draft.weightKg.toStringAsFixed(1), unit: loc.kilograms),
          _Slider(
            value: draft.weightKg,
            min: 35,
            max: 180,
            divisions: 290,
            onChanged: (v) {
              draft.weightKg = (v * 2).round() / 2.0;
              onChanged();
            },
          ),
          const SizedBox(height: 22),
          Text(loc.activityLevel, style: AppText.label),
          const SizedBox(height: 10),
          _SegmentedColumn<ActivityLevel>(
            value: draft.activity,
            options: [
              (ActivityLevel.sedentary, loc.sedentary,
                  loc.sedentaryDesc),
              (ActivityLevel.light, loc.lightlyActive,
                  loc.lightlyActiveDesc),
              (ActivityLevel.moderate, loc.moderatelyActive,
                  loc.moderatelyActiveDesc),
              (ActivityLevel.active, loc.veryActive,
                  loc.veryActiveDesc),
              (ActivityLevel.veryActive, loc.athlete,
                  loc.athleteDesc),
            ],
            onChanged: (a) {
              draft.activity = a;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _StepGoal extends StatelessWidget {
  final _Draft draft;
  final VoidCallback onChanged;
  const _StepGoal({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.whatsYourGoal, style: _StepStyles.title),
          const SizedBox(height: 8),
          Text(loc.goalSubtitle,
              style: AppText.body),
          const SizedBox(height: 20),
          Text(loc.workoutTypeField, style: AppText.label),
          const SizedBox(height: 6),
          Text(loc.workoutTypeHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          WorkoutTypePicker(
            value: draft.workoutType,
            onChanged: (t) {
              draft.workoutType = t;
              if (!draft.showsTrainingDays) draft.restDays = const [];
              onChanged();
            },
          ),
          const SizedBox(height: 22),
          _SegmentedColumn<FitnessGoal>(
            value: draft.goal,
            options: [
              (FitnessGoal.buildMuscle, loc.buildMuscle,
                  loc.buildMuscleDesc),
              (FitnessGoal.loseFat, loc.loseFat,
                  loc.loseFatDesc),
              (FitnessGoal.recomp, loc.recomp,
                  loc.recompDesc),
              (FitnessGoal.generalFitness, loc.generalFitness,
                  loc.generalFitnessDesc),
            ],
            onChanged: (g) {
              draft.goal = g;
              onChanged();
            },
          ),
          if (draft.goal == FitnessGoal.buildMuscle &&
              _hasFatFocus(draft.focusNotes)) ...[
            const SizedBox(height: 12),
            _GoalConflictHint(
              onSwitch: () {
                draft.goal = FitnessGoal.recomp;
                onChanged();
              },
            ),
          ],
          if (draft.showsTrainingDays) ...[
            const SizedBox(height: 28),
            Text(
              switch (draft.workoutType) {
                WorkoutType.yoga => loc.yogaSessions,
                WorkoutType.homeWorkout => loc.homeWorkoutDays,
                _ => loc.strengthTrainingDays,
              },
              style: AppText.label,
            ),
            const SizedBox(height: 6),
            Text(
              switch (draft.workoutType) {
                WorkoutType.yoga => loc.yogaDaysDesc,
                WorkoutType.homeWorkout =>
                  loc.homeDaysDesc,
                _ => loc.gymDaysDesc,
              },
              style: AppText.meta.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 10),
            _DayPickerRow(
              value: draft.trainingDays,
              max: 7,
              startsAt: 1,
              onChanged: (n) {
                draft.trainingDays = n;
                onChanged();
              },
            ),
            if (draft.goesGym) ...[
              const SizedBox(height: 22),
              Text(loc.gymExperience, style: AppText.label),
              const SizedBox(height: 6),
              Text(loc.gymExperienceHelper,
                  style: AppText.meta.copyWith(fontSize: 12)),
              const SizedBox(height: 10),
              _ExperiencePicker(
                value: draft.gymMonthsAgo,
                onChanged: (m) {
                  draft.gymMonthsAgo = m;
                  onChanged();
                },
              ),
              const SizedBox(height: 22),
              Text(loc.gymMinutes, style: AppText.label),
              const SizedBox(height: 6),
              Text(loc.gymMinutesHelper,
                  style: AppText.meta.copyWith(fontSize: 12)),
              const SizedBox(height: 10),
              _BigValue(value: '${draft.gymMinutesPerSession}', unit: loc.minutes),
              _Slider(
                value: draft.gymMinutesPerSession.toDouble(),
                min: 20,
                max: 150,
                divisions: 26,
                onChanged: (v) {
                  draft.gymMinutesPerSession = (v / 5).round() * 5;
                  onChanged();
                },
              ),
            ],
          ],
          const SizedBox(height: 22),
          _DailyKmField(
            label: loc.walkingKmDay,
            initial: draft.walkingKmPerDay,
            onChanged: (v) {
              draft.walkingKmPerDay = (v * 2).round() / 2.0;
              onChanged();
            },
          ),
          const SizedBox(height: 6),
          Text(loc.walkingHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 22),
          _DailyKmField(
            label: loc.runningKmDay,
            initial: draft.runningKmPerDay,
            onChanged: (v) {
              draft.runningKmPerDay = (v * 2).round() / 2.0;
              onChanged();
            },
          ),
          const SizedBox(height: 6),
          Text(
              loc.runningHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 22),
          Text(loc.bodyFocusField, style: AppText.label),
          const SizedBox(height: 6),
          Text(
              loc.bodyFocusHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 12),
          BodyFocusGrid(
            selected: FocusNotesUtil.selectedPresets(draft.focusNotes, focusPresets(loc)),
            onToggle: (label) {
              draft.focusNotes =
                  FocusNotesUtil.togglePreset(draft.focusNotes, label, focusPresets(loc));
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              minLines: 1,
              maxLines: 2,
              cursorColor: AppColors.accent,
              controller:
                  TextEditingController(text: draft.focusNotes)
                    ..selection = TextSelection.collapsed(
                        offset: draft.focusNotes.length),
              onChanged: (v) {
                draft.focusNotes = v;
              },
              style: AppText.body.copyWith(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                hintText: loc.addAnythingElse,
                hintStyle: AppText.body.copyWith(
                    color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-tier countries we explicitly support for cuisine matching. The
/// "Other" path is open text. Ordered by app-user concentration: South
/// Asia first (where the dev is), then the rest alphabetically.
const List<(String, String)> _commonCountries = [
  ('NP', 'Nepal'),
  ('IN', 'India'),
  ('BD', 'Bangladesh'),
  ('PK', 'Pakistan'),
  ('LK', 'Sri Lanka'),
  ('AU', 'Australia'),
  ('BR', 'Brazil'),
  ('CA', 'Canada'),
  ('CN', 'China'),
  ('DE', 'Germany'),
  ('FR', 'France'),
  ('ID', 'Indonesia'),
  ('IT', 'Italy'),
  ('JP', 'Japan'),
  ('KR', 'South Korea'),
  ('MX', 'Mexico'),
  ('MY', 'Malaysia'),
  ('PH', 'Philippines'),
  ('SG', 'Singapore'),
  ('TH', 'Thailand'),
  ('TR', 'Turkey'),
  ('UK', 'United Kingdom'),
  ('US', 'United States'),
  ('VN', 'Vietnam'),
];

class _CountryPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CountryPicker({required this.value, required this.onChanged});

  static String? _localizedName(AppLocalizations loc, String code) => switch (code) {
        'NP' => loc.nepal,
        'IN' => loc.india,
        'BD' => loc.bangladesh,
        'PK' => loc.pakistan,
        'LK' => loc.sriLanka,
        'AU' => loc.australia,
        'BR' => loc.brazil,
        'CA' => loc.canada,
        'CN' => loc.china,
        'DE' => loc.germany,
        'FR' => loc.france,
        'ID' => loc.indonesia,
        'IT' => loc.italy,
        'JP' => loc.japan,
        'KR' => loc.southKorea,
        'MX' => loc.mexico,
        'MY' => loc.malaysia,
        'PH' => loc.philippines,
        'SG' => loc.singapore,
        'TH' => loc.thailand,
        'TR' => loc.turkey,
        'UK' => loc.unitedKingdom,
        'US' => loc.unitedStates,
        'VN' => loc.vietnam,
        _ => null,
      };

  String _displayLabel(AppLocalizations loc) {
    if (value.isEmpty) return loc.pickCountry;
    final match =
        _commonCountries.where((c) => c.$1 == value).toList();
    if (match.isNotEmpty) {
      final name = _localizedName(loc, match.first.$1);
      if (name != null) return name;
      return match.first.$2;
    }
    return value;
  }

  Future<void> _open(BuildContext context, AppLocalizations loc) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _CountrySheet(initial: value, loc: loc),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final set = value.isNotEmpty;
    return GestureDetector(
      onTap: () => _open(context, loc),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: set ? AppColors.accent : AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded,
                size: 18,
                color: set ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_displayLabel(loc),
                  style: AppText.body.copyWith(
                      color:
                          set ? AppColors.textPrimary : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  final String initial;
  final AppLocalizations loc;
  const _CountrySheet({required this.initial, required this.loc});

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(String, String)> _filtered() {
    final q = _search.text.trim().toLowerCase();
    final loc = widget.loc;
    final localized = _commonCountries.map((c) {
      final name = _CountryPicker._localizedName(loc, c.$1) ?? c.$2;
      return (c.$1, name);
    }).toList();
    if (q.isEmpty) return localized;
    return _commonCountries
        .where((c) =>
            c.$2.toLowerCase().contains(q) || c.$1.toLowerCase() == q)
        .map((c) => (c.$1, _CountryPicker._localizedName(loc, c.$1) ?? c.$2))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final list = _filtered();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(loc.country, style: AppText.sectionTitle),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _search,
              autofocus: false,
              cursorColor: AppColors.accent,
              onChanged: (_) => setState(() {}),
              style: AppText.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                hintText: loc.searchDots,
                hintStyle: AppText.body.copyWith(
                    color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final selected = c.$1 == widget.initial;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(c.$1),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.fromLTRB(4, 14, 4, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text(c.$1,
                              style: AppText.label.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c.$2,
                              style: AppText.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        if (selected)
                          Icon(Icons.check_rounded,
                              size: 18, color: AppColors.accent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DietPicker extends StatelessWidget {
  final DietPreference value;
  final ValueChanged<DietPreference> onChanged;
  const _DietPicker({required this.value, required this.onChanged});

  static List<(DietPreference, String)> _localizedOptions(AppLocalizations loc) => [
    (DietPreference.omnivore, loc.omnivore),
    (DietPreference.vegetarian, loc.vegetarian),
    (DietPreference.vegan, loc.vegan),
    (DietPreference.pescatarian, loc.pescatarian),
    (DietPreference.keto, loc.keto),
    (DietPreference.halal, loc.halal),
    (DietPreference.kosher, loc.kosher),
    (DietPreference.jain, loc.jain),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _localizedOptions(loc).map((o) {
        final on = o.$1 == value;
        return GestureDetector(
          onTap: () => onChanged(o.$1),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? AppColors.accent : AppColors.stroke,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Text(o.$2,
                style: TextStyle(
                  color: on ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                )),
          ),
        );
      }).toList(),
    );
  }
}


class _DailyKmField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;
  const _DailyKmField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_DailyKmField> createState() => _DailyKmFieldState();
}

class _DailyKmFieldState extends State<_DailyKmField> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(
      text: widget.initial <= 0
          ? ''
          : (widget.initial == widget.initial.roundToDouble()
              ? widget.initial.toInt().toString()
              : widget.initial.toStringAsFixed(1)),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.label.copyWith(fontSize: 11)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  cursorColor: AppColors.accent,
                  onChanged: (v) {
                    widget.onChanged(double.tryParse(v.trim()) ?? 0);
                  },
                  style: AppText.body
                      .copyWith(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                    hintText: '0',
                    hintStyle: AppText.body.copyWith(
                        color: AppColors.textTertiary, fontSize: 15),
                  ),
                ),
              ),
              Text(loc.kilometers + ' / day',
                  style: AppText.meta.copyWith(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExperiencePicker extends StatelessWidget {
  // null = never lifted; otherwise months-ago since starting (capped at 60+).
  final int? value;
  final ValueChanged<int?> onChanged;
  const _ExperiencePicker({required this.value, required this.onChanged});

  static List<(int?, String, String)> _localizedOptions(AppLocalizations loc) => [
    (null, loc.never, loc.newToLifting),
    (0, loc.lessThan1Month, loc.justStarted),
    (3, loc.threeToSixMonths, loc.newbieGains),
    (12, loc.sixTo24Months, loc.intermediate),
    (36, loc.twoPlusYears, loc.advanced),
  ];

  bool _matches((int?, String, String) opt) {
    final v = value;
    if (opt.$1 == null && v == null) return true;
    if (opt.$1 == null || v == null) return false;
    if (opt.$1 == 0) return v < 1;
    if (opt.$1 == 3) return v >= 1 && v < 6;
    if (opt.$1 == 12) return v >= 6 && v < 24;
    if (opt.$1 == 36) return v >= 24;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _localizedOptions(loc).map((o) {
        final selected = _matches(o);
        return GestureDetector(
          onTap: () => onChanged(o.$1),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.stroke,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o.$2,
                    style: TextStyle(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
                const SizedBox(height: 2),
                Text(o.$3,
                    style: AppText.meta.copyWith(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

bool _hasFatFocus(String notes) {
  final lower = notes.toLowerCase();
  return lower.contains('belly fat') || lower.contains('skinny fat');
}

class _GoalConflictHint extends StatelessWidget {
  final VoidCallback onSwitch;
  const _GoalConflictHint({required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.recompMaySuit,
                  style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.recompHintBody,
                  style: AppText.meta.copyWith(fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onSwitch,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    loc.switchToRecomp,
                    style: AppText.label.copyWith(
                        color: AppColors.accent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPickerRow extends StatelessWidget {
  final int value;
  final int max;
  final int startsAt;
  final ValueChanged<int> onChanged;
  const _DayPickerRow({
    required this.value,
    required this.max,
    required this.startsAt,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = max - startsAt + 1;
    return Row(
      children: List.generate(count, (i) {
        final n = startsAt + i;
        final active = value == n;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < count - 1 ? 6 : 0),
            child: GestureDetector(
              onTap: () => onChanged(n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? AppColors.accent : AppColors.stroke,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: active ? AppColors.onAccent : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StepLifestyle extends StatelessWidget {
  final _Draft draft;
  final VoidCallback onChanged;
  const _StepLifestyle({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.dailyRhythm, style: _StepStyles.title),
          const SizedBox(height: 8),
          Text(
              loc.dailyRhythmSub,
              style: AppText.body),
          const SizedBox(height: 24),
          Text(loc.wakeAndSleep, style: AppText.label),
          const SizedBox(height: 10),
          if (!draft.perDaySchedule)
            Row(
              children: [
                Expanded(
                  child: _TimePickerTile(
                    label: loc.wake,
                    minutes: draft.wakeMin,
                    onChanged: (m) {
                      draft.wakeMin = m;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePickerTile(
                    label: loc.sleep,
                    minutes: draft.sleepMin,
                    onChanged: (m) {
                      draft.sleepMin = m;
                      onChanged();
                    },
                  ),
                ),
              ],
            )
          else
            _PerDayScheduleEditor(
              wakeMinByDay: draft.wakeMinByDay,
              sleepMinByDay: draft.sleepMinByDay,
              onChanged: onChanged,
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              // Switching ON seeds the per-day arrays from the single
              // values so the user sees their current pick on every row
              // and can tweak only the days that differ.
              if (!draft.perDaySchedule) {
                draft.wakeMinByDay = List<int>.filled(7, draft.wakeMin);
                draft.sleepMinByDay = List<int>.filled(7, draft.sleepMin);
              }
              draft.perDaySchedule = !draft.perDaySchedule;
              onChanged();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: draft.perDaySchedule
                    ? AppColors.accent.withValues(alpha: 0.10)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: draft.perDaySchedule
                      ? AppColors.accent
                      : AppColors.stroke,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    draft.perDaySchedule
                        ? Icons.check_circle_rounded
                        : Icons.calendar_view_week_rounded,
                    size: 18,
                    color: draft.perDaySchedule
                        ? AppColors.accent
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      draft.perDaySchedule
                          ? loc.perDaySchedule
                          : loc.differentTimeEachDay,
                      style: AppText.body.copyWith(
                        color: draft.perDaySchedule
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (draft.goesGym) ...[
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(child: Text(loc.supplementsField, style: AppText.label)),
              GestureDetector(
                onTap: () {
                  draft.takesSupplements = !draft.takesSupplements;
                  onChanged();
                },
                child: Text(
                  draft.takesSupplements ? loc.iDont : loc.skipIDont,
                  style: AppText.label.copyWith(
                      color: AppColors.accent, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              loc.creatineNeedsWater,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 12),
          if (!draft.takesSupplements)
            GestureDetector(
              onTap: () {
                draft.takesSupplements = true;
                onChanged();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Text(loc.iTakeSome,
                        style: AppText.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledNumField(
                  label: loc.creatineGD,
                  hint: loc.eG5,
                  initial: draft.creatineG,
                  onChanged: (n) {
                    draft.creatineG = n;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledNumField(
                        label: loc.proteinScoops,
                        hint: loc.perDay,
                        initial: draft.proteinScoops,
                        onChanged: (n) {
                          draft.proteinScoops = n;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LabeledNumField(
                        label: loc.proteinGrams,
                        hint: loc.perDay,
                        initial: draft.proteinGrams,
                        onChanged: (n) {
                          draft.proteinGrams = n;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    draft.multivitamin = !draft.multivitamin;
                    onChanged();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: draft.multivitamin
                          ? AppColors.accent.withValues(alpha: 0.10)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: draft.multivitamin
                            ? AppColors.accent
                            : AppColors.stroke,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          draft.multivitamin
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          size: 18,
                          color: draft.multivitamin
                              ? AppColors.accent
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Text(loc.multivitamin,
                            style: AppText.body.copyWith(
                              color: draft.multivitamin
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(loc.otherOptional, style: AppText.label),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    cursorColor: AppColors.accent,
                    controller: TextEditingController(text: draft.otherSupp)
                      ..selection = TextSelection.collapsed(
                          offset: draft.otherSupp.length),
                    onChanged: (v) {
                      draft.otherSupp = v;
                    },
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      hintText: loc.otherSupplementsHint,
                      hintStyle: AppText.body.copyWith(
                          color: AppColors.textTertiary, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (draft.goesGym) ...[
            const SizedBox(height: 26),
            Text(loc.restDaysField, style: AppText.label),
            const SizedBox(height: 6),
            Text(
                loc.restDaysHelper,
                style: AppText.meta.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            _WeekdayChips(
              selected: draft.restDays.toSet(),
              onChanged: (s) {
                draft.restDays = s.toList()..sort();
                // Default weigh-in to day before first rest day.
                if (draft.weighInWeekday == null && s.isNotEmpty) {
                  final first = (s.toList()..sort()).first;
                  draft.weighInWeekday = first == 1 ? 7 : first - 1;
                }
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 22),
          Text(loc.weighInCadence, style: AppText.label),
          const SizedBox(height: 6),
          Text(
              loc.weighInHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          _CadencePicker(
            value: draft.weighInCadence,
            onChanged: (c) {
              draft.weighInCadence = c;
              onChanged();
            },
          ),
          const SizedBox(height: 22),
          Text(loc.bodyFatOptional, style: AppText.label),
          const SizedBox(height: 6),
          Text(
              loc.bodyFatHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          _BodyFatField(
            initial: draft.bodyFatPct,
            onChanged: (v) {
              draft.bodyFatPct = v;
              onChanged();
            },
          ),
          const SizedBox(height: 26),
          Text(loc.healthContextOptional, style: AppText.label),
          const SizedBox(height: 6),
          Text(
              loc.healthContextHelper,
              style: AppText.meta.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          _HealthFlagGrid(
            selected: draft.healthFlags.toSet(),
            onToggle: (f) {
              if (draft.healthFlags.contains(f)) {
                draft.healthFlags = List.of(draft.healthFlags)..remove(f);
              } else {
                draft.healthFlags = List.of(draft.healthFlags)..add(f);
              }
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;
  const _TimePickerTile({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  String _formatted(AppLocalizations loc) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? loc.pm : loc.am;
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: AppColors.accent,
                  onPrimary: AppColors.onAccent,
                  surface: AppColors.surface,
                  onSurface: AppColors.textPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => _pick(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppText.label.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Text(_formatted(loc),
                style: AppText.bigNumber.copyWith(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

/// 7-day wake/sleep grid. Each row is a weekday with its own pair of
/// time-picker tiles. Mutates the parent's [wakeMinByDay] /
/// [sleepMinByDay] lists in place and pings [onChanged] so the parent's
/// `setState` re-renders. Reused from both onboarding and settings.
class _PerDayScheduleEditor extends StatelessWidget {
  final List<int> wakeMinByDay;
  final List<int> sleepMinByDay;
  final VoidCallback onChanged;
  const _PerDayScheduleEditor({
    required this.wakeMinByDay,
    required this.sleepMinByDay,
    required this.onChanged,
  });

  static List<String> _localizedDays(AppLocalizations loc) => [
    loc.monday, loc.tuesday, loc.wednesday, loc.thursday, loc.friday, loc.saturday, loc.sunday,
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final days = _localizedDays(loc);
    return Column(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(days[i],
                    style: AppText.label.copyWith(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimePickerTile(
                  label: loc.wake,
                  minutes: wakeMinByDay[i],
                  onChanged: (m) {
                    wakeMinByDay[i] = m;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimePickerTile(
                  label: loc.sleep,
                  minutes: sleepMinByDay[i],
                  onChanged: (m) {
                    sleepMinByDay[i] = m;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          if (i < 6) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _WeekdayChips extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  const _WeekdayChips({required this.selected, required this.onChanged});

  static List<(int, String)> _localizedDays(AppLocalizations loc) => [
    (1, loc.monday),
    (2, loc.tuesday),
    (3, loc.wednesday),
    (4, loc.thursday),
    (5, loc.friday),
    (6, loc.saturday),
    (7, loc.sunday),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _localizedDays(loc).map((d) {
        final on = selected.contains(d.$1);
        return GestureDetector(
          onTap: () {
            final next = Set<int>.of(selected);
            if (on) {
              next.remove(d.$1);
            } else {
              if (next.length >= 3) return;
              next.add(d.$1);
            }
            onChanged(next);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? AppColors.accent : AppColors.stroke,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Text(d.$2,
                style: TextStyle(
                  color: on ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                )),
          ),
        );
      }).toList(),
    );
  }
}

class _CadencePicker extends StatelessWidget {
  final WeighInCadence value;
  final ValueChanged<WeighInCadence> onChanged;
  const _CadencePicker({required this.value, required this.onChanged});

  static List<(WeighInCadence, String)> _localizedOptions(AppLocalizations loc) => [
    (WeighInCadence.daily, loc.daily),
    (WeighInCadence.everyOtherDay, loc.everyOtherDay),
    (WeighInCadence.twiceAWeek, loc.twicePerWeek),
    (WeighInCadence.weekly, loc.weekly),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _localizedOptions(loc).map((o) {
        final on = o.$1 == value;
        return GestureDetector(
          onTap: () => onChanged(o.$1),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? AppColors.accent : AppColors.stroke,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Text(o.$2,
                style: TextStyle(
                  color: on ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                )),
          ),
        );
      }).toList(),
    );
  }
}

class _BodyFatField extends StatefulWidget {
  final double? initial;
  final ValueChanged<double?> onChanged;
  const _BodyFatField({required this.initial, required this.onChanged});

  @override
  State<_BodyFatField> createState() => _BodyFatFieldState();
}

class _BodyFatFieldState extends State<_BodyFatField> {
  late final TextEditingController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              cursorColor: AppColors.accent,
              onChanged: (v) {
                final n = double.tryParse(v.trim());
                widget.onChanged(n);
              },
              style: AppText.body
                  .copyWith(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'e.g. 18',
                hintStyle: AppText.body
                    .copyWith(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ),
          Text(loc.key1,
              style: AppText.meta.copyWith(
                  fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _HealthFlagGrid extends StatelessWidget {
  final Set<HealthFlag> selected;
  final ValueChanged<HealthFlag> onToggle;
  const _HealthFlagGrid({required this.selected, required this.onToggle});

  static List<(HealthFlag, String, bool)> _localizedOptions(AppLocalizations loc) => [
    (HealthFlag.pregnant, loc.pregnant, true),
    (HealthFlag.breastfeeding, loc.breastfeeding, true),
    (HealthFlag.eatingDisorderHistory, loc.eatingDisorderHistory, true),
    (HealthFlag.t1Diabetes, loc.type1Diabetes, true),
    (HealthFlag.recoveringFromInjury, loc.recoveringFromInjury, false),
    (HealthFlag.t2Diabetes, loc.type2Diabetes, false),
    (HealthFlag.pcos, loc.pcos, false),
    (HealthFlag.hypothyroid, loc.hypothyroid, false),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _localizedOptions(loc).map((o) {
        final on = selected.contains(o.$1);
        return GestureDetector(
          onTap: () => onToggle(o.$1),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? AppColors.accent : AppColors.stroke,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (o.$3)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 12,
                        color: on
                            ? AppColors.accent
                            : AppColors.textTertiary),
                  ),
                Text(o.$2,
                    style: TextStyle(
                      color:
                          on ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LabeledNumField extends StatefulWidget {
  final String label;
  final String hint;
  final int initial;
  final ValueChanged<int> onChanged;
  const _LabeledNumField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_LabeledNumField> createState() => _LabeledNumFieldState();
}

class _LabeledNumFieldState extends State<_LabeledNumField> {
  late final TextEditingController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(
        text: widget.initial > 0 ? widget.initial.toString() : '');
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.label.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _ctl,
            keyboardType: TextInputType.number,
            cursorColor: AppColors.accent,
            onChanged: (v) => widget.onChanged(int.tryParse(v.trim()) ?? 0),
            style: AppText.body.copyWith(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: widget.hint,
              hintStyle: AppText.body
                  .copyWith(color: AppColors.textTertiary, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepReview extends StatelessWidget {
  final _Draft draft;
  const _StepReview({required this.draft});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final t = HealthMath.compute(
      gender: draft.gender,
      age: draft.age,
      weightKg: draft.weightKg,
      heightCm: draft.heightCm,
      activity: draft.activity,
      goal: draft.goal,
      cardioSessionsPerWeek: draft.cardioDays,
      walkingKmPerDay: draft.walkingKmPerDay,
      runningKmPerWeek: (draft.runningKmPerDay * 7).roundToDouble(),
      gymMinutesPerSession:
          draft.goesGym ? draft.gymMinutesPerSession : 0,
      strengthDaysPerWeek: draft.goesGym ? draft.trainingDays : 0,
      bodyFocusNotes: draft.focusNotes,
      creatineGramsPerDay: draft.goesGym ? draft.creatineG : 0,
      proteinScoopsPerDay: draft.goesGym ? draft.proteinScoops : 0,
      gymStartDate: draft.gymMonthsAgo == null || !draft.goesGym
          ? null
          : DateTime(DateTime.now().year,
              DateTime.now().month - draft.gymMonthsAgo!, DateTime.now().day),
      bodyFatPct: draft.bodyFatPct,
      healthFlags: draft.healthFlags,
      restDays: draft.restDays,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.yourDailyTargets, style: _StepStyles.title),
          const SizedBox(height: 8),
          Text(loc.editLater,
              style: AppText.body),
          const SizedBox(height: 26),
          if (t.warnConsultProfessional) ...[
            _ProConsultWarning(flags: draft.healthFlags),
            const SizedBox(height: 14),
          ],
          _ReviewBigCard(
            label: loc.caloriesLabel,
            value: '${t.calorieTarget}',
            unit: loc.kcal,
            accent: AppColors.calorieFrom,
          ),
          if (draft.restDays.isNotEmpty &&
              t.restDayCalorieTarget != t.calorieTarget) ...[
            const SizedBox(height: 10),
            _RestDayHint(
              trainKcal: t.calorieTarget,
              restKcal: t.restDayCalorieTarget,
              days: draft.restDays,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReviewSmallCard(
                  label: loc.protein,
                  value: '${t.proteinG}g',
                  accent: AppColors.protein,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReviewSmallCard(
                  label: loc.carbs,
                  value: '${t.carbG}g',
                  accent: AppColors.carbs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReviewSmallCard(
                  label: loc.fat,
                  value: '${t.fatG}g',
                  accent: AppColors.fat,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ReviewSmallCard(
                  label: loc.water,
                  value: '${(t.waterMl / 1000).toStringAsFixed(1)}L',
                  accent: AppColors.water,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReviewSmallCard(
                  label: loc.fiber,
                  value: '${t.fiberG}g',
                  accent: AppColors.fiber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReviewSmallCard(
                  label: loc.bmi,
                  value: t.bmi.toStringAsFixed(1),
                  accent: AppColors.accent,
                  caption: HealthMath.bmiContext(context, t.bmi),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AdvisoryCard(draft: draft, targets: t),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.floorsSafety,
                    style: AppText.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisoryCard extends ConsumerStatefulWidget {
  final _Draft draft;
  final ComputedTargets targets;
  const _AdvisoryCard({required this.draft, required this.targets});

  @override
  ConsumerState<_AdvisoryCard> createState() => _AdvisoryCardState();
}

class _AdvisoryCardState extends ConsumerState<_AdvisoryCard> {
  bool _loading = false;
  String? _text;
  String? _error;

  String _summary() {
    final d = widget.draft;
    final t = widget.targets;
    final wakeH = d.wakeMin ~/ 60;
    final wakeM = (d.wakeMin % 60).toString().padLeft(2, '0');
    final sleepH = d.sleepMin ~/ 60;
    final sleepM = (d.sleepMin % 60).toString().padLeft(2, '0');
    final supp = d.takesSupplements
        ? [
            if (d.creatineG > 0) '${d.creatineG}g creatine',
            if (d.proteinScoops > 0) '${d.proteinScoops} protein scoop(s)',
            if (d.proteinGrams > 0) '${d.proteinGrams}g protein powder',
            if (d.multivitamin) 'multivitamin',
            if (d.otherSupp.trim().isNotEmpty) d.otherSupp.trim(),
          ].join(', ')
        : 'none';
    return [
      'Age: ${d.age}, ${d.gender.name}, ${d.heightCm.round()}cm, ${d.weightKg.toStringAsFixed(1)}kg (BMI ${t.bmi.toStringAsFixed(1)})',
      if (d.country.isNotEmpty) 'Country: ${d.country}',
      'Diet preference: ${d.dietPreference.name}',
      'Workout type: ${d.workoutType.name}',
      'Activity label: ${d.activity.name}',
      if (d.showsTrainingDays)
        '${d.workoutType == WorkoutType.yoga ? "Yoga" : d.workoutType == WorkoutType.homeWorkout ? "Home workout" : "Strength"}: ${d.trainingDays}d/wk${d.goesGym ? " x ${d.gymMinutesPerSession}min" : ""}',
      if (d.gymMonthsAgo != null)
        'Gym experience: ~${d.gymMonthsAgo} months',
      'Walking: ${d.walkingKmPerDay.toStringAsFixed(1)} km/day',
      'Running: ${d.runningKmPerDay.toStringAsFixed(1)} km/day',
      if (d.restDays.isNotEmpty) 'Rest days: ${d.restDays.join(",")}',
      'Goal: ${d.goal.name}',
      'Body focus: ${d.focusNotes.isEmpty ? "none" : d.focusNotes}',
      'Sleep window: $wakeH:$wakeM to $sleepH:$sleepM',
      'Supplements: $supp',
      if (d.bodyFatPct != null) 'Body fat: ${d.bodyFatPct}%',
      if (d.healthFlags.isNotEmpty)
        'Health flags: ${d.healthFlags.map((f) => f.name).join(", ")}',
      '',
      'Computed targets:',
      'Calories ${t.calorieTarget} kcal, Protein ${t.proteinG}g, Carbs ${t.carbG}g, Fat ${t.fatG}g, Fiber ${t.fiberG}g, Water ${(t.waterMl / 1000).toStringAsFixed(1)}L',
      'BMR ${t.bmr.round()}, TDEE ${t.tdee.round()}',
    ].join('\n');
  }

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ai = ref.read(aiServiceProvider);
      final text = await ai.targetsAdvisory(profileSummary: _summary());
      if (!mounted) return;
      setState(() {
        _text = text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_text != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(loc.coachSays,
                    style: AppText.label.copyWith(
                        color: AppColors.accent, letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 10),
            Text(_text!,
                style: AppText.body
                    .copyWith(fontSize: 13.5, height: 1.45)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _loading ? null : _fetch,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loading
                        ? loc.askingCoach
                        : (_error != null
                            ? loc.couldntReachCoach
                            : loc.getCoachTake),
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _error ??
                        loc.coachSecondOpinion,
                    style: AppText.meta.copyWith(fontSize: 11.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StepStyles {
  static TextStyle get title => AppText.giantNumber.copyWith(
        fontSize: 28,
        height: 1.1,
        letterSpacing: -0.6,
      );
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        style: AppText.bigNumber.copyWith(fontSize: 18),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          hintText: loc.howShouldWeGreet,
          hintStyle: AppText.body.copyWith(fontSize: 15),
        ),
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  final String value;
  final String unit;
  const _BigValue({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: AppText.giantNumber.copyWith(fontSize: 44)),
        const SizedBox(width: 6),
        Text(unit,
            style: AppText.meta.copyWith(
                fontSize: 16, color: AppColors.textTertiary)),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _Slider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceHigh,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  const _SegmentedRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((o) {
          final active = o.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  o.$2,
                  style: TextStyle(
                    color: active ? AppColors.onAccent : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SegmentedColumn<T> extends StatelessWidget {
  final T value;
  final List<(T, String, String)> options;
  final ValueChanged<T> onChanged;
  const _SegmentedColumn({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((o) {
        final active = o.$1 == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? AppColors.accent : AppColors.stroke,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppColors.accent : Colors.transparent,
                      border: Border.all(
                        color: active
                            ? AppColors.accent
                            : AppColors.textTertiary,
                        width: 1.5,
                      ),
                    ),
                    child: active
                        ? Icon(Icons.check_rounded,
                            size: 14, color: AppColors.onAccent)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.$2,
                            style: AppText.sectionTitle
                                .copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(o.$3,
                            style: AppText.body.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewBigCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  const _ReviewBigCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: AppText.label),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppText.giantNumber.copyWith(fontSize: 44)),
              const SizedBox(width: 6),
              Text(unit,
                  style: AppText.meta.copyWith(
                      fontSize: 14, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewSmallCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final String? caption;
  const _ReviewSmallCard({
    required this.label,
    required this.value,
    required this.accent,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: AppText.meta.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppText.bigNumber.copyWith(fontSize: 19)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style: AppText.meta.copyWith(
                    fontSize: 11, color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.onAccent),
              )
            : Text(
                label,
                style: TextStyle(
                  color: AppColors.onAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}

class _ProConsultWarning extends StatelessWidget {
  final List<HealthFlag> flags;
  const _ProConsultWarning({required this.flags});

  String _label(AppLocalizations loc, HealthFlag f) => switch (f) {
        HealthFlag.pregnant => loc.warningPregnancy,
        HealthFlag.breastfeeding => loc.warningBreastfeeding,
        HealthFlag.eatingDisorderHistory => loc.warningEatingDisorder,
        HealthFlag.t1Diabetes => loc.warningType1Diabetes,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final critical = flags
        .where((f) =>
            f == HealthFlag.pregnant ||
            f == HealthFlag.breastfeeding ||
            f == HealthFlag.eatingDisorderHistory ||
            f == HealthFlag.t1Diabetes)
        .map((f) => _label(loc, f))
        .where((s) => s.isNotEmpty)
        .toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.medical_information_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.talkToProfessional,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'These numbers are generic and may not be safe for your situation (${critical.join(", ")}). Confirm calorie + macro targets with a doctor or registered dietitian before relying on them.',
                  style:
                      AppText.meta.copyWith(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestDayHint extends StatelessWidget {
  final int trainKcal;
  final int restKcal;
  final List<int> days;
  const _RestDayHint({
    required this.trainKcal,
    required this.restKcal,
    required this.days,
  });

  static List<String> _localizedNames(AppLocalizations loc) => [loc.monday, loc.tuesday, loc.wednesday, loc.thursday, loc.friday, loc.saturday, loc.sunday];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final names = _localizedNames(loc);
    final dayLabels = days.map((d) => names[d - 1]).join(', ');
    final delta = trainKcal - restKcal;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'On rest days ($dayLabels): aim for ~$restKcal kcal (−$delta vs training).',
              style: AppText.body.copyWith(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
