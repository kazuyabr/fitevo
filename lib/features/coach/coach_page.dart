import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../data/models/daily_log.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/profile.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/nutrition_repo.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/user_context_builder.dart';
import '../../services/coach/coach_history_service.dart';
import '../../services/progress/streak_calc.dart';
import '../../services/workout/pr_tracker.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/skeleton.dart';
import 'package:intl/intl.dart';

class CoachPage extends ConsumerStatefulWidget {
  const CoachPage({super.key});

  @override
  ConsumerState<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends ConsumerState<CoachPage> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<CoachMessage> _messages = [];
  bool _sending = false;
  bool _reviewing = false;
  String? _weeklyReview;

  // Persistent session — assigned fresh on first send when null. The
  // history sheet can also load an existing session into _messages and
  // set this so further turns append to the same row.
  CoachSession? _currentSession;

  @override
  void initState() {
    super.initState();
    // Resume today's chat across app restarts so the user doesn't lose
    // context every time they reopen the app. Rolls over fresh on a
    // new calendar day — yesterday's thread stays browsable via the
    // history sheet.
    _resumeTodaysSession();
  }

  Future<void> _resumeTodaysSession() async {
    final sessions = await CoachHistoryService.list();
    if (!mounted || sessions.isEmpty) return;
    final now = DateTime.now();
    final newest = sessions.first; // already date-desc
    final sameDay = newest.startedAt.year == now.year &&
        newest.startedAt.month == now.month &&
        newest.startedAt.day == now.day;
    if (!sameDay || newest.messages.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _currentSession = newest;
      _messages
        ..clear()
        ..addAll(newest.messages);
    });
    // Snap to the bottom after the next layout so resumed history
    // shows the most recent turn instead of the top.
    _scrollToBottom();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    _scroll.dispose();
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

  Future<void> _send(
    Profile profile,
    DailyTotals totals,
    int streak,
    int prCount,
    int sessionsWeek, {
    List<FoodEntry> recentFoods = const [],
    List<DailyLog> recentLogs = const [],
    List<WorkoutSession> recentSessions = const [],
    DailyLog? todayLog,
    String weightTrendLines = '',
  }) async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(CoachMessage(
          fromUser: true, text: text, timestamp: DateTime.now()));
      _ctl.clear();
      _sending = true;
    });
    _scrollToBottom();
    try {
      final trend = ref.read(weightTrendProvider);
      final builder = UserContextBuilder(
        profile: profile,
        totals: totals,
        todayLog: todayLog,
        recentFoods: recentFoods,
        recentLogs: recentLogs,
        recentSessions: recentSessions,
        weightTrend: trend,
        streak: streak,
        prCount: prCount,
        sessionsThisWeek: sessionsWeek,
      );
      final reply = await ref.read(aiServiceProvider).coachChat(
            userContext: builder.buildFullContext(),
            history: List.of(_messages..removeLast()),
            latestUserMessage: text,
          );
      if (!mounted) return;
      setState(() {
        _messages.add(CoachMessage(
            fromUser: true, text: text, timestamp: DateTime.now()));
        _messages.add(CoachMessage(
            fromUser: false, text: reply, timestamp: DateTime.now()));
      });
      _scrollToBottom();
      await _persistCurrentSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(CoachMessage(
            fromUser: true, text: text, timestamp: DateTime.now()));
      });
      _toast(e is AiNotConfiguredException
          ? AppLocalizations.of(context)!.aiServiceNotConfigured
          : e is AiException
              ? e.message
              : AppLocalizations.of(context)!.coachRequestFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Save the current session to SharedPreferences after each turn so
  /// the user can come back tomorrow and pick up where they left off
  /// from the history sheet. Auto-creates the session on first persist.
  Future<void> _persistCurrentSession() async {
    if (_messages.isEmpty) return;
    _currentSession ??= CoachSession.fresh();
    final updated = _currentSession!.copyWith(messages: List.of(_messages));
    _currentSession = updated;
    await CoachHistoryService.upsert(updated);
  }

  void _newSession() {
    setState(() {
      _messages.clear();
      _currentSession = null;
    });
  }

  void _loadSession(CoachSession s) {
    setState(() {
      _messages
        ..clear()
        ..addAll(s.messages);
      _currentSession = s;
    });
    _scrollToBottom();
  }

  Future<void> _openHistory() async {
    final sessions = await CoachHistoryService.list();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _HistorySheet(
        sessions: sessions,
        currentId: _currentSession?.id,
        onSelect: (s) {
          Navigator.of(ctx).pop();
          _loadSession(s);
        },
        onDelete: (s) async {
          await CoachHistoryService.delete(s.id);
          if (_currentSession?.id == s.id) _newSession();
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) _openHistory();
        },
        onNew: () {
          Navigator.of(ctx).pop();
          _newSession();
        },
      ),
    );
  }

  static const _cacheKey = 'coachPage.weeklyReviewText.v2';
  static const _cacheTsKey = 'coachPage.weeklyReviewAt.v2';

  Future<bool> _serveFromCacheIfFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_cacheTsKey);
    final cached = prefs.getString(_cacheKey);
    if (ts == null || cached == null || cached.isEmpty) return false;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age.inHours >= 24) return false;
    if (!mounted) return false;
    setState(() => _weeklyReview = cached);
    return true;
  }

  Future<void> _runWeeklyReview(
    Profile profile,
    List<FoodEntry> foods,
    List<WorkoutSession> sessions, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && await _serveFromCacheIfFresh()) return;
    setState(() => _reviewing = true);
    try {
      final prs = PrTracker.personalRecords(sessions);
      final trend = ref.read(weightTrendProvider);
      final builder = UserContextBuilder(
        profile: profile,
        totals: NutritionRepo.sumEntries(const []),
        todayLog: null,
        recentFoods: foods,
        recentLogs: (ref.read(allDailyLogsProvider).value ??
                const <DailyLog>[])
            .toList(),
        recentSessions: sessions,
        weightTrend: trend,
        streak: 0,
        prCount: prs.length,
        sessionsThisWeek: 0,
      );
      final summary = builder.buildWeeklySummary();
      final review = await ref
          .read(aiServiceProvider)
          .weeklyReview(contextSummary: summary);
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, review);
      await prefs.setInt(
          _cacheTsKey, DateTime.now().millisecondsSinceEpoch);
      if (!mounted) return;
      setState(() => _weeklyReview = review);
    } catch (e) {
      if (!mounted) return;
      _toast(e is AiException ? e.message : AppLocalizations.of(context)!.weeklyReviewFailed);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileStreamProvider);
    final totals = ref.watch(todayTotalsProvider);
    final foods = ref.watch(allFoodEntriesProvider).value ?? const [];
    final sessions =
        ref.watch(allSessionsProvider).value ?? const <WorkoutSession>[];
    final streak = StreakCalc.currentStreak(
      foodEntries: foods,
      sessions: sessions,
      today: DateTime.now(),
    );
    final prCount = PrTracker.personalRecords(sessions).length;
    final weekSessions = sessions
        .where((s) => s.startedAt.isAfter(
            DateTime.now().subtract(const Duration(days: 7))))
        .length;

    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.coach, style: AppText.sectionTitle),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            tooltip: loc.newChat,
            onPressed: _messages.isEmpty ? null : _newSession,
            icon: Icon(Icons.edit_note_rounded,
                color: _messages.isEmpty
                    ? AppColors.textTertiary
                    : AppColors.textPrimary),
          ),
          IconButton(
            tooltip: loc.chatHistory,
            onPressed: _openHistory,
            icon: Icon(Icons.history_rounded,
                color: AppColors.textPrimary),
          ),
        ],
      ),
      // Skeleton mirroring the chat: review card, then alternating
      // coach/user bubbles, with the input bar at the bottom.
      body: profileAsync.when(
        loading: () => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(
                    height: 120,
                    borderRadius: BorderRadius.all(Radius.circular(22))),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(
                      width: 250, height: 64,
                      borderRadius:
                          BorderRadius.all(Radius.circular(18))),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: SkeletonBox(
                      width: 180, height: 44,
                      borderRadius:
                          BorderRadius.all(Radius.circular(18))),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(
                      width: 270, height: 84,
                      borderRadius:
                          BorderRadius.all(Radius.circular(18))),
                ),
                const Spacer(),
                const SkeletonBox(
                    height: 54,
                    borderRadius: BorderRadius.all(Radius.circular(27))),
              ],
            ),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      _WeeklyReviewCard(
                        review: _weeklyReview,
                        busy: _reviewing,
                        onRun: () =>
                            _runWeeklyReview(profile, foods, sessions,
                                forceRefresh: _weeklyReview != null),
                      ),
                      const SizedBox(height: 20),
                      if (_messages.isEmpty) _Suggestions(onTap: (s) {
                        _ctl.text = s;
                        _focus.requestFocus();
                      }),
                      for (final m in _messages) ...[
                        const SizedBox(height: 10),
                        _Bubble(message: m),
                      ],
                      if (_sending) ...[
                        const SizedBox(height: 10),
                        _TypingIndicator(),
                      ],
                    ],
                  ),
                ),
                _Composer(
                  controller: _ctl,
                  focusNode: _focus,
                  busy: _sending,
                  onSend: () {
                    // Pull recent foods/logs/sessions so the AI sees a
                    // per-day breakdown and can answer "what about
                    // yesterday?" without hallucinating.
                    final now = DateTime.now();
                    final weekAgo = DateTime(now.year, now.month, now.day)
                        .subtract(const Duration(days: 6));
                    final recentFoods = foods
                        .where((f) => !f.timestamp.isBefore(weekAgo))
                        .toList();
                    final recentSessions = sessions
                        .where((s) => !s.startedAt.isBefore(weekAgo))
                        .toList();
                    final recentLogs = (ref
                                .read(allDailyLogsProvider)
                                .value ??
                            const <DailyLog>[])
                        .where((l) {
                      final parsed = DateTime.tryParse(l.dateKey);
                      return parsed != null && !parsed.isBefore(weekAgo);
                    }).toList();
                    // Today's log specifically so the lead "calorie
                    // target" line shows the activity-adjusted number.
                    final todayLog = ref.read(todayLogProvider).value;
                    // Weight trend so the AI can call out goal-vs-trend
                    // misalignment with actual numbers.
                    final trendLines =
                        ref.read(weightTrendProvider).toContextLines();
                    _send(
                      profile,
                      totals,
                      streak,
                      prCount,
                      weekSessions,
                      recentFoods: recentFoods,
                      recentLogs: recentLogs,
                      recentSessions: recentSessions,
                      todayLog: todayLog,
                      weightTrendLines: trendLines,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeeklyReviewCard extends StatelessWidget {
  final String? review;
  final bool busy;
  final VoidCallback onRun;
  const _WeeklyReviewCard({
    required this.review,
    required this.busy,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.aiCoach, style: AppText.label),
            ],
          ),
          const SizedBox(height: 10),
          if (review == null && !busy)
            Text(
            AppLocalizations.of(context)!.weeklyReviewEmpty,
            style: AppText.body.copyWith(fontSize: 13),
            )
          else if (busy)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.coachThinking, style: AppText.body),
              ],
            )
          else
            Text(review!,
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: busy ? null : onRun,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    review == null
                        ? Icons.auto_awesome_rounded
                        : Icons.refresh_rounded,
                    size: 13,
                    color: AppColors.onAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    review == null ? AppLocalizations.of(context)!.getStarted : AppLocalizations.of(context)!.retry,
                    style: TextStyle(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final void Function(String) onTap;
  const _Suggestions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final items = [
      AppLocalizations.of(context)!.suggestion1,
      AppLocalizations.of(context)!.suggestion2,
      AppLocalizations.of(context)!.suggestion3,
      AppLocalizations.of(context)!.suggestion4,
      AppLocalizations.of(context)!.suggestion5,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.noMessagesYet, style: AppText.sectionTitle.copyWith(fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context)!.startConversation,
          style: AppText.body.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 16),
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onTap(s),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s,
                          style: AppText.body.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                    ),
                    Icon(Icons.north_east_rounded,
                        size: 14, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final CoachMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Row(
      mainAxisAlignment:
          fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!fromUser) ...[
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.accent),
          ),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: fromUser ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromUser ? 16 : 4),
                bottomRight: Radius.circular(fromUser ? 4 : 16),
              ),
              border: fromUser
                  ? null
                  : Border.all(color: AppColors.stroke),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: fromUser ? AppColors.onAccent : AppColors.textPrimary,
                fontSize: 14,
                height: 1.35,
                fontWeight:
                    fromUser ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.auto_awesome_rounded,
              size: 14, color: AppColors.accent),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.coachThinking,
                  style: AppText.body.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    widget.focusNode.unfocus();
    final available = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'notListening' || s == 'done') && mounted && _listening) {
          setState(() => _listening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _listening = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            content: Text(AppLocalizations.of(context)!.speechError(e.errorMsg),
                style:
                    AppText.body.copyWith(color: AppColors.textPrimary)),
          ));
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          content: Text(AppLocalizations.of(context)!.micPermissionNeededForVoiceInput,
              style: AppText.body.copyWith(color: AppColors.textPrimary)),
        ));
      return;
    }
    if (mounted) setState(() => _listening = true);
    _speech.listen(
      onResult: (r) {
        if (mounted) widget.controller.text = r.recognizedWords;
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _listening
                        ? AppColors.accent
                        : AppColors.stroke,
                    width: _listening ? 1.5 : 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !widget.busy,
                      textInputAction: TextInputAction.newline,
                      cursorColor: AppColors.accent,
                      onSubmitted: (_) => widget.onSend(),
                      style: AppText.body.copyWith(
                          color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        hintText: _listening
                            ? AppLocalizations.of(context)!.loading
                            : AppLocalizations.of(context)!.askCoach,
                        hintStyle: AppText.body.copyWith(
                            color: AppColors.textTertiary, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.busy ? null : _toggleMic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _listening
                            ? AppColors.accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _listening
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                        size: 20,
                        color: _listening
                            ? AppColors.accent
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.busy ? null : widget.onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.busy
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_upward_rounded,
                  color: AppColors.onAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HISTORY SHEET
// ============================================================================

class _HistorySheet extends StatelessWidget {
  final List<CoachSession> sessions;
  final String? currentId;
  final void Function(CoachSession) onSelect;
  final void Function(CoachSession) onDelete;
  final VoidCallback onNew;
  const _HistorySheet({
    required this.sessions,
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
    required this.onNew,
  });

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dDay).inDays;
    if (diff == 0) return 'Today · ${DateFormat('h:mm a').format(d)}';
    if (diff == 1) return 'Yesterday · ${DateFormat('h:mm a').format(d)}';
    if (diff < 7) return DateFormat('EEEE · h:mm a').format(d);
    return DateFormat('MMM d, y · h:mm a').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.coachTab,
                      style: AppText.sectionTitle.copyWith(fontSize: 17)),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onNew,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.accent
                                .withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(AppLocalizations.of(context)!.startTracking,
                              style: AppText.body.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.noMessagesYet + '. ' + AppLocalizations.of(context)!.startConversation,
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(
                          color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final active = s.id == currentId;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(s),
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.accent.withValues(alpha: 0.08)
                                : AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active
                                  ? AppColors.accent
                                      .withValues(alpha: 0.4)
                                  : AppColors.stroke,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.previewText.isEmpty
                                          ? '(no messages)'
                                          : s.previewText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body.copyWith(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_dateLabel(s.startedAt)} · ${s.messages.length} msgs',
                                      style: AppText.meta
                                          .copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => onDelete(s),
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppColors.textTertiary),
                                tooltip: loc.deleteChat,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
