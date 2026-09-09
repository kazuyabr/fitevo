import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/workout_session.dart';
import '../../services/workout/pr_tracker.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Post-workout summary shown when a session is finished: headline stats
/// (volume, sets, duration, PRs) on a hero card you can share, plus the
/// top lift and a per-exercise recap.
class WorkoutSummaryPage extends ConsumerStatefulWidget {
  final WorkoutSession session;
  final String dayName;
  final int prCount;
  const WorkoutSummaryPage({
    super.key,
    required this.session,
    required this.dayName,
    required this.prCount,
  });

  @override
  ConsumerState<WorkoutSummaryPage> createState() =>
      _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends ConsumerState<WorkoutSummaryPage> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  // ---- derived stats -------------------------------------------------------

  List<SetEntry> get _working => widget.session.sets
      .where((s) => !s.isWarmup && s.weightKg > 0 && s.reps > 0)
      .toList();

  int get _sets => _working.length;

  double get _tonnage =>
      _working.fold<double>(0, (a, s) => a + s.weightKg * s.reps);

  Duration get _duration => widget.session.duration;

  int _calories(double bodyKg) {
    // Resistance training ≈ 5 METs. kcal = MET × 3.5 × kg / 200 × minutes.
    final kg = bodyKg > 0 ? bodyKg : 75;
    final mins = _duration.inMinutes.clamp(0, 600);
    return (5.0 * 3.5 * kg / 200 * mins).round();
  }

  ({String name, double e1rm})? get _topLift {
    String? name;
    double best = 0;
    for (final s in _working) {
      final e = PrTracker.estimatedFromSet(s);
      if (e > best) {
        best = e;
        name = s.exerciseName;
      }
    }
    final n = name;
    return n == null ? null : (name: n, e1rm: best);
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final ctx = _cardKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/workout_${widget.session.id}.png');
      await file.writeAsBytes(bytes);
      final prBit = widget.prCount > 0
          ? ', ${widget.prCount} PR${widget.prCount == 1 ? '' : 's'}'
          : '';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${widget.dayName} done 💪 '
            '${_tonnage.toStringAsFixed(0)} kg moved, $_sets sets$prBit.',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotShare)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final profile = ref.watch(profileStreamProvider).value;
    final kcal = _calories(profile?.weightKg ?? 0);
    final top = _topLift;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Shareable hero card ───────────────────────
                    RepaintBoundary(
                      key: _cardKey,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accent,
                              Color.lerp(
                                  AppColors.accent, Colors.black, 0.28)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt_rounded,
                                    color: AppColors.onAccent, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'WORKOUT COMPLETE',
                                  style: TextStyle(
                                    color: AppColors.onAccent
                                        .withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.dayName,
                              style: TextStyle(
                                color: AppColors.onAccent,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _stat(_tonnage.toStringAsFixed(0),
                                    'KG MOVED'),
                                _stat('$_sets', 'SETS'),
                                _stat('${_duration.inMinutes}', 'MIN'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _stat('$kcal', '≈ KCAL'),
                                _stat('${widget.prCount}', 'PRs'),
                                if (top != null)
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOP LIFT',
                                          style: TextStyle(
                                            color: AppColors.onAccent
                                                .withValues(alpha: 0.75),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          top.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.onAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.prCount > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.emoji_events_rounded,
                                color: AppColors.accent, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'New personal record on ${widget.prCount} '
                                'lift${widget.prCount == 1 ? '' : 's'} today!',
                                style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(AppLocalizations.of(context)!.thisSession, style: AppText.label),
                    const SizedBox(height: 10),
                    ..._exerciseRecap(),
                  ],
                ),
              ),
            ),
            // ── Actions ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _share,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(color: AppColors.stroke),
                        ),
                        child: _sharing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.accent),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.ios_share_rounded,
                                      size: 18,
                                      color: AppColors.textPrimary),
                                  const SizedBox(width: 8),
                                  Text(AppLocalizations.of(context)!.share,
                                      style: AppText.body.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Text('Done',
                            style: AppText.body.copyWith(
                                color: AppColors.onAccent,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppColors.onAccent,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.onAccent.withValues(alpha: 0.75),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _exerciseRecap() {
    // Group working sets by exercise, in first-seen order.
    final order = <String>[];
    final byName = <String, List<SetEntry>>{};
    for (final s in _working) {
      byName.putIfAbsent(s.exerciseName, () {
        order.add(s.exerciseName);
        return [];
      }).add(s);
    }
    if (order.isEmpty) {
      return [
        Text(AppLocalizations.of(context)!.noWorkingSetsLogged, style: AppText.body),
      ];
    }
    return [
      for (final name in order)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
              ),
              Text(
                '${byName[name]!.length} × '
                '${byName[name]!.map((s) => s.reps).join('/')}',
                style: AppText.meta.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
    ];
  }
}
