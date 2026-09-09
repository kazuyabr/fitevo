import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cardio_session.dart';
import '../../data/models/enums.dart';
import '../../services/workout/cardio_math.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Configurable HIIT / interval timer — set rounds, work and rest, then
/// run a big work/rest countdown with haptics on each transition. Logs a
/// HIIT [CardioSession] when finished.
class IntervalTimerPage extends ConsumerStatefulWidget {
  const IntervalTimerPage({super.key});

  @override
  ConsumerState<IntervalTimerPage> createState() => _IntervalTimerPageState();
}

enum _Phase { setup, work, rest, done }

class _IntervalTimerPageState extends ConsumerState<IntervalTimerPage> {
  int _rounds = 8;
  int _work = 30;
  int _rest = 15;

  _Phase _phase = _Phase.setup;
  int _round = 1;
  int _remaining = 0;
  Timer? _timer;
  bool _paused = false;
  int _elapsedSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.work;
      _round = 1;
      _remaining = _work;
      _elapsedSeconds = 0;
      _paused = false;
    });
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_paused || !mounted) return;
    setState(() {
      _elapsedSeconds++;
      _remaining--;
      if (_remaining > 0) return;
      // Phase transition.
      if (_phase == _Phase.work) {
        if (_rest > 0) {
          _phase = _Phase.rest;
          _remaining = _rest;
          HapticFeedback.mediumImpact();
        } else {
          _nextRoundOrDone();
        }
      } else if (_phase == _Phase.rest) {
        _nextRoundOrDone();
      }
    });
  }

  void _nextRoundOrDone() {
    if (_round >= _rounds) {
      _phase = _Phase.done;
      _timer?.cancel();
      HapticFeedback.heavyImpact();
      _logSession();
    } else {
      _round++;
      _phase = _Phase.work;
      _remaining = _work;
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _logSession() async {
    final now = DateTime.now();
    final mins = (_elapsedSeconds / 60).round().clamp(1, 600);
    final bw = ref.read(profileStreamProvider).valueOrNull?.weightKg ?? 0;
    // Fold into the day's activity so the calorie target reflects it —
    // same model the home screen + activity logger use.
    final nutrition = ref.read(nutritionRepoProvider);
    final log = await nutrition.getOrCreateLog(now);
    await nutrition.upsertDailyLog(now,
        otherCardioMinutes: log.otherCardioMinutes + mins);
    // Per-bout history entry.
    await ref.read(cardioRepoProvider).add(CardioSession()
      ..dateKey = CardioSession.keyFor(now)
      ..type = CardioType.hiit
      ..startedAt = now
      ..durationSeconds = _elapsedSeconds
      ..calories = CardioMath.estimateCalories(
          type: CardioType.hiit, minutes: mins, bodyweightKg: bw));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isWork = _phase == _Phase.work;
    final isRest = _phase == _Phase.rest;
    final phaseColor = isRest ? AppColors.water : AppColors.accent;

    return Scaffold(
      backgroundColor: _phase == _Phase.setup || _phase == _Phase.done
          ? AppColors.bg
          : phaseColor,
      appBar: _phase == _Phase.setup
          ? AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              title: Text(AppLocalizations.of(context)!.intervalTimer, style: AppText.sectionTitle),
              iconTheme: IconThemeData(color: AppColors.textPrimary),
            )
          : null,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.setup => _buildSetup(),
          _Phase.done => _buildDone(),
          _ => _buildRunning(isWork),
        },
      ),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepper('ROUNDS', _rounds, (v) => setState(() => _rounds = v),
              min: 1, max: 30, step: 1),
          const SizedBox(height: 14),
          _stepper('WORK (sec)', _work, (v) => setState(() => _work = v),
              min: 5, max: 300, step: 5),
          const SizedBox(height: 14),
          _stepper('REST (sec)', _rest, (v) => setState(() => _rest = v),
              min: 0, max: 300, step: 5),
          const SizedBox(height: 24),
          Text(
            'Total: ~${((_work + _rest) * _rounds / 60).toStringAsFixed(0)} min',
            style: AppText.meta.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _start,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(AppLocalizations.of(context)!.start,
                  style: AppText.body.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunning(bool isWork) {
    return Column(
      children: [
        const Spacer(),
        Text(
          isWork ? 'WORK' : AppLocalizations.of(context)!.rest,
          style: TextStyle(
            color: AppColors.onAccent,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_remaining',
          style: TextStyle(
            color: AppColors.onAccent,
            fontSize: 140,
            fontWeight: FontWeight.w900,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Text('ROUND $_round / $_rounds',
            style: TextStyle(
              color: AppColors.onAccent.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            )),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: _ctrlBtn(
                  _paused ? 'Resume' : 'Pause',
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  () => setState(() => _paused = !_paused),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ctrlBtn('Stop', Icons.stop_rounded, () {
                  _timer?.cancel();
                  setState(() => _phase = _Phase.setup);
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 72, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.sessionComplete,
              style: AppText.sectionTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          Text('${(_elapsedSeconds / 60).toStringAsFixed(0)} min · logged',
              style: AppText.meta.copyWith(fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text('Done',
                  style: AppText.body.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.onAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.onAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.onAccent, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged,
      {required int min, required int max, required int step}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Text(label, style: AppText.label),
          const Spacer(),
          _rndBtn(Icons.remove_rounded,
              () => onChanged((value - step).clamp(min, max))),
          SizedBox(
            width: 56,
            child: Center(
              child: Text('$value',
                  style: AppText.sectionTitle.copyWith(fontSize: 22)),
            ),
          ),
          _rndBtn(Icons.add_rounded,
              () => onChanged((value + step).clamp(min, max))),
        ],
      ),
    );
  }

  Widget _rndBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      );
}
