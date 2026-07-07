import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/enums.dart';
import '../../data/models/routine.dart';
import '../../data/models/workout_session.dart';
import '../../services/workout/overload_advisor.dart';
import '../../services/workout/pr_tracker.dart';
import '../../services/workout/progression_coach.dart';
import '../../services/workout/starting_weight.dart';
import 'exercise_library_sheet.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/skeleton.dart';
import 'exercise_detail_page.dart';
import 'exercise_guide_sheet.dart';
import 'exercise_instruction_page.dart';
import 'pr_celebration.dart';
import 'workout_photos.dart';
import 'workout_summary_page.dart';

class WorkoutLoggerPage extends ConsumerStatefulWidget {
  final String routineName;
  final RoutineDay day;
  const WorkoutLoggerPage({
    super.key,
    required this.routineName,
    required this.day,
  });

  @override
  ConsumerState<WorkoutLoggerPage> createState() => _WorkoutLoggerPageState();
}

enum _LoggerView { focus, list }

class _WorkoutLoggerPageState extends ConsumerState<WorkoutLoggerPage> {
  WorkoutSession? _session;
  bool _starting = true;
  // Set when _start() throws — so a failure shows an error the user can
  // act on instead of hanging on the skeleton forever.
  String? _startError;

  // Per-exercise UI state: list of set rows with controllers and `done` flag.
  final Map<int, List<_SetRowState>> _rowsByExercise = {};
  final Map<int, List<SetEntry>> _previousByExercise = {};
  // Best estimated-1RM per exercise BEFORE this session, used for PR
  // detection at log time.
  final Map<int, double> _previousBestE1RM = {};
  // First-session weight estimates (exerciseId → kg) for exercises with no
  // logged history — from bodyweight + training experience. History wins.
  final Map<int, double> _startEstimateByExercise = {};
  // If a set is marked done sooner than this after it became active, we
  // double-check the user actually completed it (guards mis-taps / racing).
  static const _kConfirmFastSet = Duration(seconds: 10);

  // Rest timer (list-view countdown bar)
  Timer? _restTimer;
  DateTime? _restStart;
  int _restSeconds = 0;
  int _restRemaining = 0;
  // Full-screen rest page (focus/overlay flow). Counts UP with no fixed
  // limit — supersets and gym chatter mean rest length is the user's
  // call, so the page just stopwatches until they hit DONE.
  DateTime? _fullRestStart;
  // Suggested rest for the current break — longer after near-failure /
  // AMRAP / failure sets. The rest page shows it as a target.
  int _suggestedRestSeconds = 90;
  // The SetEntry just logged — the rest screen's "how did that feel?"
  // capture writes onto this so the feeling attaches to the right set.
  SetEntry? _lastLoggedEntry;

  // ---- Focus-mode state -----------------------------------------------------
  // Focus mode is the new sporty per-set view (one big screen at a time).
  // List mode is the original "scoreboard" — every exercise + every set
  // visible at once. Defaults to focus; users can switch in the app bar.
  _LoggerView _view = _LoggerView.focus;
  // Cursor into widget.day.items + that exercise's set rows.
  int _focusExerciseIdx = 0;
  int _focusSetIdx = 0;
  // When this set was first shown — drives the per-set elapsed timer.
  DateTime? _focusSetStartedAt;
  // When the whole workout session started — drives the TOTAL TIME
  // chip on the instruction overlay.
  // Instruction overlay (with demo image, timer, form cues) is shown as
  // the main workout screen. User taps Play to log the set below.
  // PR sparkle gate — set true momentarily after a PR set logs.
  bool _focusPrPulse = false;
  // Session start — drives the instruction overlay's TOTAL TIME chip.
  DateTime _workoutStartedAt = DateTime.now();
  // Elapsed set-timer seconds per set — resume when the user returns to
  // a set they'd already started (leaving and coming back keeps the
  // count instead of resetting to 0).
  final Map<String, int> _setElapsed = {};
  // The instruction overlay is the main workout screen — it wraps the
  // focus set view and is dismissed with the top-right X or the big
  // Play button (which logs the set and advances).
  // Instruction overlay is the workout screen. X exits the workout via
  // _confirmExit rather than dismissing to reveal an underlying view.
  final bool _instructionVisible = true;

  int _completedSetsAll() => _rowsByExercise.values
      .expand((rows) => rows)
      .where((r) => r.done)
      .length;

  int _totalSetsAll() =>
      _rowsByExercise.values.expand((rows) => rows).length;

  Widget _buildInstructionOverlay() {
    final items = widget.day.items;
    final exIdx = _focusExerciseIdx.clamp(0, items.length - 1);
    final item = items[exIdx];
    final rows = _rowsByExercise[item.exerciseId];
    final row = rows == null || rows.isEmpty
        ? null
        : rows[_focusSetIdx.clamp(0, rows.length - 1)];
    if (row == null) return const SizedBox.shrink();
    // Set-timer resume key — one bucket per (exercise, set) pair.
    final elapsedKey = '${item.exerciseId}:$_focusSetIdx';
    // Auto-progression: what to do based on last session's performance,
    // RIR and feeling. Shown as a tappable coach chip that fills the
    // suggested weight/reps.
    final advice = ProgressionCoach.nextTarget(
      item: item,
      previousSets: _previousByExercise[item.exerciseId] ?? const [],
    );
    return ExerciseInstructionOverlay(
      // Key by exercise only — set changes stay on the same widget instance
      // so the image/instructions don't flash empty while _load() re-fetches.
      // didUpdateWidget in the overlay handles per-set state (elapsed timer).
      key: ValueKey('instr_$exIdx'),
      exerciseId: item.exerciseId,
      exerciseName: item.exerciseName,
      setIndex: _focusSetIdx,
      totalSets: rows!.length,
      isCurrentSetDone: row.done,
      completedSets: _completedSetsAll(),
      totalSetsAll: _totalSetsAll(),
      workoutStartedAt: _workoutStartedAt,
      weightController: row.weight,
      repsController: row.reps,
      initialElapsedSeconds: _setElapsed[elapsedKey] ?? 0,
      onElapsedChanged: (secs) => _setElapsed[elapsedKey] = secs,
      // Freeze the set timer while the full-screen rest page is up.
      suspended: _fullRestStart != null,
      // Set metadata — RPE (reps in reserve) + set type (warmup / drop /
      // AMRAP / failure). Written onto the SetEntry when the set logs.
      rpe: row.rpe,
      setType: row.setType,
      onRpeChanged: (v) => setState(() => row.rpe = v),
      onSetTypeChanged: (t) => setState(() => row.setType = t),
      // Auto-progression coach line. Tapping it applies the suggested
      // weight/reps to this set's inputs.
      coachHeadline: advice.action == ProgressionAction.buildBase
          ? null
          : advice.headline,
      onApplyCoach: (advice.suggestedWeightKg == null &&
              advice.suggestedReps == null)
          ? null
          : () {
              setState(() {
                if (advice.suggestedWeightKg != null) {
                  final w = advice.suggestedWeightKg!;
                  row.weight.text = w == w.roundToDouble()
                      ? w.toInt().toString()
                      : w.toStringAsFixed(1);
                }
                if (advice.suggestedReps != null) {
                  row.reps.text = advice.suggestedReps.toString();
                }
              });
              HapticFeedback.selectionClick();
            },
      // X on the overlay exits the workout entirely (same flow as the
      // system back button) — we don't dismiss to reveal the old
      // FocusSetView underneath.
      onClose: () async {
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) {
          navigator.pop();
        }
      },
      onPrev: () {
        setState(() {
          if (_focusSetIdx > 0) {
            _focusSetIdx--;
          } else if (_focusExerciseIdx > 0) {
            _focusExerciseIdx--;
            final pr =
                _rowsByExercise[items[_focusExerciseIdx].exerciseId];
            _focusSetIdx = pr == null ? 0 : pr.length - 1;
          }
          _focusSetStartedAt = DateTime.now();
        });
      },
      onNext: () {
        setState(() {
          final cur = items[_focusExerciseIdx.clamp(0, items.length - 1)];
          final maxSet =
              (_rowsByExercise[cur.exerciseId]?.length ?? 1) - 1;
          if (_focusSetIdx < maxSet) {
            _focusSetIdx++;
          } else if (_focusExerciseIdx < items.length - 1) {
            _focusExerciseIdx++;
            _focusSetIdx = 0;
          }
          _focusSetStartedAt = DateTime.now();
        });
      },
      // Next / big centre button: log this set when it's loggable —
      // _logSet saves and advances the cursor itself. But on a set
      // that's already done (user pressed Prev. to look back) or has
      // empty reps, _logSet is a no-op, which used to leave Next
      // completely dead. Fall back to a plain one-step advance so
      // navigation always responds.
      onLog: () {
        final rs = _rowsByExercise[item.exerciseId];
        if (rs == null || rs.isEmpty) return;
        final idx = _focusSetIdx.clamp(0, rs.length - 1);
        final r = rs[idx];
        final reps = int.tryParse(r.reps.text.trim()) ?? 0;
        if (!r.done && reps > 0) {
          _logSet(item, idx);
          return;
        }
        setState(() {
          if (idx < rs.length - 1) {
            _focusSetIdx = idx + 1;
          } else if (_focusExerciseIdx < items.length - 1) {
            _focusExerciseIdx++;
            _focusSetIdx = 0;
          }
          _focusSetStartedAt = DateTime.now();
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _startInner();
    } catch (e, st) {
      debugPrint('Workout _start failed: $e\n$st');
      if (mounted) {
        setState(() {
          _starting = false;
          _startError = e.toString();
        });
      }
    }
  }

  Future<void> _startInner() async {
    final repo = ref.read(workoutRepoProvider);
    // Resume today's still-open session for this day if one exists (the user
    // did some sets, left — e.g. to add another exercise — and came back),
    // otherwise start fresh. Resuming keeps already-logged sets done so the
    // workout continues where they left off instead of restarting.
    final session = await repo.resumableSession(
          routineName: widget.routineName,
          routineDayName: widget.day.name,
        ) ??
        await repo.startSession(
          routineName: widget.routineName,
          routineDayName: widget.day.name,
        );
    final previous = <int, List<SetEntry>>{};
    final allSessions = await repo.sessionsSince(DateTime(1970));
    final bestE1RM = <int, double>{};
    for (final item in widget.day.items) {
      previous[item.exerciseId] = await repo.previousSetsFor(
        item.exerciseId,
        excludeSessionId: session.id,
      );
      bestE1RM[item.exerciseId] = PrTracker.bestForExercise(
        allSessions,
        item.exerciseId,
        excludeSessionId: session.id,
      );
    }

    // First-session weight suggestions: for any exercise with no logged
    // history, estimate a conservative opening weight from the user's
    // bodyweight + training experience so the field isn't blank.
    final estimates = <int, double>{};
    final profile = ref.read(profileStreamProvider).valueOrNull;
    if (profile != null) {
      final library = await ref.read(exerciseRepoProvider).all();
      final exById = {for (final e in library) e.id: e};
      for (final item in widget.day.items) {
        if ((previous[item.exerciseId] ?? const <SetEntry>[]).isNotEmpty) {
          continue;
        }
        final ex = exById[item.exerciseId];
        if (ex == null) continue;
        final est = StartingWeight.suggestKg(
          exercise: ex,
          bodyweightKg: profile.weightKg,
          gender: profile.gender,
          gymStartDate: profile.gymStartDate,
        );
        if (est != null) estimates[item.exerciseId] = est;
      }
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _workoutStartedAt = DateTime.now();
      _previousByExercise.addAll(previous);
      _previousBestE1RM.addAll(bestE1RM);
      _startEstimateByExercise.addAll(estimates);
      for (final item in widget.day.items) {
        final prev = previous[item.exerciseId] ?? const [];
        _rowsByExercise[item.exerciseId] =
            List.generate(item.targetSets, (i) {
          // Resuming: this exact set was already logged in the open session
          // → show it filled + done so the user doesn't redo it.
          SetEntry? logged;
          for (final s in session.sets) {
            if (s.exerciseId == item.exerciseId && s.setNumber == i + 1) {
              logged = s;
              break;
            }
          }
          // Per-set weight preference: this set's weight from the last
          // session if we recorded it; otherwise the last session's set 1
          // weight (typical continuation pattern); otherwise blank.
          double? prevSetWeight;
          int? prevSetReps;
          if (i < prev.length) {
            prevSetWeight = prev[i].weightKg;
            prevSetReps = prev[i].reps;
          } else if (prev.isNotEmpty) {
            prevSetWeight = prev.first.weightKg;
          }
          // Reps default: pyramid from targetRepsHigh (set 1) down to
          // targetRepsLow (last set) — the classic 12/10/8/6 pattern.
          // History wins over the pyramid when present.
          final pyramidReps = _pyramidReps(
            setIdx: i,
            totalSets: item.targetSets,
            high: item.targetRepsHigh,
            low: item.targetRepsLow,
          );
          final reps = prevSetReps ?? pyramidReps;
          final row = _SetRowState(
            weight: TextEditingController(
              text: logged != null
                  ? _fmtWeight(logged.weightKg)
                  : ((prevSetWeight ?? 0) > 0
                      ? _fmtWeight(prevSetWeight!)
                      : (i == 0 &&
                              _startEstimateByExercise[item.exerciseId] != null
                          ? _fmtWeight(
                              _startEstimateByExercise[item.exerciseId]!)
                          : '')),
            ),
            reps: TextEditingController(
                text: logged != null
                    ? logged.reps.toString()
                    : (reps > 0 ? reps.toString() : '')),
          );
          if (logged != null) {
            row.done = true;
            row.rpe = logged.rpe;
            row.setType = logged.setType;
          }
          return row;
        });
      }
      // Resume point: focus the first set not yet done — a fresh workout
      // lands on set 1 of exercise 1; a resumed one skips past the sets
      // already completed to the next thing to do.
      _focusExerciseIdx = 0;
      _focusSetIdx = 0;
      outer:
      for (var e = 0; e < widget.day.items.length; e++) {
        final rows = _rowsByExercise[widget.day.items[e].exerciseId];
        if (rows == null) continue;
        for (var s = 0; s < rows.length; s++) {
          if (!rows[s].done) {
            _focusExerciseIdx = e;
            _focusSetIdx = s;
            break outer;
          }
        }
      }
      _starting = false;
      _focusSetStartedAt = DateTime.now();
    });
    // Workout starts on the focus set view with the timer ticking — the
    // instruction overlay no longer auto-blocks the screen. Users tap the
    // guide/info button (or first-set entry) to view form cues on demand.
  }

  /// Advances the focus cursor to the next not-done set in the day,
  /// or to the next exercise's set 1 when the current exercise is done.
  /// When the entire day is complete, leaves the cursor at the last set
  /// so the focus screen can show a "you're done — finish" state.
  void _advanceFocusCursor() {
    final items = widget.day.items;
    if (items.isEmpty) return;

    // Superset-aware advance: within a group (items sharing a non-null
    // supersetGroup), rotate round-major — memberA setN, memberB setN, …,
    // then setN+1 — so the exercises interleave instead of finishing one
    // before starting the next.
    final curItem = items[_focusExerciseIdx.clamp(0, items.length - 1)];
    final group = curItem.supersetGroup;
    if (group != null) {
      final members = [
        for (var i = 0; i < items.length; i++)
          if (items[i].supersetGroup == group) i
      ];
      if (members.length > 1) {
        final pos = members.indexOf(_focusExerciseIdx);
        // Remaining members in the current round (same set index).
        for (var p = pos + 1; p < members.length; p++) {
          final rows = _rowsByExercise[items[members[p]].exerciseId];
          if (rows != null &&
              _focusSetIdx < rows.length &&
              !rows[_focusSetIdx].done) {
            _focusExerciseIdx = members[p];
            _focusSetStartedAt = DateTime.now();
            return;
          }
        }
        // Later rounds, first eligible member.
        final maxSets = members
            .map((ei) => _rowsByExercise[items[ei].exerciseId]?.length ?? 0)
            .fold<int>(0, (a, b) => a > b ? a : b);
        for (var s = _focusSetIdx + 1; s < maxSets; s++) {
          for (final ei in members) {
            final rows = _rowsByExercise[items[ei].exerciseId];
            if (rows != null && s < rows.length && !rows[s].done) {
              _focusExerciseIdx = ei;
              _focusSetIdx = s;
              _focusSetStartedAt = DateTime.now();
              return;
            }
          }
        }
        // Group exhausted — fall through to the normal walk past it.
      }
    }

    // Walk forward from current position; first not-done set wins.
    final total = items.length;
    var ex = _focusExerciseIdx;
    var st = _focusSetIdx + 1;
    while (ex < total) {
      final rows = _rowsByExercise[items[ex].exerciseId];
      if (rows != null) {
        while (st < rows.length) {
          if (!rows[st].done) {
            _focusExerciseIdx = ex;
            _focusSetIdx = st;
            _focusSetStartedAt = DateTime.now();
            // Timer keeps counting through exercise changes; the user
            // can pull up the guide/instruction on demand.
            return;
          }
          st++;
        }
      }
      ex++;
      st = 0;
    }
    // Fell through — nothing left. Keep cursor at last position; the
    // focus screen renders a "workout complete" state when every row
    // in widget.day.items is done.
  }

  /// "BENCH PRESS · SET 2 OF 4" for the rest page — the cursor has
  /// already advanced to the upcoming set by the time rest starts.
  String _nextUpLabel() {
    final items = widget.day.items;
    if (items.isEmpty) return '';
    final exIdx = _focusExerciseIdx.clamp(0, items.length - 1);
    final item = items[exIdx];
    final rows = _rowsByExercise[item.exerciseId];
    final total = rows?.length ?? 1;
    final setIdx = _focusSetIdx.clamp(0, total - 1);
    return '${item.exerciseName.toUpperCase()} · SET ${setIdx + 1} OF $total';
  }



  @override
  void dispose() {
    _restTimer?.cancel();
    for (final list in _rowsByExercise.values) {
      for (final r in list) {
        r.weight.dispose();
        r.reps.dispose();
      }
    }
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restStart = DateTime.now();
      _restSeconds = seconds;
      _restRemaining = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_restStart!).inSeconds;
      final remaining = _restSeconds - elapsed;
      if (remaining <= 0) {
        t.cancel();
        setState(() {
          _restRemaining = 0;
          _restStart = null;
        });
        HapticFeedback.mediumImpact();
      } else {
        setState(() => _restRemaining = remaining);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _restStart = null;
      _restRemaining = 0;
    });
  }

  /// Asks the user to confirm a set they finished suspiciously fast.
  Future<bool> _confirmSetComplete(int elapsedSecs) async {
    final when = elapsedSecs < 2
        ? 'You only just started this set.'
        : 'You started this set about ${elapsedSecs}s ago.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Finished this set?',
            style: AppText.sectionTitle.copyWith(fontSize: 18)),
        content: Text('$when Log it as complete?',
            style: AppText.body
                .copyWith(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Not yet',
                style: AppText.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Yes, log it',
                style: AppText.body.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _logSet(RoutinePlanItem item, int rowIndex) async {
    final row = _rowsByExercise[item.exerciseId]![rowIndex];
    if (row.done) return;
    final weight = double.tryParse(row.weight.text.trim()) ?? 0;
    final reps = int.tryParse(row.reps.text.trim()) ?? 0;
    if (reps <= 0) return;

    final session = _session;
    if (session == null) return;

    // Guard against banking a set the user didn't actually finish — if they
    // hit DONE within a few seconds of the set becoming active (mis-tap, or
    // racing ahead of their real training), confirm first. Warm-ups are
    // naturally quick, so they're exempt.
    if (_view == _LoggerView.focus &&
        row.setType != SetType.warmup &&
        _focusSetStartedAt != null) {
      final elapsed = DateTime.now().difference(_focusSetStartedAt!);
      if (elapsed < _kConfirmFastSet) {
        final confirmed = await _confirmSetComplete(elapsed.inSeconds);
        if (!mounted || !confirmed) return;
      }
    }

    final entry = SetEntry()
      ..exerciseId = item.exerciseId
      ..exerciseName = item.exerciseName
      ..setNumber = rowIndex + 1
      ..weightKg = weight
      ..reps = reps
      ..rpe = row.rpe
      ..setType = row.setType
      ..isWarmup = row.setType == SetType.warmup
      ..completedAt = DateTime.now();
    session.sets.add(entry);
    _lastLoggedEntry = entry;
    await ref.read(workoutRepoProvider).updateSession(session);

    // PR detection
    // Warmup sets never count as PRs — a light warmup shouldn't fire the
    // celebration or bump the tracked best.
    final newE1RM = PrTracker.estimated1RM(weight, reps);
    final priorBest = _previousBestE1RM[item.exerciseId] ?? 0;
    final isPr = row.setType != SetType.warmup &&
        priorBest > 0 &&
        newE1RM > priorBest;
    if (isPr) {
      _previousBestE1RM[item.exerciseId] = newE1RM;
    }

    if (!mounted) return;
    setState(() {
      row.done = true;
      // Pre-fill next set with the same values
      final nextIdx = rowIndex + 1;
      final rows = _rowsByExercise[item.exerciseId]!;
      if (nextIdx < rows.length) {
        final next = rows[nextIdx];
        if (next.weight.text.trim().isEmpty) {
          next.weight.text = row.weight.text;
        }
        if (next.reps.text.trim().isEmpty) {
          next.reps.text = row.reps.text;
        }
      }
    });
    if (isPr) {
      PrCelebration.show(context,
          exerciseName: item.exerciseName, e1rm: newE1RM);
      // Trigger a brief sparkle on the focus screen's weight number.
      setState(() => _focusPrPulse = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _focusPrPulse = false);
      });
    } else {
      HapticFeedback.lightImpact();
    }
    // Move the focus cursor forward only when we're in focus mode; the
    // list view advances naturally by user tap on the next row's "+".
    if (_view == _LoggerView.focus) _advanceFocusCursor();
    // Rest: focus/overlay flow gets the full-screen count-up rest page
    // (user decides when rest is over — no fixed countdown). Skip it
    // when the day is fully logged; nothing left to rest for. List
    // view keeps the classic countdown bar.
    // Superset: if the cursor just moved to a DIFFERENT exercise sharing
    // this one's group, flow straight into it with no rest (rest comes
    // after the last exercise in the round).
    final nextItem =
        widget.day.items[_focusExerciseIdx.clamp(0, widget.day.items.length - 1)];
    final intoSupersetPartner = item.supersetGroup != null &&
        nextItem.supersetGroup == item.supersetGroup &&
        nextItem.exerciseId != item.exerciseId;
    // Show the full-screen rest / completion screen after every logged set
    // (except when flowing straight into a superset partner). When the whole
    // day is done, _FullRestPage switches to "complete" mode where the user
    // can add another exercise or finish → summary.
    if (_view == _LoggerView.focus && _instructionVisible) {
      if (!intoSupersetPartner) {
        setState(() {
          _suggestedRestSeconds = _suggestRest(item, row);
          _fullRestStart = DateTime.now();
        });
      }
    } else if (item.restSeconds > 0 && !intoSupersetPartner) {
      _startRest(item.restSeconds);
    }
  }

  /// Whole day logged?
  bool _allDone() => widget.day.items.every((it) =>
      (_rowsByExercise[it.exerciseId] ?? const <_SetRowState>[])
          .every((r) => r.done));

  /// Add an exercise mid-workout (from the completion screen) — creates its
  /// rows, jumps the cursor to it, and dismisses the rest screen.
  Future<void> _addExerciseMidWorkout() async {
    final picked = await ExerciseLibrarySheet.show(context);
    if (picked == null || !mounted) return;
    final item = RoutinePlanItem()
      ..exerciseId = picked.exerciseId
      ..exerciseName = picked.name
      ..targetSets = 3
      ..targetRepsLow = 8
      ..targetRepsHigh = 12
      ..restSeconds = picked.restSeconds;
    setState(() {
      widget.day.items.add(item);
      _rowsByExercise[item.exerciseId] = List.generate(item.targetSets, (i) {
        final reps = _pyramidReps(
          setIdx: i,
          totalSets: item.targetSets,
          high: item.targetRepsHigh,
          low: item.targetRepsLow,
        );
        return _SetRowState(
          weight: TextEditingController(),
          reps: TextEditingController(text: reps > 0 ? reps.toString() : ''),
        );
      });
      _focusExerciseIdx = widget.day.items.length - 1;
      _focusSetIdx = 0;
      _fullRestStart = null;
      _focusSetStartedAt = DateTime.now();
    });
  }

  /// Suggested rest seconds — base rest for the exercise, extended when the
  /// set was taken near or to failure (low RIR / AMRAP / failure), which
  /// needs more recovery before the next hard effort.
  int _suggestRest(RoutinePlanItem item, _SetRowState row) {
    var s = item.restSeconds > 0 ? item.restSeconds : 90;
    final nearFailure = (row.rpe != null && row.rpe! >= 9) ||
        row.setType == SetType.failure ||
        row.setType == SetType.amrap;
    if (nearFailure) s += 45;
    return s.clamp(45, 240);
  }

  /// Attaches the rest-screen "how did that feel?" pick to the set that
  /// was just logged, then persists so the AI coach can read it later.
  Future<void> _setLastSetFeeling(SetFeeling feeling) async {
    final entry = _lastLoggedEntry;
    final session = _session;
    if (entry == null || session == null) return;
    setState(() => entry.feeling = feeling);
    HapticFeedback.selectionClick();
    await ref.read(workoutRepoProvider).updateSession(session);
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null) return;
    final ok = await _confirmFinish(session.sets.isEmpty);
    if (!ok) return;
    // Snapshot before save so we can count PRs achieved this session.
    final prsBefore = _prsBeforeSession();
    await ref.read(workoutRepoProvider).completeSession(session.id);
    if (!mounted) return;
    final prCount = _countSessionPrs(session, prsBefore);
    // Any real (non-warmup) rep counts — bodyweight sets (weight 0) still
    // make a session worth summarising.
    final hasWork = session.sets.any((s) => !s.isWarmup && s.reps > 0);
    // Empty finish → just leave. Real session → show the summary page.
    if (!hasWork) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WorkoutSummaryPage(
        session: session,
        dayName: widget.day.name,
        prCount: prCount,
      ),
    ));
  }

  /// Count of exercises that set a new best estimated-1RM this session.
  int _countSessionPrs(
      WorkoutSession session, Map<String, double> prsBefore) {
    final best = Map<String, double>.from(prsBefore);
    var prs = 0;
    for (final set in session.sets) {
      if (set.isWarmup || set.weightKg <= 0 || set.reps <= 0) continue;
      final e = set.weightKg * (1 + set.reps / 30.0);
      final prior = best[set.exerciseName] ?? 0;
      if (e > prior + 0.5) {
        prs++;
        best[set.exerciseName] = e;
      }
    }
    return prs;
  }

  Map<String, double> _prsBeforeSession() {
    final allSessions =
        ref.read(allSessionsProvider).valueOrNull ?? const <WorkoutSession>[];
    final current = _session;
    final prior = allSessions.where((s) => s.id != current?.id).toList();
    final best = <String, double>{};
    for (final s in prior) {
      for (final set in s.sets) {
        if (set.isWarmup || set.weightKg <= 0 || set.reps <= 0) continue;
        final e = set.weightKg * (1 + set.reps / 30.0);
        final cur = best[set.exerciseName] ?? 0;
        if (e > cur) best[set.exerciseName] = e;
      }
    }
    return best;
  }

  Future<bool> _confirmFinish(bool empty) async {
    if (!empty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finish without logging?',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                  'You haven\'t logged any sets. The session will be saved empty.',
                  style: AppText.body),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Keep going',
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Finish',
                        style: AppText.body.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return res ?? false;
  }

  Future<void> _discardWorkout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Discard workout?',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                  'All logged sets in this session will be deleted. This can\'t be undone.',
                  style: AppText.body),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel',
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Discard',
                        style: AppText.body.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final session = _session;
    if (session == null) return;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(workoutRepoProvider).deleteSession(session.id);
    if (mounted) navigator.pop();
  }

  Future<bool> _confirmExit() async {
    final session = _session;
    if (session == null) return true;
    if (session.sets.isEmpty) {
      // Drop the empty session
      await ref.read(workoutRepoProvider).deleteSession(session.id);
      return true;
    }
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leave workout?',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                  'Your sets are saved. You can come back and continue from the workout tab.',
                  style: AppText.body),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Stay',
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Leave',
                        style: AppText.body.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit()) {
          if (mounted) navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        extendBodyBehindAppBar: _instructionVisible ||
            (_view == _LoggerView.focus && !_starting),
        appBar: _instructionVisible
            ? null
            : AppBar(
          backgroundColor: _view == _LoggerView.focus && !_starting
              ? Colors.transparent
              : AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            widget.day.name,
            style: AppText.sectionTitle.copyWith(
              color: _view == _LoggerView.focus && !_starting
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
          ),
          iconTheme: IconThemeData(
            color: _view == _LoggerView.focus && !_starting
                ? Colors.white
                : AppColors.textPrimary,
          ),
          actions: [
            // Focus ↔ list toggle.
            IconButton(
              onPressed: () {
                setState(() {
                  _view = _view == _LoggerView.focus
                      ? _LoggerView.list
                      : _LoggerView.focus;
                  if (_view == _LoggerView.focus) {
                    _focusSetStartedAt = DateTime.now();
                  }
                });
              },
              icon: Icon(
                _view == _LoggerView.focus
                    ? Icons.view_agenda_outlined
                    : Icons.crop_square_rounded,
              ),
              tooltip: _view == _LoggerView.focus
                  ? 'Show full list'
                  : 'Show focus view',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.stroke),
              ),
              onSelected: (v) {
                if (v == 'discard') _discardWorkout();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'discard',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Text('Discard workout',
                          style: AppText.body.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _startError != null
            ? _StartErrorView(
                message: _startError!,
                onRetry: () {
                  setState(() {
                    _starting = true;
                    _startError = null;
                  });
                  _start();
                },
                onClose: () => Navigator.of(context).maybePop(),
              )
            : _starting
                ? const _OngoingWorkoutSkeleton()
                : Stack(
                children: [
                  // The instruction overlay is opaque and fills the body —
                  // when it's up, don't build the photo backdrop / focus
                  // body / rest overlay underneath it. They were being
                  // rebuilt on every rest-timer tick (once a second) for
                  // pixels the user can never see, which made taps on the
                  // overlay's Prev/Next feel laggy on slower devices.
                  if (!(_instructionVisible &&
                      widget.day.items.isNotEmpty)) ...[
                    // Photo backdrop in focus mode only — gives the screen
                    // a Strava/Whoop-style "you are training right now"
                    // feel. List mode keeps the flat bg so dense rows stay
                    // readable. Falls back to a gradient if no asset.
                    if (_view == _LoggerView.focus &&
                        widget.day.items.isNotEmpty)
                      Positioned.fill(
                        child: WorkoutPhotoBackground(
                          dayName: widget.day.name,
                          overlayStrength: 0.78,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    SafeArea(
                      child: _view == _LoggerView.focus
                          ? _buildFocusBody()
                          : _buildListBody(),
                    ),
                    if (_restStart != null)
                      _RestOverlay(
                        remaining: _restRemaining,
                        total: _restSeconds,
                        onSkip: _skipRest,
                        onAdd: (delta) {
                          if (_restStart == null) return;
                          setState(() {
                            _restSeconds =
                                (_restSeconds + delta).clamp(0, 3600).toInt();
                            _restRemaining =
                                (_restRemaining + delta).clamp(0, 3600).toInt();
                          });
                        },
                      ),
                  ],
                  if (_instructionVisible &&
                      widget.day.items.isNotEmpty)
                    _buildInstructionOverlay(),
                  // Full-screen rest page — sits on top of the instruction
                  // overlay after every logged set. Ticks internally so the
                  // rest of the page doesn't rebuild every second.
                  if (_fullRestStart != null &&
                      _instructionVisible &&
                      widget.day.items.isNotEmpty)
                    _FullRestPage(
                      startedAt: _fullRestStart!,
                      nextUp: _nextUpLabel(),
                      suggestedRestSeconds: _suggestedRestSeconds,
                      isComplete: _allDone(),
                      onFinish: () {
                        setState(() => _fullRestStart = null);
                        _finish();
                      },
                      onAddExercise: _addExerciseMidWorkout,
                      feeling:
                          _lastLoggedEntry?.feeling ?? SetFeeling.unset,
                      onFeeling: _setLastSetFeeling,
                      onDone: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _fullRestStart = null;
                          _focusSetStartedAt = DateTime.now();
                        });
                      },
                      // Preview the upcoming exercise (photos, video,
                      // form cues) so the user can prepare during rest.
                      // The cursor already points at the next set, so
                      // mid-exercise this shows the same movement and
                      // after the last set it shows the next one.
                      onPreview: () {
                        final items = widget.day.items;
                        if (items.isEmpty) return;
                        final item = items[
                            _focusExerciseIdx.clamp(0, items.length - 1)];
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailPage(
                              exerciseId: item.exerciseId,
                              planItem: item,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }

  static String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  /// Classic descending pyramid: start at [high], drop 2 reps per set,
  /// clamped to [low] as the floor. So 4 sets of 12–6 → 12/10/8/6,
  /// 3 sets → 12/10/8. If the range is tight (e.g. 8–12) the tail
  /// settles at [low] rather than going below.
  static int _pyramidReps({
    required int setIdx,
    required int totalSets,
    required int high,
    required int low,
  }) {
    if (totalSets <= 1) return high;
    final reps = high - (setIdx * 2);
    if (reps < low) return low < 1 ? 1 : low;
    return reps < 1 ? 1 : reps;
  }

  // ---- View builders --------------------------------------------------------

  /// Original "scoreboard" — every exercise + every set visible at once.
  /// Useful for power users who want to type values directly. Kept as a
  /// secondary view; toggled from the app bar.
  Widget _buildListBody() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            itemCount: widget.day.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final item = widget.day.items[i];
              final prev =
                  _previousByExercise[item.exerciseId] ?? const [];
              return _ExerciseCard(
                item: item,
                rows: _rowsByExercise[item.exerciseId]!,
                previous: prev,
                overloadHint: OverloadAdvisor.hintFor(
                  item: item,
                  previousSets: prev,
                  upColor: AppColors.accent,
                  holdColor: AppColors.textSecondary,
                  downColor: AppColors.water,
                ),
                onShowGuide: () => ExerciseGuideSheet.show(
                  context,
                  exerciseId: item.exerciseId,
                  fallbackName: item.exerciseName,
                ),
                onLog: (rowIndex) => _logSet(item, rowIndex),
              );
            },
          ),
        ),
        _FinishButton(onTap: _finish),
      ],
    );
  }

  /// New per-set focus view. Big number for weight, huge tappable rep
  /// counter, ±2.5/±5 chips, ghost row with last session's data, and a
  /// full-width Complete Set button that triggers the rest overlay.
  Widget _buildFocusBody() {
    final items = widget.day.items;
    if (items.isEmpty) return const SizedBox.shrink();
    // Clamp cursor in case the routine shrank or all sets are done.
    final exIdx = _focusExerciseIdx.clamp(0, items.length - 1);
    final item = items[exIdx];
    final rows = _rowsByExercise[item.exerciseId] ?? const <_SetRowState>[];
    if (rows.isEmpty) return const SizedBox.shrink();
    final setIdx = _focusSetIdx.clamp(0, rows.length - 1);
    final row = rows[setIdx];
    final prev = _previousByExercise[item.exerciseId] ?? const <SetEntry>[];
    final prevSet = setIdx < prev.length ? prev[setIdx] : null;
    final priorBest = _previousBestE1RM[item.exerciseId] ?? 0;

    final allDone = items.every((it) {
      final rs = _rowsByExercise[it.exerciseId];
      return rs == null || rs.every((r) => r.done);
    });

    // Overload coaching for the next-set call. Same advisor the list
    // view uses — heuristic, no AI cost, runs every rebuild cheaply.
    final overload = OverloadAdvisor.hintFor(
      item: item,
      previousSets: prev,
      upColor: AppColors.accent,
      holdColor: AppColors.textSecondary,
      downColor: AppColors.water,
    );

    final allRows = _rowsByExercise.values.expand((r) => r).toList();
    final totalSetsAll = allRows.length;
    final completedAll = allRows.where((r) => r.done).length;

    return _FocusSetView(
      item: item,
      setIndex: setIdx,
      totalSets: rows.length,
      rowState: row,
      previousSet: prevSet,
      priorBestE1RM: priorBest,
      overloadHint: overload,
      setStartedAt: _focusSetStartedAt,
      workoutStartedAt: _session?.startedAt,
      completedSetsAll: completedAll,
      totalSetsAll: totalSetsAll,
      prPulse: _focusPrPulse,
      onLog: () => _logSet(item, setIdx),
      onPrev: () {
        setState(() {
          if (_focusSetIdx > 0) {
            _focusSetIdx--;
          } else if (_focusExerciseIdx > 0) {
            _focusExerciseIdx--;
            final pr = _rowsByExercise[items[_focusExerciseIdx].exerciseId];
            _focusSetIdx = pr == null ? 0 : pr.length - 1;
          }
          _focusSetStartedAt = DateTime.now();
        });
      },
      onNext: () {
        setState(() {
          final maxSet = rows.length - 1;
          if (_focusSetIdx < maxSet) {
            _focusSetIdx++;
          } else if (_focusExerciseIdx < items.length - 1) {
            _focusExerciseIdx++;
            _focusSetIdx = 0;
          }
          _focusSetStartedAt = DateTime.now();
        });
      },
      onFinish: _finish,
      finishVisible: allDone,
      onShowGuide: () => ExerciseGuideSheet.show(
        context,
        exerciseId: item.exerciseId,
        fallbackName: item.exerciseName,
      ),
    );
  }
}

class _SetRowState {
  final TextEditingController weight;
  final TextEditingController reps;
  bool done = false;
  // How hard the set was — "reps in reserve" captured via chips. Null
  // until the user taps one. Persisted onto the SetEntry at log time.
  double? rpe;
  // Working set by default; warmup/dropset/AMRAP/failure change how the
  // set counts in PR + volume math.
  SetType setType = SetType.normal;
  _SetRowState({required this.weight, required this.reps});
}

class _ExerciseCard extends StatelessWidget {
  final RoutinePlanItem item;
  final List<_SetRowState> rows;
  final List<SetEntry> previous;
  final OverloadHint? overloadHint;
  final VoidCallback onShowGuide;
  final void Function(int rowIndex) onLog;
  const _ExerciseCard({
    required this.item,
    required this.rows,
    required this.previous,
    required this.overloadHint,
    required this.onShowGuide,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onShowGuide,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(item.exerciseName,
                                style: AppText.sectionTitle
                                    .copyWith(fontSize: 16)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.textTertiary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.targetSets} × ${item.targetRepsLow}–${item.targetRepsHigh} reps',
                        style: AppText.meta.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (overloadHint != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: overloadHint!.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: overloadHint!.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(overloadHint!.icon,
                      size: 13, color: overloadHint!.color),
                  const SizedBox(width: 6),
                  Text(
                    overloadHint!.message,
                    style: TextStyle(
                      color: overloadHint!.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            _SetRow(
              setNumber: i + 1,
              state: rows[i],
              previous: i < previous.length ? previous[i] : null,
              onLog: () => onLog(i),
            ),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

String _fmtPrev(SetEntry s) {
  final w = s.weightKg;
  final wStr =
      w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
  return w > 0 ? '$wStr kg × ${s.reps}' : '${s.reps} reps';
}

class _SetRow extends StatelessWidget {
  final int setNumber;
  final _SetRowState state;
  final SetEntry? previous;
  final VoidCallback onLog;
  const _SetRow({
    required this.setNumber,
    required this.state,
    required this.previous,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: state.done
            ? AppColors.protein.withValues(alpha: 0.08)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.done
              ? AppColors.protein.withValues(alpha: 0.3)
              : AppColors.stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Text('$setNumber',
                    style: AppText.body.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    )),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _NumField(
                  controller: state.weight,
                  hint: 'kg',
                  enabled: !state.done,
                  allowDecimal: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('×',
                    style: AppText.meta.copyWith(
                        color: AppColors.textTertiary, fontSize: 14)),
              ),
              Expanded(
                child: _NumField(
                  controller: state.reps,
                  hint: 'reps',
                  enabled: !state.done,
                  allowDecimal: false,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: state.done ? null : onLog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        state.done ? AppColors.protein : AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    state.done ? Icons.check_rounded : Icons.add_rounded,
                    color: AppColors.onAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (previous != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 4, 0, 0),
              child: Text(
                'Last: ${_fmtPrev(previous!)}',
                style: AppText.meta.copyWith(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool allowDecimal;
  const _NumField({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.allowDecimal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: allowDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: allowDecimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        cursorColor: AppColors.accent,
        style: AppText.bigNumber.copyWith(
          fontSize: 16,
          color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: hint,
          hintStyle: AppText.meta.copyWith(
              color: AppColors.textTertiary, fontSize: 13),
        ),
      ),
    );
  }
}

// ===========================================================================
// FOCUS MODE WIDGETS
// ===========================================================================

class _FinishButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FinishButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            'Finish workout',
            style: TextStyle(
              color: AppColors.onAccent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-set focus screen — big weight, tappable rep counter, ghost row,
/// elapsed set timer, full-width Complete Set button. Pure presentation:
/// all state lives on _WorkoutLoggerPageState and is mutated via the
/// passed-in callbacks.
class _FocusSetView extends StatefulWidget {
  final RoutinePlanItem item;
  final int setIndex;
  final int totalSets;
  final _SetRowState rowState;
  final SetEntry? previousSet;
  final double priorBestE1RM;
  /// Heuristic coaching call for the next set ("Try 67.5 kg today" /
  /// "Add a rep this session"). Null when there's no history to base
  /// it on.
  final OverloadHint? overloadHint;
  final DateTime? setStartedAt;
  /// When the whole workout session started — powers the top TOTAL
  /// TIME chip.
  final DateTime? workoutStartedAt;
  /// Number of sets completed across all exercises in this day so far.
  final int completedSetsAll;
  /// Total number of sets planned across all exercises in this day.
  final int totalSetsAll;
  final bool prPulse;
  final VoidCallback onLog;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFinish;
  final bool finishVisible;
  final VoidCallback onShowGuide;

  const _FocusSetView({
    required this.item,
    required this.setIndex,
    required this.totalSets,
    required this.rowState,
    required this.previousSet,
    required this.priorBestE1RM,
    required this.overloadHint,
    required this.setStartedAt,
    required this.workoutStartedAt,
    required this.completedSetsAll,
    required this.totalSetsAll,
    required this.prPulse,
    required this.onLog,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
    required this.finishVisible,
    required this.onShowGuide,
  });

  @override
  State<_FocusSetView> createState() => _FocusSetViewState();
}

class _FocusSetViewState extends State<_FocusSetView> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Repaint the elapsed-set-timer once a second.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  double _weight() => double.tryParse(widget.rowState.weight.text.trim()) ?? 0;
  int _reps() => int.tryParse(widget.rowState.reps.text.trim()) ?? 0;

  void _setWeight(double v) {
    final clamped = v < 0 ? 0.0 : v;
    final s = clamped == clamped.roundToDouble()
        ? clamped.toInt().toString()
        : clamped.toStringAsFixed(1);
    widget.rowState.weight.text = s;
    setState(() {});
  }

  /// Apply a coaching call to the inputs. Parses the suggested weight
  /// out of the hint string when present (e.g. "Try 67.5 kg today")
  /// and pre-fills it; otherwise just nudges reps up by one. The
  /// underlying `OverloadAdvisor` already encodes the policy — we
  /// just translate its text into a button.
  void _acceptOverloadHint(OverloadHint hint) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*kg').firstMatch(hint.message);
    if (match != null) {
      final v = double.tryParse(match.group(1)!);
      if (v != null) {
        _setWeight(v);
        HapticFeedback.selectionClick();
        return;
      }
    }
    // No weight in the suggestion (e.g. "Add a rep this session") —
    // bump reps by one from the previous set's count.
    final prev = widget.previousSet;
    if (prev != null && prev.reps > 0) {
      widget.rowState.reps.text = '${prev.reps + 1}';
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _bumpReps(int delta) {
    final next = (_reps() + delta).clamp(0, 999);
    widget.rowState.reps.text = next.toString();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  String _fmtSetTimer() {
    if (widget.setStartedAt == null) return '00:00';
    final s = DateTime.now().difference(widget.setStartedAt!).inSeconds;
    final m = s ~/ 60;
    final ss = s % 60;
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  String _ghostText() {
    final p = widget.previousSet;
    if (p == null || (p.weightKg <= 0 && p.reps <= 0)) {
      return 'No history yet — set the bar.';
    }
    final w = p.weightKg;
    final wStr = w == w.roundToDouble()
        ? w.toInt().toString()
        : w.toStringAsFixed(1);
    final pieces = <String>[];
    if (w > 0) {
      pieces.add('Last: $wStr kg × ${p.reps}');
    } else {
      pieces.add('Last: ${p.reps} reps');
    }
    if (widget.priorBestE1RM > 0) {
      final b = widget.priorBestE1RM;
      final bStr = b == b.roundToDouble()
          ? b.toInt().toString()
          : b.toStringAsFixed(1);
      pieces.add('e1RM $bStr kg');
    }
    return pieces.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.rowState.done;
    final wt = _weight();
    final reps = _reps();
    final wtDisplay = wt == 0
        ? '0'
        : (wt == wt.roundToDouble()
            ? wt.toInt().toString()
            : wt.toStringAsFixed(1));
    // ── TOTAL TIME + completion progress row (top of focus screen) ─
    final ws = widget.workoutStartedAt;
    final elapsed = ws == null
        ? Duration.zero
        : DateTime.now().difference(ws);
    final elapsedMin =
        elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final elapsedSec =
        elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final completion = widget.totalSetsAll == 0
        ? 0.0
        : (widget.completedSetsAll / widget.totalSetsAll)
            .clamp(0.0, 1.0);
    final pctInt = (completion * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TOTAL TIME pill + completion progress bar with % ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      '$elapsedMin:$elapsedSec',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$pctInt%',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: completion,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceHigh,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // -- Header: exercise + set position + guide button -------------
          Row(
            children: [
              // Thumbnail from free-exercise-db (loads async, hidden until ready).
              Consumer(
                builder: (ctx, ref, _) {
                  final svc = ref.read(exerciseImageServiceProvider);
                  return FutureBuilder<String?>(
                    future: svc.firstImageFor(widget.item.exerciseName),
                    builder: (ctx, snap) {
                      final url = snap.data;
                      if (url == null) return const SizedBox(width: 4);
                      return GestureDetector(
                        onTap: widget.onShowGuide,
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              fadeInDuration:
                                  const Duration(milliseconds: 300),
                              placeholder: (_, _) => Container(
                                  color: AppColors.surfaceHigh),
                              errorWidget: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onShowGuide,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.exerciseName,
                          style: AppText.sectionTitle.copyWith(fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Text(
                  'SET ${widget.setIndex + 1} / ${widget.totalSets}',
                  style: AppText.label.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _ghostText(),
            style: AppText.meta.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          // Next-set coaching call. Surfaces above the weight number
          // so the user reads "Try 67.5 kg today" before they touch
          // the chips. Tap to load that weight into the input.
          if (widget.overloadHint != null && !widget.rowState.done) ...[
            const SizedBox(height: 10),
            _OverloadBanner(
              hint: widget.overloadHint!,
              onAccept: () => _acceptOverloadHint(widget.overloadHint!),
            ),
          ],
          const SizedBox(height: 22),

          // -- WEIGHT block ---------------------------------------------
          Center(
            child: Column(
              children: [
                Text('WEIGHT', style: AppText.label.copyWith(fontSize: 11)),
                const SizedBox(height: 6),
                AnimatedScale(
                  scale: widget.prPulse ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTap: done
                        ? null
                        : () => _showWeightInputDialog(context),
                    child: ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: widget.prPulse
                            ? [AppColors.accent, AppColors.calorieFrom]
                            : [
                                AppColors.textPrimary,
                                AppColors.textPrimary.withValues(alpha: 0.85),
                              ],
                      ).createShader(rect),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            wtDisplay,
                            style: AppText.giantNumber.copyWith(fontSize: 80),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'kg',
                              style: AppText.meta.copyWith(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepChip(
                      label: '-5',
                      onTap: done ? null : () => _setWeight(wt - 5),
                    ),
                    const SizedBox(width: 8),
                    _StepChip(
                      label: '-2.5',
                      onTap: done ? null : () => _setWeight(wt - 2.5),
                    ),
                    const SizedBox(width: 8),
                    _StepChip(
                      label: '+2.5',
                      primary: true,
                      onTap: done ? null : () => _setWeight(wt + 2.5),
                    ),
                    const SizedBox(width: 8),
                    _StepChip(
                      label: '+5',
                      primary: true,
                      onTap: done ? null : () => _setWeight(wt + 5),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // -- REP counter ----------------------------------------------
          Center(
            child: Column(
              children: [
                Text('REPS · tap to count',
                    style: AppText.label.copyWith(fontSize: 11)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: done ? null : () => _bumpReps(1),
                  onVerticalDragEnd: (d) {
                    if (done) return;
                    if (d.primaryVelocity != null &&
                        d.primaryVelocity! > 200) {
                      _bumpReps(-1);
                    }
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$reps',
                      style: AppText.giantNumber.copyWith(
                        fontSize: 96,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepChip(
                      label: '-1',
                      onTap: done ? null : () => _bumpReps(-1),
                    ),
                    const SizedBox(width: 8),
                    _StepChip(
                      label: 'tap above to +1',
                      onTap: null,
                    ),
                    const SizedBox(width: 8),
                    _StepChip(
                      label: '+1',
                      primary: true,
                      onTap: done ? null : () => _bumpReps(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // -- Set timer + nav arrows -----------------------------------
          Row(
            children: [
              IconButton(
                onPressed: widget.onPrev,
                icon: Icon(Icons.chevron_left_rounded,
                    color: AppColors.textSecondary),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(_fmtSetTimer(),
                  style: AppText.bigNumber.copyWith(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  )),
              const Spacer(),
              IconButton(
                onPressed: widget.onNext,
                icon: Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // -- Complete Set button --------------------------------------
          GestureDetector(
            onTap: done || reps <= 0 ? null : widget.onLog,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 60,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.protein.withValues(alpha: 0.15)
                    : reps <= 0
                        ? AppColors.surfaceHigh
                        : AppColors.accent,
                borderRadius: BorderRadius.circular(20),
                border: done
                    ? Border.all(
                        color: AppColors.protein.withValues(alpha: 0.4))
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.flash_on_rounded,
                    color: done
                        ? AppColors.protein
                        : reps <= 0
                            ? AppColors.textTertiary
                            : AppColors.onAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    done ? 'Set logged' : 'Complete set',
                    style: TextStyle(
                      color: done
                          ? AppColors.protein
                          : reps <= 0
                              ? AppColors.textTertiary
                              : AppColors.onAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (widget.finishVisible) ...[
            const SizedBox(height: 12),
            _FinishButton(onTap: widget.onFinish),
          ],
        ],
      ),
    );
  }

  Future<void> _showWeightInputDialog(BuildContext context) async {
    final ctl = TextEditingController(text: widget.rowState.weight.text);
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set weight',
                  style: AppText.sectionTitle.copyWith(fontSize: 17)),
              const SizedBox(height: 12),
              Container(
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
                        controller: ctl,
                        autofocus: true,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        cursorColor: AppColors.accent,
                        style: AppText.bigNumber.copyWith(fontSize: 22),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                    Text('kg',
                        style: AppText.meta.copyWith(
                            fontSize: 13, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel',
                        style: AppText.body
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx)
                        .pop(double.tryParse(ctl.text.trim())),
                    child: Text('Set',
                        style: AppText.body.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (v != null && v >= 0) _setWeight(v);
  }
}

/// Compact "next-set call" banner shown above the weight number in
/// the focus view. Tap = pre-fill the suggestion into the inputs.
class _OverloadBanner extends StatelessWidget {
  final OverloadHint hint;
  final VoidCallback onAccept;
  const _OverloadBanner({required this.hint, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAccept,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: hint.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hint.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: hint.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(hint.icon, size: 14, color: hint.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT-SET CALL',
                      style: AppText.label.copyWith(
                          fontSize: 10,
                          color: hint.color,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 1),
                  Text(
                    hint.message,
                    style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: hint.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Apply',
                  style: TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const _StepChip({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.surfaceHigh
              : primary
                  ? AppColors.accent.withValues(alpha: 0.14)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? AppColors.stroke
                : primary
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : AppColors.stroke,
          ),
        ),
        child: Text(
          label,
          style: AppText.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: disabled
                ? AppColors.textTertiary
                : primary
                    ? AppColors.accent
                    : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Full-screen rest countdown that takes over after a set logs. Big
/// circular ring, breathing digits, ±15 s buttons, Skip at bottom.
class _RestOverlay extends StatelessWidget {
  final int remaining;
  final int total;
  final VoidCallback onSkip;
  final ValueChanged<int> onAdd;
  const _RestOverlay({
    required this.remaining,
    required this.total,
    required this.onSkip,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final m = remaining ~/ 60;
    final s = remaining % 60;
    final progress = total == 0 ? 0.0 : remaining / total;
    return Positioned.fill(
      child: Container(
        color: AppColors.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                // ── Header: REST label + optional Skip ──────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                AppColors.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'REST',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // ── Huge sporty countdown (MM : SS) ─────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                    key: ValueKey(remaining),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 172,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -8,
                      height: 0.85,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'SECONDS LEFT',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 28),
                // Slim progress bar (visual reinforcement of the number)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 260,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Adjustment chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepChip(label: '-15s', onTap: () => onAdd(-15)),
                    const SizedBox(width: 10),
                    _StepChip(
                      label: '+15s',
                      primary: true,
                      onTap: () => onAdd(15),
                    ),
                    const SizedBox(width: 10),
                    _StepChip(
                      label: '+30s',
                      primary: true,
                      onTap: () => onAdd(30),
                    ),
                  ],
                ),
                const Spacer(),
                // ── DONE button: dismiss rest, start the next set now ─
                GestureDetector(
                  onTap: onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 62,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(31),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'DONE',
                      style: TextStyle(
                        color: AppColors.onAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when starting a workout fails (e.g. a database read error) so
/// the user gets a clear message + retry instead of an endless skeleton.
class _StartErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  const _StartErrorView({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                "Couldn't start the workout",
                style: AppText.sectionTitle.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: onClose,
                    child: Text('Close',
                        style: AppText.body
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton shown while the session + set history load — mirrors the
/// instruction overlay layout 1:1 (image zone, TOTAL pill, X button,
/// bottom card with timer, input tiles, progress bar and nav row) so
/// the real screen appears to "fill in" rather than pop from a spinner.
class _OngoingWorkoutSkeleton extends StatelessWidget {
  const _OngoingWorkoutSkeleton();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topH = mq.size.height * 0.44;
    return Stack(
      children: [
        // Image zone
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topH,
          child: const SkeletonBox(
            height: double.infinity,
            borderRadius: BorderRadius.zero,
          ),
        ),
        // TOTAL TIME pill
        Positioned(
          top: mq.padding.top + 14,
          left: 16,
          child: SkeletonBox(
              width: 62, height: 76,
              borderRadius: BorderRadius.circular(16)),
        ),
        // X button
        Positioned(
          top: mq.padding.top + 16,
          right: 16,
          child: const SkeletonCircle(size: 48),
        ),
        // Bottom card
        Positioned(
          top: topH - 24,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding:
                EdgeInsets.fromLTRB(20, 24, 20, mq.padding.bottom + 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 150, height: 44),
                        SizedBox(height: 8),
                        SkeletonBox(width: 90, height: 12),
                      ],
                    ),
                    const Spacer(),
                    SkeletonBox(
                        width: 40, height: 40,
                        borderRadius: BorderRadius.circular(12)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: const [
                    Expanded(
                        child: SkeletonBox(
                            height: 86,
                            borderRadius:
                                BorderRadius.all(Radius.circular(18)))),
                    SizedBox(width: 12),
                    Expanded(
                        child: SkeletonBox(
                            height: 86,
                            borderRadius:
                                BorderRadius.all(Radius.circular(18)))),
                  ],
                ),
                const SizedBox(height: 14),
                const SkeletonBox(
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(14))),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SkeletonBox(width: 56, height: 40),
                    SkeletonCircle(size: 92),
                    SkeletonBox(width: 56, height: 40),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen rest page for the focus/overlay flow. Unlike [_RestOverlay]
/// this counts UP with no fixed limit — supersets, alternating exercises
/// and gym chatter make rest length the user's call, so it stopwatches
/// until DONE is tapped. Ticks with its own internal timer so the parent
/// page (and the instruction overlay beneath) don't rebuild every second.
class _FullRestPage extends StatefulWidget {
  final DateTime startedAt;
  final String nextUp;
  final VoidCallback onDone;
  /// Opens the upcoming exercise's detail page (photos, video, cues) so
  /// the user can prepare while resting.
  final VoidCallback onPreview;
  /// "How did that set feel?" — current pick for the just-logged set and
  /// a callback to change it. Stored on the SetEntry for the AI coach.
  final SetFeeling feeling;
  final ValueChanged<SetFeeling> onFeeling;
  /// Recommended rest for this break — shown as a target; the timer turns
  /// green once the user has rested at least this long.
  final int suggestedRestSeconds;
  /// True when the whole day is logged — the screen becomes a completion
  /// screen (add another exercise / finish → summary) instead of a rest.
  final bool isComplete;
  final VoidCallback onFinish;
  final VoidCallback onAddExercise;
  const _FullRestPage({
    required this.startedAt,
    required this.nextUp,
    required this.onDone,
    required this.onPreview,
    required this.feeling,
    required this.onFeeling,
    required this.suggestedRestSeconds,
    required this.isComplete,
    required this.onFinish,
    required this.onAddExercise,
  });

  @override
  State<_FullRestPage> createState() => _FullRestPageState();
}

class _FullRestPageState extends State<_FullRestPage> {
  Timer? _timer;
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    _secs = DateTime.now().difference(widget.startedAt).inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() =>
          _secs = DateTime.now().difference(widget.startedAt).inSeconds);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = (_secs ~/ 60).clamp(0, 99);
    final s = _secs % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    // Rest-timer intelligence: once elapsed ≥ the suggested rest, the
    // timer greens up to signal "you're recovered — go".
    final suggested = widget.suggestedRestSeconds;
    final rested = _secs >= suggested;
    final restColor = const Color(0xFF2FB673);
    final sugStr =
        '${(suggested ~/ 60).toString().padLeft(2, '0')}:${(suggested % 60).toString().padLeft(2, '0')}';
    // nextUp arrives as "LEG PRESS · SET 2 OF 4" — split for hierarchy.
    final parts = widget.nextUp.split(' · ');
    final nextName = parts.isNotEmpty ? parts.first : '';
    final nextSub = parts.length > 1 ? parts.sublist(1).join(' · ') : '';
    return Positioned.fill(
      child: Container(
        color: AppColors.bg,
        child: Stack(
          children: [
            // Soft accent glow behind the timer — subtle depth, static.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.95,
                      colors: [
                        AppColors.accent.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.accent
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'REST',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // ── One-line, full-width sporty count-up ────────
                    // BoxFit.fill inside a fixed-height box stretches the
                    // digits vertically — always exactly one line across
                    // the full width, but taller than natural proportions
                    // for that condensed-scoreboard look.
                    SizedBox(
                      height:
                          MediaQuery.of(context).size.height * 0.26,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: mm),
                              TextSpan(
                                text: ':',
                                style:
                                    TextStyle(color: AppColors.accent),
                              ),
                              TextSpan(text: ss),
                            ],
                          ),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 220,
                            fontWeight: FontWeight.w900,
                            color: rested ? restColor : AppColors.textPrimary,
                            letterSpacing: -10,
                            height: 0.85,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.isComplete
                          ? 'ALL SETS DONE 🎉'
                          : rested
                              ? 'RESTED · READY TO GO'
                              : 'SUGGESTED REST $sugStr',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: rested ? restColor : AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const Spacer(),
                    // ── "How did that set feel?" — captured here on the
                    // rest screen and stored on the just-logged set so the
                    // AI coach can factor effort + pain into its advice.
                    _FeelingPicker(
                      value: widget.feeling,
                      onChanged: widget.onFeeling,
                    ),
                    const SizedBox(height: 16),
                    // ── Up-next card — tap to preview the exercise ──
                    // Opens photos / video / form cues so the user can
                    // prepare for the coming set while resting. Hidden on the
                    // completion screen — there's nothing "up next".
                    if (!widget.isComplete && nextName.isNotEmpty) ...[
                      GestureDetector(
                        onTap: widget.onPreview,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.stroke),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius:
                                      BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'UP NEXT',
                                          style: TextStyle(
                                            color:
                                                AppColors.textTertiary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        if (nextSub.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '· $nextSub',
                                            style: TextStyle(
                                              color: AppColors
                                                  .textTertiary,
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w800,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      nextName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'TAP TO PREVIEW · HOW TO DO IT',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.accent,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.isComplete) ...[
                      // ── Add another exercise mid-workout ──────────
                      GestureDetector(
                        onTap: widget.onAddExercise,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color:
                                    AppColors.accent.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 18, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Text(
                                'ADD ANOTHER EXERCISE',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Finish → summary ──────────────────────────
                      GestureDetector(
                        onTap: widget.onFinish,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(31),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.accent.withValues(alpha: 0.35),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'FINISH WORKOUT',
                            style: TextStyle(
                              color: AppColors.onAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      // ── DONE: rest over, start the next set ─────────
                      GestureDetector(
                        onTap: widget.onDone,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(31),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.accent.withValues(alpha: 0.35),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'DONE',
                            style: TextStyle(
                              color: AppColors.onAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "How did that set feel?" picker on the rest screen. Five emoji chips
/// from easy → brutal, plus a distinct pain flag. Optional — the user can
/// ignore it and just hit DONE. Selection is stored on the SetEntry.
class _FeelingPicker extends StatelessWidget {
  final SetFeeling value;
  final ValueChanged<SetFeeling> onChanged;
  const _FeelingPicker({required this.value, required this.onChanged});

  static const _options = [
    (SetFeeling.easy, '😌', 'Easy'),
    (SetFeeling.good, '💪', 'Good'),
    (SetFeeling.hard, '😤', 'Hard'),
    (SetFeeling.brutal, '🥵', 'Brutal'),
    (SetFeeling.pain, '⚠️', 'Pain'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOW DID THAT SET FEEL?',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final o in _options) ...[
              Expanded(child: _chip(o.$1, o.$2, o.$3)),
              if (o.$1 != _options.last.$1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chip(SetFeeling f, String emoji, String label) {
    final active = value == f;
    // Pain is a caution, not an achievement — tint it with the danger
    // colour when picked so it reads as "flagged".
    final accent = f == SetFeeling.pain ? AppColors.danger : AppColors.accent;
    return GestureDetector(
      // Tap again to clear the pick.
      onTap: () => onChanged(active ? SetFeeling.unset : f),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.18)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent : AppColors.stroke,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? accent : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
