import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../../l10n/app_localizations.dart';

class _Move {
  final String name;
  final int seconds;
  final String cue;
  const _Move(this.name, this.seconds, this.cue);
}

class _Flow {
  final String id;
  final String name;
  final String subtitle;
  final List<_Move> moves;
  const _Flow(this.id, this.name, this.subtitle, this.moves);
}

/// Guided warm-up / cool-down / mobility flows — a timed sequence of
/// movements that auto-advance, so users prep and recover properly.
class MobilityFlowPage extends StatefulWidget {
  const MobilityFlowPage({super.key});

  @override
  State<MobilityFlowPage> createState() => _MobilityFlowPageState();
}

class _MobilityFlowPageState extends State<MobilityFlowPage> {
  static const _flows = [
    _Flow('warmup', 'Warm-up', 'Dynamic · before lifting', [
      _Move('Jumping jacks', 40, 'Loose and rhythmic — raise the heart rate.'),
      _Move('Arm circles', 30, 'Forward then backward, big controlled circles.'),
      _Move('Leg swings', 40, 'Front-to-back each leg, hold something for balance.'),
      _Move('Hip openers', 40, 'Open the gate — lift knee out and around.'),
      _Move('Bodyweight squats', 40, 'Slow and deep, drive the knees out.'),
      _Move('Torso twists', 30, 'Rotate through the mid-back, relaxed arms.'),
      _Move('Inchworm', 40, 'Walk hands out to plank, walk feet up.'),
    ]),
    _Flow('cooldown', 'Cool-down', 'Static · after lifting', [
      _Move('Quad stretch', 40, 'Heel to glute, knees together, stand tall.'),
      _Move('Hamstring stretch', 40, 'Hinge over a straight leg, soft knee.'),
      _Move('Chest doorway stretch', 40, 'Forearm on frame, rotate away gently.'),
      _Move('Child\'s pose', 45, 'Hips to heels, arms long, breathe into the back.'),
      _Move('Figure-four glute', 45, 'Ankle over knee, draw the thigh in.'),
      _Move('Cat–cow', 40, 'Flow between arch and round with the breath.'),
    ]),
    _Flow('mobility', 'Full mobility', 'Joints · anytime', [
      _Move('Neck rolls', 30, 'Slow half-circles, no forcing.'),
      _Move('Shoulder dislocates', 40, 'Band or towel overhead and back.'),
      _Move('Thoracic rotations', 40, 'Quadruped, hand behind head, open up.'),
      _Move('90/90 hip switches', 45, 'Rotate both knees side to side.'),
      _Move('Deep squat hold', 45, 'Sink in, pry knees out with elbows.'),
      _Move('Ankle rocks', 30, 'Knee over toe, drive the ankle forward.'),
    ]),
  ];

  _Flow? _flow;
  int _index = 0;
  int _remaining = 0;
  Timer? _timer;
  bool _paused = false;
  bool _done = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startFlow(_Flow f) {
    setState(() {
      _flow = f;
      _index = 0;
      _remaining = f.moves.first.seconds;
      _done = false;
      _paused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_paused || !mounted) return;
    setState(() {
      _remaining--;
      if (_remaining <= 0) _next();
    });
  }

  void _next() {
    final f = _flow!;
    if (_index >= f.moves.length - 1) {
      _timer?.cancel();
      _done = true;
      HapticFeedback.mediumImpact();
      return;
    }
    _index++;
    _remaining = f.moves[_index].seconds;
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _flow == null
          ? AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              title: Text(loc.mobility, style: AppText.sectionTitle),
              iconTheme: IconThemeData(color: AppColors.textPrimary),
            )
          : null,
      body: SafeArea(
        child: _flow == null
            ? _buildPicker()
            : _done
                ? _buildDone()
                : _buildRunning(),
      ),
    );
  }

  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        for (final f in _flows)
          GestureDetector(
            onTap: () => _startFlow(f),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            style: AppText.body.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(
                          '${f.subtitle} · ${f.moves.length} moves · '
                          '~${(f.moves.fold<int>(0, (a, m) => a + m.seconds) / 60).round()} min',
                          style: AppText.meta.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.accent, size: 30),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRunning() {
    final f = _flow!;
    final move = f.moves[_index];
    return Column(
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_index + 1) / f.moves.length,
          minHeight: 4,
          backgroundColor: AppColors.surfaceHigh,
          valueColor: AlwaysStoppedAnimation(AppColors.accent),
        ),
        const Spacer(),
        Text('${_index + 1} / ${f.moves.length}',
            style: AppText.label.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(move.name,
              textAlign: TextAlign.center,
              style: AppText.sectionTitle.copyWith(fontSize: 28)),
        ),
        const SizedBox(height: 20),
        Text('$_remaining',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 96,
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(move.cue,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                  color: AppColors.textSecondary, height: 1.4)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: _btn(_paused ? 'Resume' : 'Pause',
                    _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    () => setState(() => _paused = !_paused)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn('Skip', Icons.skip_next_rounded,
                    () => setState(_next)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 72, color: AppColors.accent),
          const SizedBox(height: 16),
          Text('${_flow!.name} complete',
              style: AppText.sectionTitle.copyWith(fontSize: 20)),
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

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
