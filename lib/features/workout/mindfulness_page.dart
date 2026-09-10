import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Guided mindfulness session for yoga / meditation users — pick a length
/// and a mode (breathe with an expanding-circle pacer, or a quiet timer),
/// then run a calming full-screen session. Logs the minutes when done.
class MindfulnessPage extends ConsumerStatefulWidget {
  const MindfulnessPage({super.key});

  @override
  ConsumerState<MindfulnessPage> createState() => _MindfulnessPageState();
}

enum _Mode { breathe, meditate }

enum _Stage { setup, running, done }

class _MindfulnessPageState extends ConsumerState<MindfulnessPage>
    with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.breathe;
  int _minutes = 5;
  _Stage _stage = _Stage.setup;

  int _remaining = 0;
  int _doneSeconds = 0;
  Timer? _timer;
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4), // inhale 4s / exhale 4s
  );

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _stage = _Stage.running;
      _remaining = _minutes * 60;
    });
    if (_mode == _Mode.breathe) _breath.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _finish();
    });
  }

  void _finish() {
    _timer?.cancel();
    _breath.stop();
    HapticFeedback.mediumImpact();
    // Actual time spent (ends early → less than the picked length).
    // Mindfulness is recovery, not cardio — it doesn't log calories.
    _doneSeconds = (_minutes * 60 - _remaining).clamp(0, _minutes * 60);
    setState(() => _stage = _Stage.done);
  }

  String get _doneLabel {
    final m = _doneSeconds ~/ 60;
    final s = _doneSeconds % 60;
    if (m > 0) return '$m min${s > 0 ? ' ${s}s' : ''} of mindfulness';
    return '${s}s of mindfulness';
  }

  String get _fmt {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _stage == _Stage.running
          ? const Color(0xFF12233A)
          : AppColors.bg,
      appBar: _stage == _Stage.setup
          ? AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              title: Text(AppLocalizations.of(context)!.mindfulness, style: AppText.sectionTitle),
              iconTheme: IconThemeData(color: AppColors.textPrimary),
            )
          : null,
      body: SafeArea(
        child: switch (_stage) {
          _Stage.setup => _buildSetup(),
          _Stage.running => _buildRunning(),
          _Stage.done => _buildDone(),
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
          Text(AppLocalizations.of(context)!.mode, style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              _modeChip(_Mode.breathe, 'Breathe', Icons.air_rounded),
              const SizedBox(width: 10),
              _modeChip(
                  _Mode.meditate, 'Meditate', Icons.self_improvement_rounded),
            ],
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context)!.length, style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in [3, 5, 10, 15, 20])
                GestureDetector(
                  onTap: () => setState(() => _minutes = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _minutes == m
                          ? AppColors.accent
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _minutes == m
                              ? AppColors.accent
                              : AppColors.stroke),
                    ),
                    child: Text('$m min',
                        style: TextStyle(
                          color: _minutes == m
                              ? AppColors.onAccent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
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
              child: Text(AppLocalizations.of(context)!.begin,
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

  Widget _modeChip(_Mode m, String label, IconData icon) {
    final active = _mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = m),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: active ? AppColors.accent : AppColors.stroke),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: active ? AppColors.onAccent : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    color: active ? AppColors.onAccent : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunning() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        const Spacer(),
        SizedBox(
          height: 300,
          child: Center(
            child: AnimatedBuilder(
              animation: _breath,
              builder: (context, _) {
                final t =
                    _mode == _Mode.breathe ? _breath.value : 0.5; // static-ish
                final size = 120 + t * 100;
                final inhaling = _breath.status == AnimationStatus.forward;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.water.withValues(alpha: 0.25),
                        border: Border.all(
                            color: AppColors.water.withValues(alpha: 0.6),
                            width: 2),
                      ),
                    ),
                    if (_mode == _Mode.breathe) ...[
                      const SizedBox(height: 20),
                      Text(inhaling ? loc.breatheIn : loc.breatheOut,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          )),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        const Spacer(),
        Text(_fmt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _finish,
          child: Text(AppLocalizations.of(context)!.end,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDone() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_rounded, size: 72, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.wellDone, style: AppText.sectionTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          Text(_doneLabel, style: AppText.meta.copyWith(fontSize: 13)),
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
              child: Text(loc.done,
                  style: AppText.body.copyWith(
                      color: AppColors.onAccent, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
