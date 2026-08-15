// Single AI character panel for the deepThink quadrant grid.
//
// Each panel shows:
//   • This AI's own responses (streamed live, then committed)
//   • User messages interleaved in chronological order
//   • Subtle round-banding so you can see which responses belong together
//
// The ScrollController is supplied externally so the QuadrantGrid can
// synchronise scrolling across all four panels.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/conversation/message.dart';
import '../../core/conversation/whisper_message.dart';
import '../../core/conversation/participant.dart';
import '../../core/mood/mood_score.dart';
import '../../core/tools/image/image_watcher.dart';
import '../../core/trust/trust_manager.dart';
import '../../core/trust/trust_score.dart';
import '../avatars/avatar_registry.dart';
import '../avatars/avatar_widget.dart';
import '../avatars/energy_orb/orb_config.dart';
import '../widgets/app_theme.dart';
import '../widgets/character_picker_dialog.dart';
import '../widgets/mood_indicator/mood_indicator.dart';
import '../widgets/network_indicator/network_toggle.dart';
import '../widgets/network_indicator/rate_limit_flash.dart';
import '../widgets/network_indicator/search_activity_entry.dart';
import '../widgets/token_counter/token_counter_widget.dart';
import '../widgets/trust_badge/trust_badge.dart';
import '../widgets/trust_badge/trust_sparkline_widget.dart';

// ---------------------------------------------------------------------------
// Round palette — subtle background tints cycling per conversation round.
// A "round" is the set of responses triggered by the same user/kickoff message.
// ---------------------------------------------------------------------------

/// Six very dark background tints that cycle per round index.
const List<Color> _kRoundColors = [
  Color(0xFF0D1220), // indigo tint
  Color(0xFF130D20), // violet tint
  Color(0xFF0D1A13), // teal tint
  Color(0xFF1A130D), // amber tint
  Color(0xFF1A0D0D), // rose tint
  Color(0xFF0D1A1A), // cyan tint
];

Color _roundColor(int roundIndex) =>
    _kRoundColors[roundIndex % _kRoundColors.length];

// ---------------------------------------------------------------------------
// AiQuadrant
// ---------------------------------------------------------------------------

/// A self-contained panel for one AI participant.
///
/// - Header  : avatar + character name + model badge
/// - Body    : scrollable message history (own + user only) + live streaming
/// - Footer  : animated "thinking…" dots while [isThinking]
///
/// [scrollController] is owned by [QuadrantGrid] so all panels stay in sync.
class AiQuadrant extends StatefulWidget {
  /// The AI participant this quadrant represents.
  final Participant participant;

  /// Only messages from this participant and the user (no other AIs).
  final List<Message> messages;

  /// Current avatar animation state.
  final AvatarState avatarState;

  /// Whether this participant is currently generating a response.
  final bool isThinking;

  /// Stream of raw token strings for the live-streaming text area.
  final Stream<String> tokenStream;

  /// External scroll controller — supplied by [QuadrantGrid] for sync.
  final ScrollController scrollController;

  /// [TrustManager] for network toggle callbacks.
  final TrustManager? trustManager;

  /// Initial trust score — used to prime the trust badge.
  final TrustScore? initialTrustScore;

  /// Stream of [TrustScore] updates for this character — feeds the badge.
  final Stream<TrustScore>? trustScoreStream;

  /// Controller for triggering the rate-limit flash indicator.
  final RateLimitFlashController? rateLimitFlashController;

  /// Initial mood score for the mood indicator.
  final MoodScore? initialMoodScore;

  /// Stream of mood score updates for this character.
  final Stream<MoodScore>? moodScoreStream;

  /// Stream of image drop events to show inline in the quadrant.
  final Stream<ImageDroppedEvent>? imageEventStream;

  /// Token counter fields.
  final int tokenCount;
  final int maxTokens;

  /// Optional callback when user requests a character swap for this slot.
  final void Function(Participant)? onSwap;

  const AiQuadrant({
    required this.participant,
    required this.messages,
    required this.avatarState,
    required this.isThinking,
    required this.tokenStream,
    required this.scrollController,
    this.trustManager,
    this.initialTrustScore,
    this.trustScoreStream,
    this.rateLimitFlashController,
    this.initialMoodScore,
    this.moodScoreStream,
    this.imageEventStream,
    this.tokenCount = 0,
    this.maxTokens = 8192,
    this.onSwap,
    super.key,
  });

  @override
  State<AiQuadrant> createState() => _AiQuadrantState();
}

class _AiQuadrantState extends State<AiQuadrant> {
  /// Tokens that have streamed in during the current generation turn.
  final StringBuffer _liveBuffer = StringBuffer();
  String _liveText = '';

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<ImageDroppedEvent>? _imageSub;

  // Recent image event notices shown inline.
  final List<String> _imageNotices = [];

  // Thinking-dots animation
  int _dotCount = 0;
  Timer? _dotsTimer;

  // ---------------------------------------------------------------------------
  // Auto-scroll lock
  // ---------------------------------------------------------------------------

  /// Whether the user has scrolled away from the bottom.
  /// When true, auto-scroll is suspended so they can read without interruption.
  bool _userScrolledUp = false;

  /// Small threshold — if within this many pixels of the bottom, treat as
  /// "at bottom" and re-enable auto-scroll automatically.
  static const double _atBottomThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _subscribeToTokens();
    _subscribeToImageEvents();
    _updateDotsTimer();
    // Start listening for manual scroll gestures.
    widget.scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(AiQuadrant old) {
    super.didUpdateWidget(old);
    if (old.scrollController != widget.scrollController) {
      old.scrollController.removeListener(_onScrollChanged);
      widget.scrollController.addListener(_onScrollChanged);
    }
    if (old.tokenStream != widget.tokenStream) {
      _tokenSub?.cancel();
      _subscribeToTokens();
    }
    if (old.isThinking != widget.isThinking) {
      _updateDotsTimer();
    }
    // When a new completed message arrives (for this participant), clear the
    // live buffer — the completed text is now in widget.messages.
    if (old.messages.length != widget.messages.length) {
      final latest = widget.messages.isNotEmpty ? widget.messages.last : null;
      if (latest != null && !latest.isUser) {
        setState(() {
          _liveBuffer.clear();
          _liveText = '';
        });
      }
      _maybeScrollToBottom();
    }
  }

  void _subscribeToImageEvents() {
    _imageSub?.cancel();
    if (widget.imageEventStream == null) return;
    _imageSub = widget.imageEventStream!.listen((event) {
      if (mounted) {
        setState(() {
          _imageNotices.add('🖼️ image analysed: ${event.fileName}');
        });
      }
    });
  }

  void _subscribeToTokens() {
    _tokenSub = widget.tokenStream.listen((token) {
      _liveBuffer.write(token);
      setState(() => _liveText = _liveBuffer.toString());
      _maybeScrollToBottom();
    });
  }

  void _updateDotsTimer() {
    _dotsTimer?.cancel();
    if (widget.isThinking) {
      _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
      });
    } else {
      _dotCount = 0;
    }
  }

  /// Called whenever the scroll position changes.
  /// Only cares about the at-bottom → re-enable auto-scroll transition.
  void _onScrollChanged() {
    final ctrl = widget.scrollController;
    if (!ctrl.hasClients) return;
    final pos = ctrl.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    final atBottom = distanceFromBottom <= _atBottomThreshold;

    // If the user has scrolled back to the bottom, re-enable auto-scroll.
    if (atBottom && _userScrolledUp) {
      if (mounted) setState(() => _userScrolledUp = false);
    }
  }

  /// Called by the [NotificationListener] on the ListView when a user drag
  /// or fling starts.  This is the correct way to distinguish user gestures
  /// from programmatic scrolls.
  bool _onScrollNotification(ScrollNotification n) {
    if (n is UserScrollNotification) {
      final ctrl = widget.scrollController;
      if (!ctrl.hasClients) return false;
      final distanceFromBottom =
          ctrl.position.maxScrollExtent - ctrl.position.pixels;
      if (distanceFromBottom > _atBottomThreshold && !_userScrolledUp) {
        if (mounted) setState(() => _userScrolledUp = true);
      }
    }
    return false; // don't absorb the notification
  }

  /// Scrolls to the bottom only when the user has not manually scrolled away.
  void _maybeScrollToBottom() {
    if (_userScrolledUp) return;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = widget.scrollController;
      if (ctrl.hasClients) {
        ctrl.animateTo(
          ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Force-scrolls to the bottom and re-enables auto-scroll.
  void _jumpToLatest() {
    setState(() => _userScrolledUp = false);
    _scrollToBottom();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollChanged);
    _tokenSub?.cancel();
    _imageSub?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Color _characterColor() => OrbConfig.forCharacter(widget.participant.name).primaryColor;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final charColor = _characterColor();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: charColor.withValues(alpha: 0.45), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            participant: widget.participant,
            avatarState: widget.avatarState,
            charColor: charColor,
            trustManager: widget.trustManager,
            initialTrustScore: widget.initialTrustScore,
            trustScoreStream: widget.trustScoreStream,
            rateLimitFlashController: widget.rateLimitFlashController,
            initialMoodScore: widget.initialMoodScore,
            moodScoreStream: widget.moodScoreStream,
            tokenCount: widget.tokenCount,
            maxTokens: widget.maxTokens,
            onSwap: widget.onSwap,
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: _MessageArea(
                    messages: widget.messages,
                    liveText: _liveText,
                    ownerName: widget.participant.name,
                    scroll: widget.scrollController,
                    charColor: charColor,
                    imageNotices: _imageNotices,
                  ),
                ),
                // "Jump to Latest" pill — only shown when auto-scroll is locked.
                if (_userScrolledUp)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _JumpToLatestButton(onTap: _jumpToLatest),
                  ),
              ],
            ),
          ),
          if (widget.isThinking)
            _ThinkingIndicator(
              dotCount: _dotCount,
              charColor: charColor,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final Participant participant;
  final AvatarState avatarState;
  final Color charColor;
  final TrustManager? trustManager;
  final TrustScore? initialTrustScore;
  final Stream<TrustScore>? trustScoreStream;
  final RateLimitFlashController? rateLimitFlashController;
  final MoodScore? initialMoodScore;
  final Stream<MoodScore>? moodScoreStream;
  final int tokenCount;
  final int maxTokens;
  final void Function(Participant)? onSwap;

  const _Header({
    required this.participant,
    required this.avatarState,
    required this.charColor,
    this.trustManager,
    this.initialTrustScore,
    this.trustScoreStream,
    this.rateLimitFlashController,
    this.initialMoodScore,
    this.moodScoreStream,
    this.tokenCount = 0,
    this.maxTokens = 8192,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          AvatarRegistry.build(
            'energyOrb',
            state: avatarState,
            characterName: participant.name,
            size: 52,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Text(
                      participant.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: charColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (initialTrustScore != null &&
                        trustScoreStream != null) ...[
                      const SizedBox(width: 6),
                      TrustBadge(
                        scoreStream: trustScoreStream!,
                        initialScore: initialTrustScore!,
                      ),
                      if (trustManager != null) ...[
                        const SizedBox(width: 4),
                        TrustSparklineWidget(
                          trustManager: trustManager!,
                          characterName: participant.name,
                        ),
                      ],
                    ],
                    if (rateLimitFlashController != null) ...[
                      const SizedBox(width: 4),
                      RateLimitFlash(
                          controller: rateLimitFlashController!),
                    ],
                    // Mood indicator — only shown when mood stream is provided.
                    if (initialMoodScore != null &&
                        moodScoreStream != null) ...[
                      const SizedBox(width: 6),
                      MoodIndicator(
                        initialScore: initialMoodScore!,
                        scoreStream: moodScoreStream!,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _ModelBadge(modelId: participant.assignedModelId),
                    const SizedBox(width: 6),
                    TokenCounterWidget(
                      tokenCount: tokenCount,
                      maxTokens: maxTokens,
                    ),
                    const SizedBox(width: 6),
                    if (trustManager != null)
                      NetworkToggle(
                        characterName: participant.name,
                        initialEnabled:
                            initialTrustScore?.networkEnabled ?? true,
                        trustManager: trustManager!,
                      )
                    else
                      Text(
                        participant.personality,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Swap button — shown when onSwap is provided
          if (onSwap != null)
            Tooltip(
              message: 'Swap character',
              child: InkWell(
                onTap: () => showCharacterPickerDialog(
                  context: context,
                  currentCharacter: participant.name,
                  onSelected: onSwap!,
                ),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 4),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: charColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ModelBadge
// ---------------------------------------------------------------------------

class _ModelBadge extends StatelessWidget {
  final String modelId;
  const _ModelBadge({required this.modelId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        modelId,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MessageArea
// ---------------------------------------------------------------------------

/// Scrollable list of message rows with round-based color banding.
///
/// Each "round" — contiguous block of messages sharing the same [roundIndex]
/// — gets a faint background tint so it's visually clear which responses
/// belong together across all four panels.
class _MessageArea extends StatelessWidget {
  final List<Message> messages;
  final String liveText;
  final String ownerName;
  final ScrollController scroll;
  final Color charColor;
  final List<String> imageNotices;

  const _MessageArea({
    required this.messages,
    required this.liveText,
    required this.ownerName,
    required this.scroll,
    required this.charColor,
    this.imageNotices = const [],
  });

  @override
  Widget build(BuildContext context) {
    final noticeCount = imageNotices.length;
    final itemCount = messages.length + (liveText.isNotEmpty ? 1 : 0) + noticeCount;

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Image notices shown at the top.
        if (index < noticeCount) {
          return Container(
            color: const Color(0xFF0D1A0D),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              imageNotices[index],
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF66BB6A),
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        final msgIndex = index - noticeCount;
        if (msgIndex < messages.length) {
          final msg = messages[msgIndex];
          if (msg.isPass) return const SizedBox.shrink();
          // Ephemeral web-result injections render as collapsible search entries.
          if (msg.isEphemeral) {
            return SearchActivityEntry(
              label: msg.content,
              responseBody: msg.responseBody,
            );
          }
          final whisperTarget = msg.isWhisper
              ? (msg as WhisperMessage).targetCharacter
              : null;
          return _MessageRow(
            name: msg.participantName,
            content: msg.content,
            isUser: msg.isUser,
            roundIndex: msg.roundIndex,
            ownerColor: charColor,
            whisperTarget: whisperTarget,
          );
        }
        // Live streaming row — always in the latest round.
        final latestRound = messages.isNotEmpty
            ? messages.last.roundIndex
            : 0;
        return _MessageRow(
          name: ownerName,
          content: liveText,
          isUser: false,
          roundIndex: latestRound,
          ownerColor: charColor,
          isStreaming: true,
        );
      },
    );
  }

  /// Truncates [content] to at most [maxLen] characters for compact display.
  static String _truncate(String content, {int maxLen = 60}) {
    final preview = content.replaceAll('\n', ' ').trim();
    return preview.length > 60 ? '${preview.substring(0, 57)}...' : preview;
  }
}

// ---------------------------------------------------------------------------
// _JumpToLatestButton
// ---------------------------------------------------------------------------

class _JumpToLatestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _JumpToLatestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.arrow_downward_rounded,
                size: 11, color: AppColors.accent),
            SizedBox(width: 4),
            Text(
              'Jump to Latest',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MessageRow
// ---------------------------------------------------------------------------

class _MessageRow extends StatelessWidget {
  final String name;
  final String content;
  final bool isUser;
  final int roundIndex;
  final Color ownerColor;
  final bool isStreaming;
  /// Non-null when this is a whisper message; holds the target character name.
  final String? whisperTarget;

  const _MessageRow({
    required this.name,
    required this.content,
    required this.isUser,
    required this.roundIndex,
    required this.ownerColor,
    this.isStreaming = false,
    this.whisperTarget,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _roundColor(roundIndex);
    final isWhisper = whisperTarget != null;

    // Whisper label: "🤫 name → TARGET"
    final nameLabel = isWhisper
        ? '🤫 $name→$whisperTarget  '
        : (isUser ? '$name  ' : '');

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: nameLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isWhisper
                    ? const Color(0xFF9B59B6)
                    : AppColors.accent,
                letterSpacing: 0.5,
              ),
            ),
            if (isUser || isWhisper)
              TextSpan(
                text: content,
                style: TextStyle(
                  fontSize: 12,
                  color: isWhisper
                      ? const Color(0xFFCE93D8)
                      : AppColors.accent,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              TextSpan(
                text: content,
                style: TextStyle(
                  fontSize: 12,
                  color: isStreaming
                      ? AppColors.textPrimary.withValues(alpha: 0.80)
                      : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ThinkingIndicator
// ---------------------------------------------------------------------------

class _ThinkingIndicator extends StatelessWidget {
  final int dotCount;
  final Color charColor;

  const _ThinkingIndicator({
    required this.dotCount,
    required this.charColor,
  });

  @override
  Widget build(BuildContext context) {
    final dots = '.' * (dotCount + 1);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.statusBackground,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: charColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'thinking$dots',
            style: TextStyle(
              fontSize: 10,
              color: charColor.withValues(alpha: 0.75),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
