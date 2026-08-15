// 2×2 grid of AiQuadrant panels with synchronized scrolling.
// ignore_for_file: always_use_package_imports
//
// All four panels share a [SyncScrollController] so that scrolling any one
// panel causes all others to move to the same fractional position in time.
import 'package:flutter/material.dart';

import '../../core/conversation/message.dart';
import '../../core/conversation/participant.dart';
import '../../core/mood/mood_score.dart';
import '../../core/tools/image/image_watcher.dart';
import '../../core/trust/trust_manager.dart';
import '../avatars/avatar_widget.dart';
import '../widgets/network_indicator/rate_limit_flash.dart';
import 'ai_quadrant.dart'; // also provides AiQuadrant

// ---------------------------------------------------------------------------
// QuadrantData — per-quadrant state bundle
// ---------------------------------------------------------------------------

/// All runtime state needed to render one [AiQuadrant].
class QuadrantData {
  final Participant participant;

  /// Only this participant's own messages + user messages.
  final List<Message> messages;
  final AvatarState avatarState;
  final bool isThinking;
  final Stream<String> tokenStream;

  /// Optional image event stream for the quadrant.
  final Stream<ImageDroppedEvent>? imageEventStream;

  /// Estimated token count for this character.
  final int tokenCount;

  /// Context window size in tokens.
  final int maxTokens;

  /// Optional swap callback — passed through to [AiQuadrant.onSwap].
  final void Function(Participant)? onSwap;

  // ── Trust / network ──────────────────────────────────────────────────────

  /// [TrustManager] so the quadrant's network toggle can call back.
  final TrustManager? trustManager;

  /// Initial trust score for this character.
  final TrustScore? initialTrustScore;

  /// Live stream of [TrustScore] updates for this character.
  final Stream<TrustScore>? trustScoreStream;

  /// Controller for triggering the rate-limit flash indicator.
  final RateLimitFlashController? rateLimitFlashController;

  // ── Mood ─────────────────────────────────────────────────────────────────

  /// Initial mood score for this character.
  final MoodScore? initialMoodScore;

  /// Live stream of [MoodScore] updates for this character.
  final Stream<MoodScore>? moodScoreStream;

  const QuadrantData({
    required this.participant,
    required this.messages,
    required this.avatarState,
    required this.isThinking,
    required this.tokenStream,
    this.imageEventStream,
    this.tokenCount = 0,
    this.maxTokens = 8192,
    this.onSwap,
    this.trustManager,
    this.initialTrustScore,
    this.trustScoreStream,
    this.rateLimitFlashController,
    this.initialMoodScore,
    this.moodScoreStream,
  });
}

// ---------------------------------------------------------------------------
// SyncScrollController
// ---------------------------------------------------------------------------

/// Keeps multiple [ScrollController]s in sync by fractional position.
///
/// When any registered controller scrolls, all others are moved to the same
/// fraction (scrollOffset / maxScrollExtent) of their own scroll range.
/// This gives a "same point in time" feel even when panels have different
/// total heights.
class SyncScrollController {
  final List<ScrollController> _controllers = [];
  bool _isSyncing = false;

  /// Register a [ScrollController] to be kept in sync.
  void register(ScrollController ctrl) {
    _controllers.add(ctrl);
    ctrl.addListener(() => _onScroll(ctrl));
  }

  /// Remove a controller (call from dispose).
  void unregister(ScrollController ctrl) {
    _controllers.remove(ctrl);
  }

  void _onScroll(ScrollController source) {
    if (_isSyncing) return;
    if (!source.hasClients) return;
    final pos = source.position;
    if (pos.maxScrollExtent == 0) return;
    final fraction = pos.pixels / pos.maxScrollExtent;

    _isSyncing = true;
    for (final ctrl in _controllers) {
      if (ctrl == source) continue;
      if (!ctrl.hasClients) continue;
      final max = ctrl.position.maxScrollExtent;
      if (max == 0) continue;
      final target = (fraction * max).clamp(0.0, max);
      if ((ctrl.position.pixels - target).abs() > 1.0) {
        ctrl.jumpTo(target);
      }
    }
    _isSyncing = false;
  }

  /// Scroll all controllers to the bottom.
  void scrollAllToBottom() {
    for (final ctrl in _controllers) {
      if (!ctrl.hasClients) continue;
      final max = ctrl.position.maxScrollExtent;
      if (max > 0) ctrl.jumpTo(max);
    }
  }

  /// Scroll all controllers to the very top.
  void scrollAllToTop() {
    for (final ctrl in _controllers) {
      if (!ctrl.hasClients) continue;
      ctrl.jumpTo(0);
    }
  }

  void dispose() {
    _controllers.clear();
  }
}

// ---------------------------------------------------------------------------
// QuadrantGrid
// ---------------------------------------------------------------------------

/// Renders four [AiQuadrant] widgets in a 2×2 layout with synchronized scroll.
///
/// [quadrants] must have exactly 4 elements, in the order:
/// top-left, top-right, bottom-left, bottom-right.
class QuadrantGrid extends StatefulWidget {
  /// Exactly 4 data bundles — one per quadrant.
  final List<QuadrantData> quadrants;

  /// Optional callback invoked when the "Warp to Head" action is triggered
  /// externally — wires in the [SyncScrollController.scrollAllToTop] call.
  /// Pass a [_QuadrantGridState] key reference instead; see [warpToHead].
  // (We expose this via a GlobalKey rather than a prop — see warpToHead below.)

  const QuadrantGrid({
    required this.quadrants,
    super.key,
  }) : assert(quadrants.length == 4,
            'QuadrantGrid requires exactly 4 QuadrantData entries');

  /// Scroll all panels to the top.  Call via `GlobalKey<QuadrantGridState>`.
  static void warpToHead(GlobalKey<QuadrantGridState> key) {
    key.currentState?._sync.scrollAllToTop();
  }

  @override
  State<QuadrantGrid> createState() => QuadrantGridState();
}

// ignore: library_private_types_in_public_api — intentionally public for GlobalKey access
class QuadrantGridState extends State<QuadrantGrid> {
  late final SyncScrollController _sync;
  final List<ScrollController> _scrollControllers = [];

  @override
  void initState() {
    super.initState();
    _sync = SyncScrollController();
    for (int i = 0; i < 4; i++) {
      final ctrl = ScrollController();
      _scrollControllers.add(ctrl);
      _sync.register(ctrl);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _scrollControllers) {
      _sync.unregister(ctrl);
      ctrl.dispose();
    }
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top row
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildQuadrant(0)),
              const SizedBox(width: 4),
              Expanded(child: _buildQuadrant(1)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Bottom row
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildQuadrant(2)),
              const SizedBox(width: 4),
              Expanded(child: _buildQuadrant(3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrant(int index) {
    final d = widget.quadrants[index];
    return AiQuadrant(
      key: ValueKey(d.participant.name),
      participant: d.participant,
      messages: d.messages,
      avatarState: d.avatarState,
      isThinking: d.isThinking,
      tokenStream: d.tokenStream,
      scrollController: _scrollControllers[index],
      imageEventStream: d.imageEventStream,
      tokenCount: d.tokenCount,
      maxTokens: d.maxTokens,
      onSwap: d.onSwap,
      trustManager: d.trustManager,
      initialTrustScore: d.initialTrustScore,
      trustScoreStream: d.trustScoreStream,
      rateLimitFlashController: d.rateLimitFlashController,
      initialMoodScore: d.initialMoodScore,
      moodScoreStream: d.moodScoreStream,
    );
  }
}
