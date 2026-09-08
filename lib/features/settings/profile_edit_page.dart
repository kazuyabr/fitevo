// ignore_for_file: use_null_aware_elements
// (isar_generator's bundled analyzer doesn't parse `'key': ?value` yet.)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_math.dart';
import '../../data/models/enums.dart';
import '../../data/models/profile.dart';
import '../../state/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/km_input_field.dart';
import '../../widgets/skeleton.dart';
import '../workout/workout_type_picker.dart';

/// Curated body-focus presets. Each is a short tag + a one-line description
/// that helps the user understand what it covers. Tapping a chip toggles it
/// in the notes field (comma-joined). Users can also type their own.
const List<(String, String)> _focusPresets = [
  ('Skinny arms', 'Weak upper body, need more muscle'),
  ('Belly fat', 'Carry weight around the waist'),
  ('Skinny fat', 'Average weight but low muscle tone'),
  ('Lower body heavy', 'Wider hips / thighs, slim upper'),
  ('Upper body heavy', 'Broad shoulders, slim lower body'),
  ('Athletic', 'Already toned, want maintenance'),
  ('Overall lean', 'Want to gain muscle everywhere'),
  ('Skinny legs', 'Thin legs, need lower-body strength'),
];

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late TextEditingController _name;
  late TextEditingController _age;
  late TextEditingController _heightCm;
  late TextEditingController _weightKg;
  late TextEditingController _trainingDays;
  late TextEditingController _cardioDays;
  late TextEditingController _walkingKm;
  late TextEditingController _runningKm;
  late TextEditingController _gymMin;
  late TextEditingController _creatineG;
  late TextEditingController _proteinScoops;
  late TextEditingController _proteinGrams;
  late TextEditingController _otherSupp;
  late TextEditingController _focusNotes;
  bool _multivitamin = false;
  int _wakeMin = 420;
  int _sleepMin = 1380;
  // Per-day toggle + arrays. When _perDaySchedule is false, only
  // _wakeMin / _sleepMin are saved; the arrays clear on save.
  bool _perDaySchedule = false;
  List<int> _wakeMinByDay = List<int>.filled(7, 420);
  List<int> _sleepMinByDay = List<int>.filled(7, 1380);
  DateTime? _gymStartDate;
  double? _bodyFatPct;
  List<HealthFlag> _healthFlags = [];
  List<int> _restDays = [];
  WeighInCadence _cadence = WeighInCadence.weekly;
  int? _weighInWeekday;
  bool _goesGym = true;
  CyclePhase _cyclePhase = CyclePhase.unknown;
  String _country = '';
  DietPreference _dietPreference = DietPreference.omnivore;

  late TextEditingController _calOverride;
  late TextEditingController _proteinOverride;
  late TextEditingController _carbOverride;
  late TextEditingController _fatOverride;
  late TextEditingController _fiberOverride;
  late TextEditingController _waterOverride;

  Gender _gender = Gender.male;
  ActivityLevel _activity = ActivityLevel.moderate;
  FitnessGoal _goal = FitnessGoal.generalFitness;
  WorkoutType _workoutType = WorkoutType.gym;
  Profile? _profile;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _age = TextEditingController();
    _heightCm = TextEditingController();
    _weightKg = TextEditingController();
    _trainingDays = TextEditingController();
    _cardioDays = TextEditingController();
    _walkingKm = TextEditingController();
    _runningKm = TextEditingController();
    _gymMin = TextEditingController();
    _creatineG = TextEditingController();
    _proteinScoops = TextEditingController();
    _proteinGrams = TextEditingController();
    _otherSupp = TextEditingController();
    _focusNotes = TextEditingController();
    _calOverride = TextEditingController();
    _proteinOverride = TextEditingController();
    _carbOverride = TextEditingController();
    _fatOverride = TextEditingController();
    _fiberOverride = TextEditingController();
    _waterOverride = TextEditingController();
    _load();
  }

  /// Sanitises an int that may be Isar's "missing field" sentinel value
  /// for existing rows when a new int field was added to the schema.
  int _safeInt(int value, {int min = 0, int max = 14}) {
    if (value < min || value > max) return min;
    return value;
  }

  double _safeDouble(double value, {double min = 0, double max = 1000}) {
    if (value.isNaN || value < min || value > max) return min;
    return value;
  }

  Future<void> _load() async {
    Profile? p;
    try {
      p = await ref.read(profileRepoProvider).getCurrent();
    } catch (_) {
      p = null;
    }
    if (!mounted) return;
    if (p == null) {
      // No profile row yet (e.g. brand-new install, corrupted DB, or
      // Isar was cleared). Bail cleanly instead of spinning forever.
      setState(() => _loaded = true);
      return;
    }
    _profile = p;
    _name.text = p.displayName;
    _age.text = p.age.toString();
    _heightCm.text = p.heightCm.toStringAsFixed(0);
    _weightKg.text = p.weightKg.toStringAsFixed(1);
    _trainingDays.text =
        _safeInt(p.trainingDaysPerWeek, min: 0, max: 7).toString();
    _cardioDays.text =
        _safeInt(p.cardioSessionsPerWeek, min: 0, max: 7).toString();
    _walkingKm.text = _safeDouble(p.walkingKmPerDay, max: 30).toStringAsFixed(1);
    _runningKm.text =
        _safeDouble(p.runningKmPerWeek, max: 100).toStringAsFixed(0);
    _gymMin.text =
        _safeInt(p.gymMinutesPerSession, min: 20, max: 180).toString();
    _creatineG.text =
        _safeInt(p.creatineGramsPerDay, min: 0, max: 20).toString();
    _proteinScoops.text =
        _safeInt(p.proteinScoopsPerDay, min: 0, max: 6).toString();
    _proteinGrams.text =
        _safeInt(p.proteinGramsPerDay, min: 0, max: 400).toString();
    _otherSupp.text = p.otherSupplementsNote;
    _multivitamin = p.multivitamin;
    _wakeMin = _safeInt(p.wakeTimeMin, min: 0, max: 1439);
    _sleepMin = _safeInt(p.sleepTimeMin, min: 0, max: 1439);
    if (_wakeMin == 0) _wakeMin = 420;
    if (_sleepMin == 0) _sleepMin = 1380;
    if (p.wakeMinByDay.length == 7 && p.sleepMinByDay.length == 7) {
      _perDaySchedule = true;
      _wakeMinByDay = List<int>.from(p.wakeMinByDay);
      _sleepMinByDay = List<int>.from(p.sleepMinByDay);
    } else {
      _perDaySchedule = false;
      _wakeMinByDay = List<int>.filled(7, _wakeMin);
      _sleepMinByDay = List<int>.filled(7, _sleepMin);
    }
    _focusNotes.text = p.bodyFocusNotes;
    _gymStartDate = p.gymStartDate;
    _goesGym = p.goesGym;
    _cyclePhase = p.cyclePhase;
    _country = p.country;
    _dietPreference = p.dietPreference;
    _bodyFatPct = p.bodyFatPct;
    _healthFlags = List.of(p.healthFlags);
    _restDays = List.of(p.restDays);
    _cadence = p.weighInCadence;
    _weighInWeekday = p.weighInWeekday;
    _gender = p.gender;
    _activity = p.activityLevel;
    _goal = p.goal;
    _workoutType = p.workoutType;
    _calOverride.text = p.calorieOverride?.toString() ?? '';
    _proteinOverride.text = p.proteinOverride?.toString() ?? '';
    _carbOverride.text = p.carbOverride?.toString() ?? '';
    _fatOverride.text = p.fatOverride?.toString() ?? '';
    _fiberOverride.text = p.fiberOverride?.toString() ?? '';
    _waterOverride.text = p.waterOverride?.toString() ?? '';
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _heightCm.dispose();
    _weightKg.dispose();
    _trainingDays.dispose();
    _cardioDays.dispose();
    _walkingKm.dispose();
    _runningKm.dispose();
    _gymMin.dispose();
    _creatineG.dispose();
    _proteinScoops.dispose();
    _proteinGrams.dispose();
    _otherSupp.dispose();
    _focusNotes.dispose();
    _calOverride.dispose();
    _proteinOverride.dispose();
    _carbOverride.dispose();
    _fatOverride.dispose();
    _fiberOverride.dispose();
    _waterOverride.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        content: Text(msg,
            style: AppText.body.copyWith(color: AppColors.textPrimary)),
      ));
  }

  int? _maybeInt(TextEditingController c) {
    final v = c.text.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  Set<String> _selectedPresets() {
    final tokens = _focusNotes.text
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    return _focusPresets
        .where((p) => tokens.contains(p.$1.toLowerCase()))
        .map((p) => p.$1)
        .toSet();
  }

  void _togglePreset(String preset) {
    final selected = _selectedPresets();
    final tokens = _focusNotes.text
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (selected.contains(preset)) {
      tokens.removeWhere((t) => t.toLowerCase() == preset.toLowerCase());
    } else {
      tokens.add(preset);
    }
    setState(() {
      _focusNotes.text = tokens.join(', ');
    });
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final p = _profile;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final age = int.tryParse(_age.text.trim()) ?? p.age;
      final height = double.tryParse(_heightCm.text.trim()) ?? p.heightCm;
      final weight = double.tryParse(_weightKg.text.trim()) ?? p.weightKg;
      final days = _safeInt(
          int.tryParse(_trainingDays.text.trim()) ?? p.trainingDaysPerWeek,
          min: 0,
          max: 7);
      final cardio = _safeInt(
          int.tryParse(_cardioDays.text.trim()) ?? p.cardioSessionsPerWeek,
          min: 0,
          max: 7);
      final walking =
          double.tryParse(_walkingKm.text.trim()) ?? p.walkingKmPerDay;
      final running =
          double.tryParse(_runningKm.text.trim()) ?? p.runningKmPerWeek;
      final gymMin = _safeInt(
          int.tryParse(_gymMin.text.trim()) ?? p.gymMinutesPerSession,
          min: 20,
          max: 180);
      final creatine = _safeInt(
          int.tryParse(_creatineG.text.trim()) ?? p.creatineGramsPerDay,
          min: 0,
          max: 20);
      final protein = _safeInt(
          int.tryParse(_proteinScoops.text.trim()) ?? p.proteinScoopsPerDay,
          min: 0,
          max: 6);
      final proteinG = _safeInt(
          int.tryParse(_proteinGrams.text.trim()) ?? p.proteinGramsPerDay,
          min: 0,
          max: 400);

      final t = HealthMath.compute(
        gender: _gender,
        age: age,
        weightKg: weight,
        heightCm: height,
        activity: _activity,
        goal: _goal,
        cardioSessionsPerWeek: cardio,
        walkingKmPerDay: walking,
        runningKmPerWeek: running,
        gymMinutesPerSession: _goesGym ? gymMin : 0,
        strengthDaysPerWeek: _goesGym ? days : 0,
        bodyFocusNotes: _focusNotes.text.trim(),
        creatineGramsPerDay: creatine,
        proteinScoopsPerDay: protein,
        gymStartDate: _gymStartDate,
        bodyFatPct: _bodyFatPct,
        healthFlags: _healthFlags,
        restDays: _restDays,
        cyclePhase: _cyclePhase,
      );

      p
        ..displayName = _name.text.trim()
        ..age = age
        ..gender = _gender
        ..heightCm = height
        ..weightKg = weight
        ..activityLevel = _activity
        ..goal = _goal
        ..workoutType = _workoutType
        ..trainingDaysPerWeek = days
        ..cardioSessionsPerWeek = cardio
        ..walkingKmPerDay = walking
        ..runningKmPerWeek = running
        ..gymMinutesPerSession = gymMin
        ..wakeTimeMin = _wakeMin
        ..wakeMinByDay =
            _perDaySchedule ? List<int>.from(_wakeMinByDay) : []
        ..sleepMinByDay =
            _perDaySchedule ? List<int>.from(_sleepMinByDay) : []
        ..sleepTimeMin = _sleepMin
        ..creatineGramsPerDay = creatine
        ..proteinScoopsPerDay = protein
        ..proteinGramsPerDay = proteinG
        ..multivitamin = _multivitamin
        ..otherSupplementsNote = _otherSupp.text.trim()
        ..bodyFocusNotes = _focusNotes.text.trim()
        ..gymStartDate = _gymStartDate
        ..bodyFatPct = _bodyFatPct
        ..healthFlags = _healthFlags
        ..restDays = _restDays
        ..weighInCadence = _cadence
        ..weighInWeekday = _weighInWeekday
        ..goesGym = _goesGym
        ..cyclePhase = _cyclePhase
        ..country = _country
        ..dietPreference = _dietPreference
        ..bmr = t.bmr
        ..tdee = t.tdee
        ..calorieTarget = t.calorieTarget
        ..restDayCalorieTarget = t.restDayCalorieTarget
        ..proteinTargetG = t.proteinG
        ..carbTargetG = t.carbG
        ..fatTargetG = t.fatG
        ..fiberTargetG = t.fiberG
        ..waterTargetMl = t.waterMl
        ..bmi = t.bmi
        ..calorieOverride = _maybeInt(_calOverride)
        ..proteinOverride = _maybeInt(_proteinOverride)
        ..carbOverride = _maybeInt(_carbOverride)
        ..fatOverride = _maybeInt(_fatOverride)
        ..fiberOverride = _maybeInt(_fiberOverride)
        ..waterOverride = _maybeInt(_waterOverride);
      await ref.read(profileRepoProvider).save(p);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _toast(loc.couldNotSave);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: Text(loc.profileAndTargets, style: AppText.sectionTitle),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          actions: [
            TextButton(
              onPressed: _busy || !_loaded ? null : _save,
              child: Text(_busy ? '…' : loc.save,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  )),
            ),
          ],
        ),
        body: !_loaded
          ? const _ProfileEditSkeleton()
          : _profile == null
              ? _EmptyProfileNotice()
              : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  // ----------------- ABOUT YOU -----------------
                  _Section(
                    title: loc.aboutYou,
                    subtitle: loc.aboutYouDesc,
                    children: [
                      _Field(
                        label: loc.name.toUpperCase(),
                        controller: _name,
                        hint: 'How should we greet you?',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Field(
                              label: loc.age.toUpperCase(),
                              controller: _age,
                              hint: loc.years,
                              digits: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.genderField, style: AppText.label),
                                const SizedBox(height: 6),
                                _GenderSegment(
                                  value: _gender,
                                  onChanged: (g) =>
                                      setState(() => _gender = g),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                  Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: loc.heightField.toUpperCase(),
                              controller: _heightCm,
                              hint: loc.centimeters,
                              digits: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              label: loc.weightField.toUpperCase(),
                              controller: _weightKg,
                              hint: loc.kilograms,
                              decimals: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(loc.countryField, style: AppText.label),
                      const SizedBox(height: 6),
                      Text(
                          loc.coachSuggests,
                          style: AppText.meta.copyWith(fontSize: 11)),
                      const SizedBox(height: 8),
                      _CountryPickerEdit(
                        value: _country,
                        onChanged: (c) => setState(() => _country = c),
                      ),
                      const SizedBox(height: 14),
                      Text(loc.dietField, style: AppText.label),
                      const SizedBox(height: 8),
                      _DietPickerEdit(
                        value: _dietPreference,
                        onChanged: (d) =>
                            setState(() => _dietPreference = d),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- ACTIVITY -----------------
                  _Section(
                    title: loc.activity,
                    subtitle:
                        loc.activityDesc,
                    children: [
                      Text('DO YOU TRAIN AT A GYM?',
                          style: AppText.label),
                      const SizedBox(height: 8),
                      _GoesGymToggle(
                        value: _goesGym,
                        onChanged: (v) => setState(() => _goesGym = v),
                      ),
                      const SizedBox(height: 16),
                      Text(loc.activityLevel, style: AppText.label),
                      const SizedBox(height: 8),
                      _ActivitySegment(
                        value: _activity,
                        onChanged: (a) => setState(() => _activity = a),
                      ),
                      if (_goesGym) ...[
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'STRENGTH / WK',
                                controller: _trainingDays,
                                hint: '0–7',
                                digits: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Field(
                                label: 'CARDIO / WK',
                                controller: _cardioDays,
                                hint: '0–7',
                                digits: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      KmInputField(
                        label: 'WALKING',
                        initialCanonicalValue:
                            double.tryParse(_walkingKm.text) ?? 0,
                        canonicalUnit: KmUnit.perDay,
                        onChanged: (v) {
                          _walkingKm.text =
                              ((v * 2).round() / 2.0).toStringAsFixed(1);
                        },
                      ),
                      const SizedBox(height: 14),
                      KmInputField(
                        label: 'RUNNING',
                        initialCanonicalValue:
                            double.tryParse(_runningKm.text) ?? 0,
                        canonicalUnit: KmUnit.perWeek,
                        onChanged: (v) {
                          _runningKm.text = v.roundToDouble().toStringAsFixed(0);
                        },
                      ),
                      if (_goesGym) ...[
                        const SizedBox(height: 14),
                        _Field(
                          label: 'GYM MIN / SESSION',
                          controller: _gymMin,
                          hint: 'e.g. 60',
                          digits: true,
                        ),
                        const SizedBox(height: 14),
                        Text('GYM EXPERIENCE', style: AppText.label),
                        const SizedBox(height: 8),
                        _GymExperienceField(
                          startDate: _gymStartDate,
                          onChanged: (d) => setState(() => _gymStartDate = d),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _goesGym
                            ? 'Toggle Day / Week on walking and running — whichever feels natural to you.'
                            : 'Log specific running days from the home page — you\'ll get extra calories that day only.',
                        style: AppText.meta.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- SCHEDULE -----------------
                  _Section(
                    title: loc.schedule,
                    subtitle:
                        loc.scheduleDesc,
                    children: [
                      if (!_perDaySchedule)
                        Row(
                          children: [
                            Expanded(
                              child: _TimeField(
                                label: 'WAKE',
                                minutes: _wakeMin,
                                onChanged: (m) =>
                                    setState(() => _wakeMin = m),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TimeField(
                                label: 'SLEEP',
                                minutes: _sleepMin,
                                onChanged: (m) =>
                                    setState(() => _sleepMin = m),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < 7; i++) ...[
                              Row(
                                children: [
                                  SizedBox(
                                    width: 42,
                                    child: Text(
                                      [loc.monday, loc.tuesday, loc.wednesday, loc.thursday, loc.friday, loc.saturday, loc.sunday][i],
                                      style: AppText.label.copyWith(fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _TimeField(
                                      label: 'WAKE',
                                      minutes: _wakeMinByDay[i],
                                      onChanged: (m) =>
                                          setState(() => _wakeMinByDay[i] = m),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _TimeField(
                                      label: 'SLEEP',
                                      minutes: _sleepMinByDay[i],
                                      onChanged: (m) =>
                                          setState(() => _sleepMinByDay[i] = m),
                                    ),
                                  ),
                                ],
                              ),
                              if (i < 6) const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (!_perDaySchedule) {
                              _wakeMinByDay =
                                  List<int>.filled(7, _wakeMin);
                              _sleepMinByDay =
                                  List<int>.filled(7, _sleepMin);
                            }
                            _perDaySchedule = !_perDaySchedule;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: _perDaySchedule
                                ? AppColors.accent.withValues(alpha: 0.10)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _perDaySchedule
                                  ? AppColors.accent
                                  : AppColors.stroke,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _perDaySchedule
                                    ? Icons.check_circle_rounded
                                    : Icons.calendar_view_week_rounded,
                                size: 18,
                                color: _perDaySchedule
                                    ? AppColors.accent
                                    : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _perDaySchedule
                                      ? 'Per-day schedule — set wake & sleep for each day'
                                      : 'Different time each day?',
                                  style: AppText.body.copyWith(
                                    color: _perDaySchedule
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
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- HEALTH & CADENCE -----------------
                  _Section(
                    title: loc.healthAndCadence,
                    subtitle:
                        loc.healthAndCadenceDesc,
                    children: [
                      Text('BODY FAT % (OPTIONAL)', style: AppText.label),
                      const SizedBox(height: 8),
                      _BodyFatInline(
                        initial: _bodyFatPct,
                        onChanged: (v) => setState(() => _bodyFatPct = v),
                      ),
                      const SizedBox(height: 14),
                      Text(loc.restDaysField, style: AppText.label),
                      const SizedBox(height: 8),
                      _WeekdayChipsEdit(
                        selected: _restDays.toSet(),
                        onChanged: (s) => setState(() {
                          _restDays = s.toList()..sort();
                          if (_weighInWeekday == null && s.isNotEmpty) {
                            final f = (s.toList()..sort()).first;
                            _weighInWeekday = f == 1 ? 7 : f - 1;
                          }
                        }),
                      ),
                      const SizedBox(height: 14),
                      Text(loc.weighInCadence, style: AppText.label),
                      const SizedBox(height: 8),
                      _CadencePickerEdit(
                        value: _cadence,
                        onChanged: (c) => setState(() => _cadence = c),
                      ),
                      if (_gender == Gender.female) ...[
                        const SizedBox(height: 14),
                        Text('CYCLE PHASE', style: AppText.label),
                        const SizedBox(height: 4),
                        Text(
                            'Luteal phase = +100 kcal hunger bump; menstrual = +250 ml water.',
                            style: AppText.meta.copyWith(fontSize: 11)),
                        const SizedBox(height: 8),
                        _CyclePhasePicker(
                          value: _cyclePhase,
                          onChanged: (c) =>
                              setState(() => _cyclePhase = c),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(loc.healthContextOptional, style: AppText.label),
                      const SizedBox(height: 8),
                      _HealthFlagGridEdit(
                        selected: _healthFlags.toSet(),
                        onToggle: (f) => setState(() {
                          if (_healthFlags.contains(f)) {
                            _healthFlags = List.of(_healthFlags)..remove(f);
                          } else {
                            _healthFlags = List.of(_healthFlags)..add(f);
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- SUPPLEMENTS -----------------
                  if (_goesGym)
                  _Section(
                    title: loc.supplements,
                    subtitle:
                        loc.supplementsDesc,
                    children: [
                      _Field(
                        label: 'CREATINE (G/DAY)',
                        controller: _creatineG,
                        hint: 'e.g. 5',
                        digits: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Field(
                              label: loc.proteinScoops,
                              controller: _proteinScoops,
                              hint: loc.perDay,
                              digits: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              label: loc.proteinGrams,
                              controller: _proteinGrams,
                              hint: loc.perDay,
                              digits: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => setState(
                            () => _multivitamin = !_multivitamin),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: _multivitamin
                                ? AppColors.accent.withValues(alpha: 0.10)
                                : AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _multivitamin
                                  ? AppColors.accent
                                  : AppColors.stroke,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _multivitamin
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 18,
                                color: _multivitamin
                                    ? AppColors.accent
                                    : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Text(loc.multivitamin,
                                  style: AppText.body.copyWith(
                                    color: _multivitamin
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
                      _Field(
                        label: loc.otherOptional,
                        controller: _otherSupp,
                        hint: 'Pre-workout, omega-3, vitamin D…',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- WORKOUT TYPE -----------------
                  _Section(
                    title: loc.workoutType,
                    subtitle:
                        loc.workoutTypeDesc,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 4),
                        child: WorkoutTypePicker(
                          value: _workoutType,
                          onChanged: (t) =>
                              setState(() => _workoutType = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- GOAL -----------------
                  _Section(
                    title: loc.goal,
                    subtitle: loc.goalDesc,
                    children: [
                      _GoalSegment(
                        value: _goal,
                        onChanged: (g) => setState(() => _goal = g),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- BODY FOCUS -----------------
                  _Section(
                    title: loc.bodyFocusOptional,
                    subtitle:
                        loc.bodyFocusDesc,
                    children: [
                      RepaintBoundary(
                        child: _FocusPresetGrid(
                          presets: _focusPresets,
                          selected: _selectedPresets(),
                          onToggle: _togglePreset,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        label: 'NOTAS',
                        controller: _focusNotes,
                        hint:
                            'e.g. Skinny arms, belly fat, average legs…',
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ----------------- OVERRIDES -----------------
                  _Section(
                    title: loc.overrideTargets,
                    subtitle:
                        loc.overrideDesc,
                    trailing: GestureDetector(
                      onTap: () {
                        setState(() {
                          _calOverride.clear();
                          _proteinOverride.clear();
                          _carbOverride.clear();
                          _fatOverride.clear();
                          _fiberOverride.clear();
                          _waterOverride.clear();
                        });
                      },
                      child: Text(loc.clearAll,
                          style: AppText.label.copyWith(
                              color: AppColors.accent,
                              letterSpacing: 0.6)),
                    ),
                    children: [
                      _OverrideRow(
                          label: loc.calories + ' (kcal)',
                          controller: _calOverride,
                          autoValue: _profile?.calorieTarget),
                      _OverrideRow(
                          label: loc.protein + ' (g)',
                          controller: _proteinOverride,
                          autoValue: _profile?.proteinTargetG),
                      _OverrideRow(
                          label: loc.carbs + ' (g)',
                          controller: _carbOverride,
                          autoValue: _profile?.carbTargetG),
                      _OverrideRow(
                          label: loc.fat + ' (g)',
                          controller: _fatOverride,
                          autoValue: _profile?.fatTargetG),
                      _OverrideRow(
                          label: loc.fiber + ' (g)',
                          controller: _fiberOverride,
                          autoValue: _profile?.fiberTargetG),
                      _OverrideRow(
                          label: loc.water + ' (ml)',
                          controller: _waterOverride,
                          autoValue: _profile?.waterTargetMl),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// ───────────────── Helpers / smaller widgets ─────────────────

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  const _Section({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              AppText.sectionTitle.copyWith(fontSize: 18)),
                      if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: AppText.meta.copyWith(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String? label;
  final TextEditingController controller;
  final String hint;
  final bool digits;
  final bool decimals;
  final int maxLines;
  const _Field({
    this.label,
    required this.controller,
    required this.hint,
    this.digits = false,
    this.decimals = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppText.label),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            keyboardType: decimals
                ? const TextInputType.numberWithOptions(decimal: true)
                : digits
                    ? TextInputType.number
                    : maxLines > 1
                        ? TextInputType.multiline
                        : TextInputType.text,
            inputFormatters: decimals
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : digits
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
            cursorColor: AppColors.accent,
            maxLines: maxLines,
            style: AppText.body
                .copyWith(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: hint,
              hintStyle: AppText.body
                  .copyWith(color: AppColors.textTertiary, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusPresetGrid extends StatelessWidget {
  final List<(String, String)> presets;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _FocusPresetGrid({
    required this.presets,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < presets.length; i += 2) {
      final left = presets[i];
      final right = i + 1 < presets.length ? presets[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _FocusChip(
                label: left.$1,
                description: left.$2,
                selected: selected.contains(left.$1),
                onTap: () => onToggle(left.$1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _FocusChip(
                      label: right.$1,
                      description: right.$2,
                      selected: selected.contains(right.$1),
                      onTap: () => onToggle(right.$1),
                    ),
            ),
          ],
        ),
      ));
      if (i + 2 < presets.length) rows.add(const SizedBox(height: 8));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

class _FocusChip extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  const _FocusChip({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.stroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 13,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.1,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta.copyWith(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderSegment extends StatelessWidget {
  final Gender value;
  final ValueChanged<Gender> onChanged;
  const _GenderSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _RowSegment<Gender>(
      value: value,
      options: [
        (Gender.male, loc.male),
        (Gender.female, loc.female),
        (Gender.other, loc.other),
      ],
      onChanged: onChanged,
    );
  }
}

class _ActivitySegment extends StatelessWidget {
  final ActivityLevel value;
  final ValueChanged<ActivityLevel> onChanged;
  const _ActivitySegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _RowSegment<ActivityLevel>(
      value: value,
      options: [
        (ActivityLevel.sedentary, 'Sed.'),
        (ActivityLevel.light, 'Leve'),
        (ActivityLevel.moderate, 'Mod.'),
        (ActivityLevel.active, 'Ativo'),
        (ActivityLevel.veryActive, loc.athlete),
      ],
      onChanged: onChanged,
    );
  }
}

class _GoalSegment extends StatelessWidget {
  final FitnessGoal value;
  final ValueChanged<FitnessGoal> onChanged;
  const _GoalSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _RowSegment<FitnessGoal>(
      value: value,
      options: [
        (FitnessGoal.buildMuscle, loc.buildMuscle),
        (FitnessGoal.loseFat, loc.loseFat),
        (FitnessGoal.recomp, loc.recomp),
        (FitnessGoal.generalFitness, loc.generalFitness),
      ],
      onChanged: onChanged,
    );
  }
}

class _RowSegment<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  const _RowSegment({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: options.map((o) {
          final active = o.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  o.$2,
                  style: TextStyle(
                    color: active ? AppColors.onAccent : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
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

class _OverrideRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int? autoValue;
  const _OverrideRow({
    required this.label,
    required this.controller,
    required this.autoValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(label,
                          style: AppText.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  if (autoValue != null)
                    Text('auto: $autoValue',
                        style: AppText.meta.copyWith(
                            color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stroke),
              ),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                cursorColor: AppColors.accent,
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: '—',
                  hintStyle: AppText.body.copyWith(
                      color: AppColors.textTertiary, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? loc.pm : loc.am;
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final pretty = '$h12:${m.toString().padLeft(2, '0')} $period';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _pick(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(pretty,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GymExperienceField extends StatelessWidget {
  final DateTime? startDate;
  final ValueChanged<DateTime?> onChanged;
  const _GymExperienceField({required this.startDate, required this.onChanged});

  int? _currentBucket() {
    if (startDate == null) return null;
    final months = HealthMath.trainingMonths(startDate)!;
    if (months < 1) return 0;
    if (months < 6) return 3;
    if (months < 24) return 12;
    return 36;
  }

  DateTime? _bucketToDate(int? bucket) {
    if (bucket == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month - bucket, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final options = <(int?, String)>[
      (null, loc.never),
      (0, loc.lessThan1Month),
      (3, loc.threeToSixMonths),
      (12, loc.sixTo24Months),
      (36, loc.twoPlusYears),
    ];
    final current = _currentBucket();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = o.$1 == current;
        return GestureDetector(
          onTap: () => onChanged(_bucketToDate(o.$1)),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.stroke,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(o.$2,
                style: TextStyle(
                  color: selected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                )),
          ),
        );
      }).toList(),
    );
  }
}

/// Country list mirrors the onboarding flow's _commonCountries. Kept
/// here to avoid cross-package imports; if this list grows beyond ~30
/// entries, move it into a shared widget.
const List<(String, String)> _editCountries = [
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

class _CountryPickerEdit extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CountryPickerEdit(
      {required this.value, required this.onChanged});

  String _label(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (value.isEmpty) return loc.pickCountry;
    final m = _editCountries.where((c) => c.$1 == value).toList();
    return m.isEmpty ? value : m.first.$2;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _CountryEditSheet(initial: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final set = value.isNotEmpty;
    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: set ? AppColors.accent : AppColors.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded,
                size: 16,
                color: set ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_label(context),
                  style: AppText.body.copyWith(
                      color: set
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CountryEditSheet extends StatefulWidget {
  final String initial;
  const _CountryEditSheet({required this.initial});

  @override
  State<_CountryEditSheet> createState() => _CountryEditSheetState();
}

class _CountryEditSheetState extends State<_CountryEditSheet> {
  late final TextEditingController _q;
  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<(String, String)> _filtered() {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return _editCountries;
    return _editCountries
        .where((c) =>
            c.$2.toLowerCase().contains(q) || c.$1.toLowerCase() == q)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
              controller: _q,
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
                maxHeight:
                    MediaQuery.of(context).size.height * 0.55),
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
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
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

class _DietPickerEdit extends StatelessWidget {
  final DietPreference value;
  final ValueChanged<DietPreference> onChanged;
  const _DietPickerEdit({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final options = <(DietPreference, String)>[
      (DietPreference.omnivore, loc.omnivore),
      (DietPreference.vegetarian, loc.vegetarian),
      (DietPreference.vegan, loc.vegan),
      (DietPreference.pescatarian, loc.pescatarian),
      (DietPreference.keto, loc.keto),
      (DietPreference.halal, loc.halal),
      (DietPreference.kosher, loc.kosher),
      (DietPreference.jain, loc.jain),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
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
                  : AppColors.surfaceHigh,
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

class _CyclePhasePicker extends StatelessWidget {
  final CyclePhase value;
  final ValueChanged<CyclePhase> onChanged;
  const _CyclePhasePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final options = <(CyclePhase, String)>[
      (CyclePhase.unknown, loc.skip),
      (CyclePhase.menstrual, 'Menstrual'),
      (CyclePhase.follicular, 'Folicular'),
      (CyclePhase.ovulation, 'Ovulação'),
      (CyclePhase.luteal, 'Lútea'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
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
                  : AppColors.surfaceHigh,
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

class _GoesGymToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GoesGymToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                  color: selected ? AppColors.onAccent : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                )),
          ),
        ),
      );
    }

    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          pill('Yes, I Lift!', value, () => onChanged(true)),
          pill(loc.no, !value, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _BodyFatInline extends StatefulWidget {
  final double? initial;
  final ValueChanged<double?> onChanged;
  const _BodyFatInline({required this.initial, required this.onChanged});

  @override
  State<_BodyFatInline> createState() => _BodyFatInlineState();
}

class _BodyFatInlineState extends State<_BodyFatInline> {
  late final TextEditingController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(
      text:
          widget.initial == null ? '' : widget.initial!.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
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
              onChanged: (v) =>
                  widget.onChanged(double.tryParse(v.trim())),
              style: AppText.body
                  .copyWith(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: 'e.g. 18',
                hintStyle: AppText.body.copyWith(
                    color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ),
          Text('%',
              style: AppText.meta.copyWith(
                  fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _WeekdayChipsEdit extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  const _WeekdayChipsEdit({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final days = <(int, String)>[
      (1, loc.monday),
      (2, loc.tuesday),
      (3, loc.wednesday),
      (4, loc.thursday),
      (5, loc.friday),
      (6, loc.saturday),
      (7, loc.sunday),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: days.map((d) {
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
                  : AppColors.surfaceHigh,
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

class _CadencePickerEdit extends StatelessWidget {
  final WeighInCadence value;
  final ValueChanged<WeighInCadence> onChanged;
  const _CadencePickerEdit(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final options = <(WeighInCadence, String)>[
      (WeighInCadence.daily, loc.daily),
      (WeighInCadence.everyOtherDay, loc.everyOtherDay),
      (WeighInCadence.twiceAWeek, loc.twicePerWeek),
      (WeighInCadence.weekly, loc.weekly),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((o) {
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
                  : AppColors.surfaceHigh,
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

class _HealthFlagGridEdit extends StatelessWidget {
  final Set<HealthFlag> selected;
  final ValueChanged<HealthFlag> onToggle;
  const _HealthFlagGridEdit(
      {required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final options = <(HealthFlag, String, bool)>[
      (HealthFlag.pregnant, loc.pregnant, true),
      (HealthFlag.breastfeeding, loc.breastfeeding, true),
      (HealthFlag.eatingDisorderHistory, loc.eatingDisorderHistory, true),
      (HealthFlag.t1Diabetes, loc.type1Diabetes, true),
      (HealthFlag.recoveringFromInjury, loc.recoveringFromInjury, false),
      (HealthFlag.t2Diabetes, loc.type2Diabetes, false),
      (HealthFlag.pcos, loc.pcos, false),
      (HealthFlag.hypothyroid, loc.hypothyroid, false),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
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
                  : AppColors.surfaceHigh,
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

// ───────────────── Loading + empty states ─────────────────

class _ProfileEditSkeleton extends StatelessWidget {
  const _ProfileEditSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SkeletonSection(rows: 3, titleWidth: 120),
          SizedBox(height: 14),
          SkeletonSection(rows: 2, titleWidth: 160),
          SizedBox(height: 14),
          SkeletonSection(rows: 4, titleWidth: 140),
          SizedBox(height: 14),
          SkeletonSection(rows: 2, titleWidth: 100),
        ],
      ),
    );
  }
}

class _EmptyProfileNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 14),
              Text(loc.noProfileYet,
                  style: AppText.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                loc.finishOnboardingFirst,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
