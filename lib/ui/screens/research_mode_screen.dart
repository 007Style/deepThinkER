import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/conversation/conversation_engine.dart';
import '../../core/conversation/inference_worker.dart';
import '../../core/ollama/ollama_client.dart';
import '../../core/research/research_engine.dart';
import '../widgets/research/phase_indicator.dart';
import '../widgets/research/report_preview_widget.dart';

// ---------------------------------------------------------------------------
// ResearchModeScreen
// ---------------------------------------------------------------------------

/// Full-screen Autonomous Research Mode UI.
///
/// The user enters a topic, presses Start, and the four characters
/// autonomously research, debate, and synthesise findings.
class ResearchModeScreen extends StatefulWidget {
  /// The active conversation engine shared with [MainScreen].
  final ConversationEngine engine;

  /// Character names for the four participants.
  final List<String> characterNames;

  /// Ollama client (used to create a ResearchEngine if needed).
  final OllamaClient ollamaClient;

  const ResearchModeScreen({
    super.key,
    required this.engine,
    required this.characterNames,
    required this.ollamaClient,
  });

  @override
  State<ResearchModeScreen> createState() => _ResearchModeScreenState();
}

class _ResearchModeScreenState extends State<ResearchModeScreen> {
  late final ResearchEngine _researchEngine;

  final TextEditingController _topicController = TextEditingController();
  final StreamController<ResearchPhase> _phaseStreamController =
      StreamController<ResearchPhase>.broadcast();

  bool _isRunning = false;
  bool _isPaused = false;
  ResearchPhase _currentPhase = ResearchPhase.gathering;
  String _reportMarkdown = '';

  // Per-character last tool call label.
  final Map<String, String> _lastActivity = {};

  // Synthesis counts.
  int _synthesisCount = 0;

  StreamSubscription<ResearchPhaseEvent>? _phaseSub;
  StreamSubscription<InferenceEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _researchEngine = ResearchEngine(
      engine: widget.engine,
      characterNames: widget.characterNames,
    );

    // Forward phase events to the PhaseIndicator stream.
    _phaseSub = _researchEngine.phaseStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _currentPhase = event.phase;
        if (event.synthesisByCharacter != null) {
          _synthesisCount++;
          _lastActivity[event.synthesisByCharacter!] =
              '📝 synthesis submitted';
        }
        if (event.phase == ResearchPhase.complete) {
          _isRunning = false;
          _loadReport(event.reportPath);
        }
      });
      _phaseStreamController.add(event.phase);
    });

    // Track per-character tool call activity.
    _eventSub = widget.engine.eventStream.listen((event) {
      if (!mounted) return;
      if (event.toolCallEvent != null) {
        final tc = event.toolCallEvent!;
        setState(() {
          _lastActivity[event.participantName] =
              '${_tagEmoji(tc.tag)} ${tc.tag.toLowerCase()}: '
              '${tc.argument.length > 30 ? '${tc.argument.substring(0, 30)}…' : tc.argument}';
        });
      }
    });
  }

  void _loadReport(String? path) {
    if (path == null || path.isEmpty) return;
    // Report content is already written by ReportGenerator.
    // We display a success message pointing to the file.
    setState(() {
      _reportMarkdown = '# Research Complete\n\n'
          'Report saved to:\n\n'
          '`$path`\n\n'
          '---\n\n'
          '**${widget.characterNames.length} characters participated.**  \n'
          '$_synthesisCount synthesis statements collected.';
    });
  }

  String _tagEmoji(String tag) {
    switch (tag.toUpperCase()) {
      case 'SEARCH':
        return '🔍';
      case 'FETCH':
        return '🌐';
      case 'RECALL':
        return '🧠';
      default:
        return '🔧';
    }
  }

  @override
  void dispose() {
    _phaseSub?.cancel();
    _eventSub?.cancel();
    _researchEngine.dispose();
    _topicController.dispose();
    _phaseStreamController.close();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _startResearch() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a research topic.')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _isPaused = false;
      _currentPhase = ResearchPhase.gathering;
      _reportMarkdown = '';
      _synthesisCount = 0;
      _lastActivity.clear();
    });

    await _researchEngine.startResearch(topic);
    _phaseStreamController.add(ResearchPhase.gathering);
  }

  void _pauseResume() {
    if (_isPaused) {
      _researchEngine.resume();
    } else {
      _researchEngine.pause();
    }
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopResearch() async {
    await _researchEngine.stopResearch();
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Text('🔬', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Research Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Phase indicator (shown when running).
          if (_isRunning)
            PhaseIndicator(
              phaseStream: _phaseStreamController.stream,
              initialPhase: _currentPhase,
            ),

          // Topic input + controls.
          _buildTopicBar(),

          const Divider(color: Color(0xFF21262D), height: 1),

          // Main content: character activity feeds + report preview.
          Expanded(
            child: _isRunning || _reportMarkdown.isNotEmpty
                ? _buildRunningContent()
                : _buildIdleContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _topicController,
              enabled: !_isRunning,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter research topic…',
                hintStyle: const TextStyle(color: Color(0xFF6E7681)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => !_isRunning ? _startResearch() : null,
            ),
          ),
          const SizedBox(width: 8),
          if (!_isRunning)
            ElevatedButton.icon(
              onPressed: _startResearch,
              icon: const Text('🔬', style: TextStyle(fontSize: 14)),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: _pauseResume,
              icon: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                size: 18,
                color: Colors.amber,
              ),
              label: Text(
                _isPaused ? 'Resume' : 'Pause',
                style: const TextStyle(color: Colors.amber),
              ),
            ),
            TextButton.icon(
              onPressed: _stopResearch,
              icon: const Icon(Icons.stop, size: 18, color: Colors.red),
              label:
                  const Text('Stop', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdleContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔬', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'Enter a topic above and press Start.',
            style: TextStyle(color: Color(0xFF6E7681), fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'All four characters will independently research,\n'
            'debate, and synthesise findings autonomously.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF484F58), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningContent() {
    return Column(
      children: [
        // Character activity row.
        if (_isRunning || _lastActivity.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF161B22),
            child: Row(
              children: widget.characterNames
                  .map((name) => Expanded(
                        child: _CharacterActivityTile(
                          name: name,
                          activity: _lastActivity[name] ?? '…',
                          isSynthesised: _researchEngine.currentSession
                                  ?.synthesisStatements
                                  .containsKey(name) ??
                              false,
                        ),
                      ))
                  .toList(),
            ),
          ),

        // Synthesis progress bar.
        if (_isRunning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Syntheses: $_synthesisCount / ${widget.characterNames.length}',
                  style: const TextStyle(
                      color: Color(0xFF6E7681), fontSize: 11),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _synthesisCount / widget.characterNames.length,
                    backgroundColor: const Color(0xFF21262D),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),

        const Divider(color: Color(0xFF21262D), height: 1),

        // Report preview.
        Expanded(
          child: _reportMarkdown.isNotEmpty
              ? ReportPreviewWidget(reportMarkdown: _reportMarkdown)
              : const Center(
                  child: Text(
                    'Report will appear here when research is complete.',
                    style:
                        TextStyle(color: Color(0xFF484F58), fontSize: 12),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterActivityTile
// ---------------------------------------------------------------------------

class _CharacterActivityTile extends StatelessWidget {
  final String name;
  final String activity;
  final bool isSynthesised;

  const _CharacterActivityTile({
    required this.name,
    required this.activity,
    required this.isSynthesised,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isSynthesised
            ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
            : const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSynthesised
              ? const Color(0xFF2E7D32)
              : const Color(0xFF21262D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isSynthesised
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFFB0BEC5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSynthesised) ...[
                const SizedBox(width: 4),
                const Text('✅', style: TextStyle(fontSize: 10)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            activity,
            style: const TextStyle(
              color: Color(0xFF6E7681),
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
