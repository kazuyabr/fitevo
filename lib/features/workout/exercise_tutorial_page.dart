import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen in-app tutorial player. Resolves a playable video URL
/// for [exerciseName] via `ExerciseVideoService` (Pexels stock first,
/// then a live YouTube search) and plays it with `video_player`.
///
/// If resolution fails entirely (offline / YouTube blocked) we surface
/// an error state with a fallback button that launches a YouTube search
/// externally.
class ExerciseTutorialPage extends ConsumerStatefulWidget {
  final String exerciseName;
  /// If provided, skips the ExerciseVideoService lookup and plays this
  /// URL directly. Used by the inline "fullscreen" button so we don't
  /// re-search YouTube for a URL we already have.
  final String? initialUrl;
  /// Optional starting position — the inline player passes its current
  /// position so fullscreen resumes where the user was watching instead
  /// of restarting from 0.
  final Duration? startAt;

  const ExerciseTutorialPage({
    super.key,
    required this.exerciseName,
    this.initialUrl,
    this.startAt,
  });

  @override
  ConsumerState<ExerciseTutorialPage> createState() =>
      _ExerciseTutorialPageState();
}

class _ExerciseTutorialPageState
    extends ConsumerState<ExerciseTutorialPage> {
  VideoPlayerController? _ctrl;
  bool _resolving = true;
  bool _errored = false;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // If the caller pre-resolved the URL (e.g. the inline player passing
    // its already-fetched stream URL), skip the search and use it.
    final url = widget.initialUrl ??
        await ref
            .read(exerciseVideoServiceProvider)
            .resolveStreamUrl(widget.exerciseName);
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _resolving = false;
        _errored = true;
      });
      return;
    }
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      // Resume from where the inline player left off, when passed.
      // Clamp so we don't seek past the video duration on shorter clips.
      final resumeAt = widget.startAt;
      if (resumeAt != null &&
          resumeAt > Duration.zero &&
          resumeAt < ctrl.value.duration) {
        await ctrl.seekTo(resumeAt);
      }
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _errored = true;
      });
    }
  }

  Future<void> _openExternalSearch() async {
    final query = Uri.encodeQueryComponent(
        '${widget.exerciseName} proper form technique tutorial');
    final url =
        Uri.parse('https://www.youtube.com/results?search_query=$query');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = _ctrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video / loading / error ─────────────────────────────
            if (_resolving)
              _LoadingState(exerciseName: widget.exerciseName)
            else if (_errored)
              _ErrorState(
                exerciseName: widget.exerciseName,
                onFallback: _openExternalSearch,
                onRetry: () {
                  setState(() {
                    _resolving = true;
                    _errored = false;
                  });
                  _load();
                },
              )
            else if (c != null)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),

            // ── Top gradient + back + title ─────────────────────────
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 6,
                        bottom: 14,
                        left: 6,
                        right: 14,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xB3000000),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              widget.exerciseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // ── Bottom controls (only when playing) ─────────
                    if (c != null && !_resolving && !_errored)
                      _BottomControls(
                        controller: c,
                        onTogglePlay: _togglePlay,
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

// ─────────────────────── Loading state ───────────────────────

class _LoadingState extends StatelessWidget {
  final String exerciseName;
  const _LoadingState({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                  strokeWidth: 2.6, color: AppColors.accent),
            ),
            const SizedBox(height: 18),
            Text(
              loc.findingBestDemo,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              exerciseName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Error state ───────────────────────

class _ErrorState extends StatelessWidget {
  final String exerciseName;
  final VoidCallback onFallback;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.exerciseName,
    required this.onFallback,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 40, color: Colors.white54),
            const SizedBox(height: 14),
            Text(
              loc.couldntLoadDemo,
              textAlign: TextAlign.center,
              style: AppText.sectionTitle
                  .copyWith(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              loc.checkConnectionOrYT,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillButton(
                  label: loc.retry,
                  onTap: onRetry,
                  filled: false,
                ),
                const SizedBox(width: 10),
                _PillButton(
                  label: AppLocalizations.of(context)!.openOnYoutube,
                  onTap: onFallback,
                  filled: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: filled ? AppColors.accent : Colors.white54,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? AppColors.onAccent : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Bottom controls ───────────────────────

class _BottomControls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onTogglePlay;

  const _BottomControls({
    required this.controller,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00000000),
            Color(0xCC000000),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: AppColors.accent,
              bufferedColor: Colors.white.withValues(alpha: 0.35),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: onTogglePlay,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 26,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, VideoPlayerValue value, _) => Text(
                  '${_fmt(value.position)} / ${_fmt(value.duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
