// Startup configuration screen for deepThink.
//
// Shown every launch (once all models are installed). Lets the user:
//   • Name the session (or generate a fun name)
//   • Configure the model and system prompt for each of the four characters
//   • See the live total RAM allocation
//   • View detected hardware info
//   • Launch into MainScreen
import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/conversation/conversation_log.dart';
import '../../core/conversation/participant.dart';
import '../../core/ollama/model_manager.dart';
import '../../core/ollama/ollama_client.dart';
import '../../core/ollama/hardware_detector.dart';
import '../../core/ollama/model_registry.dart';
import '../../core/paths/app_paths.dart';
import '../../core/persona/user_persona.dart';
import '../../core/session/name_generator.dart';
import '../../core/session/participant_prefs.dart';
import '../../core/session/replay_mode.dart';
import '../../core/session/session_loader.dart';
import '../widgets/app_theme.dart';
import '../widgets/character_config_card.dart';
import '../widgets/help_menu.dart';
import '../widgets/ram_total_display.dart';
import '../widgets/whitelist_editor.dart';
import 'main_screen.dart';

// ---------------------------------------------------------------------------
// StartupConfigScreen
// ---------------------------------------------------------------------------

/// Per-launch session configuration screen.
///
/// Requires [hardware] to display detected system info. If not supplied at
/// construction time (e.g. when navigated to from [FirstLaunchScreen]) the
/// screen detects hardware itself during its loading phase.
class StartupConfigScreen extends StatefulWidget {
  /// Pre-detected hardware info. May be null — screen will detect it if so.
  final HardwareInfo? hardware;

  const StartupConfigScreen({
    this.hardware,
    super.key,
  });

  @override
  State<StartupConfigScreen> createState() => _StartupConfigScreenState();
}

class _StartupConfigScreenState extends State<StartupConfigScreen> {
  // ── Loaded hardware ───────────────────────────────────────────────────────
  HardwareInfo? _hardware;
  bool _detectingHardware = false;

  // ── Participants (mutable copies) ─────────────────────────────────────────
  late final List<Participant> _participants;

  // ── Session name ──────────────────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final _nameGenerator = NameGenerator();

  // ── User persona ─────────────────────────────────────────────────────────
  UserPersona _persona = UserPersona();
  final TextEditingController _personaController = TextEditingController();

  // ── Focus node ────────────────────────────────────────────────────────────
  final FocusNode _nameFocus = FocusNode();

  // ── Name dice animation ───────────────────────────────────────────────────
  bool _diceSpinning = false;

  @override
  void initState() {
    super.initState();
    _participants = Participant.defaults();
    _nameController.text = _nameGenerator.generate();

    if (widget.hardware != null) {
      _hardware = widget.hardware;
    } else {
      _detectHardware();
    }

    // Load last-used model + prompt for each character.
    _loadPrefs();
    // Load persona.
    _loadPersona();
  }

  Future<void> _loadPersona() async {
    _persona = await UserPersona.load();
    if (mounted) {
      setState(() {
        _personaController.text = _persona.text;
      });
    }
  }

  Future<void> _loadPrefs() async {
    await ParticipantPrefs.load(_participants);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _personaController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _detectHardware() async {
    setState(() => _detectingHardware = true);
    final info = await HardwareDetector.detect();
    if (mounted) {
      setState(() {
        _hardware = info;
        _detectingHardware = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Computed values
  // -------------------------------------------------------------------------

  List<double> get _ramValues => _participants
      .map((p) => ModelRegistry.findById(p.assignedModelId)?.ramGb ?? 0.0)
      .toList();

  String get _contextLabel {
    final hw = _hardware;
    if (hw == null) return 'Detecting…';
    final ctx = (hw.standardContextWindow / 1024).round();
    return 'Detected: ${hw.totalRamGb.toStringAsFixed(0)} GB RAM  ·  '
        '${hw.backendDisplayName}  ·  Context: ${ctx}k tokens';
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _generateName() async {
    setState(() => _diceSpinning = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      _nameController.text = _nameGenerator.generate();
      _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length),
      );
      _diceSpinning = false;
    });
  }

  void _launch() {
    final hw = _hardware;
    if (hw == null) return;

    String sessionName = _nameController.text.trim();
    if (sessionName.isEmpty) {
      sessionName = _nameGenerator.generate();
      _nameController.text = sessionName;
    }

    // Persist current model + prompt choices and persona before launching.
    ParticipantPrefs.save(_participants);
    _persona.save().ignore(); // fire-and-forget

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainScreen(
          participants: _participants,
          hardware: hw,
        ),
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    await ParticipantPrefs.clear();
    final fresh = Participant.defaults();
    setState(() {
      for (var i = 0; i < _participants.length; i++) {
        _participants[i].assignedModelId = fresh[i].assignedModelId;
        _participants[i].masterPrompt = fresh[i].masterPrompt;
      }
    });
  }

  /// Shows a confirmation dialog then deletes all Ollama models and all app data.
  Future<void> _deleteAllModelsAndData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Delete All Models & App Data?',
          style: TextStyle(
            color: Color(0xFFF44336),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will:\n'
          '  • Remove all Ollama models from disk\n'
          '  • Delete all sessions, memory, settings and\n'
          '    every other file in the app data folder\n\n'
          'This cannot be undone.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete Everything',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show progress dialog while deletion runs.
    final statusLines = <String>[];
    final progressKey = GlobalKey<_DeleteProgressDialogState>();

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteProgressDialog(key: progressKey),
    ));

    final manager = ModelManager(client: OllamaClient());
    await manager.deleteAllModelsAndData(
      onStatus: (msg) {
        statusLines.add(msg);
        progressKey.currentState?.addLine(msg);
      },
    );

    if (!mounted) return;
    // Close progress dialog.
    Navigator.of(context).pop();

    // Show completion summary.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Clean-up Complete',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Text(
            statusLines.join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  /// Opens a dialog listing past session .txt files for replay.
  Future<void> _loadPastSession() async {
    final hw = _hardware;
    if (hw == null) return;

    // Locate the sessions directory.
    final sessionsDir = Directory(AppPaths.sessions);

    List<FileSystemEntity> files = [];
    if (await sessionsDir.exists()) {
      files = await sessionsDir
          .list()
          .where((e) => e is File && e.path.endsWith('.txt'))
          .toList();
    }

    if (!mounted) return;

    if (files.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'No sessions found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'No .txt files found in ${sessionsDir.path}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    // Sort by name for a predictable order.
    files.sort((a, b) => a.path.compareTo(b.path));

    // Show the picker dialog. Returns [filePath, mode].
    final result = await showDialog<(String, ReplayMode)>(
      context: context,
      builder: (ctx) => _SessionPickerDialog(files: files),
    );

    if (result == null || !mounted) return;

    final (filePath, mode) = result;

    // Load the log.
    ConversationLog replayLog;
    try {
      replayLog = await SessionLoader.load(filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load session: $e')),
      );
      return;
    }

    final sessionName =
        filePath.split(Platform.pathSeparator).last.replaceAll('.txt', '');

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainScreen(
          participants: _participants,
          hardware: hw,
          replayLog: replayLog,
          replayMode: mode,
          replaySessionName: sessionName,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Model / prompt change handlers
  // -------------------------------------------------------------------------

  void _onModelChanged(int index, String modelId) {
    setState(() => _participants[index].assignedModelId = modelId);
  }

  void _onPromptChanged(int index, String prompt) {
    _participants[index].masterPrompt = prompt;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _detectingHardware && _hardware == null
              ? const _LoadingSpinner()
              : _buildContent(),
          // Help button — top-right overlay
          Positioned(
            top: 8,
            right: 8,
            child: HelpMenuButton(hardware: _hardware),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── App logo ─────────────────────────────────────────────────
              _AppLogo(),

              const SizedBox(height: 36),

              // ── Session name row ─────────────────────────────────────────
              _SectionLabel(label: 'SESSION NAME'),
              const SizedBox(height: 8),
              _SessionNameRow(
                controller: _nameController,
                focusNode: _nameFocus,
                diceSpinning: _diceSpinning,
                onGenerate: _generateName,
              ),
              const SizedBox(height: 8),
              // ── Load past session ────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _hardware != null ? _loadPastSession : null,
                  icon: const Text('\u23EA', style: TextStyle(fontSize: 13)),
                  label: const Text('\u202FLoad Past Session'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Hardware info ────────────────────────────────────────────
              _HardwareInfoBar(label: _contextLabel),

              const SizedBox(height: 28),

              // ── RAM total ────────────────────────────────────────────────
              _SectionLabel(label: 'ESTIMATED RAM USAGE'),
              const SizedBox(height: 8),
              RamTotalDisplay(modelRamValues: _ramValues),

              const SizedBox(height: 28),

              // ── Character cards ──────────────────────────────────────────
              _SectionLabel(label: 'AI CHARACTERS'),
              const SizedBox(height: 12),
              _CharacterGrid(
                participants: _participants,
                onModelChanged: _onModelChanged,
                onPromptChanged: _onPromptChanged,
              ),

              const SizedBox(height: 24),

              // ── User Persona ────────────────────────────────────────────
              _SectionLabel(label: 'USER PERSONA'),
              const SizedBox(height: 8),
              TextField(
                controller: _personaController,
                maxLength: UserPersona.maxLength,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe yourself (injected into all AI prompts)…',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.4),
                  ),
                ),
                onChanged: (v) => _persona.text = v,
              ),

              const SizedBox(height: 24),

              // ── Network Access ───────────────────────────────────────────
              _SectionLabel(label: 'NETWORK ACCESS'),
              const SizedBox(height: 12),
              _NetworkAccessSection(participants: _participants),

              const SizedBox(height: 24),

              // ── Domain Whitelist ─────────────────────────────────────────
              _SectionLabel(label: 'DOMAIN WHITELIST'),
              const SizedBox(height: 12),
              const WhitelistEditor(),

              const SizedBox(height: 24),

              // ── Reset / Launch row ───────────────────────────────────────
              Row(
                children: [
                  // Reset to Defaults — left-aligned, subdued
                  TextButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore_rounded, size: 15),
                    label: const Text('Reset to Defaults'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete all models & app data — destructive, subdued
                  TextButton.icon(
                    onPressed: _deleteAllModelsAndData,
                    icon: const Icon(Icons.delete_forever_outlined, size: 15,
                        color: Color(0xFFE57373)),
                    label: const Text('Delete All Models & App Data',
                        style: TextStyle(color: Color(0xFFE57373))),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE57373),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  // Launch button — right-aligned
                  SizedBox(
                    height: 52,
                    width: 240,
                    child: _LaunchButton(
                      enabled: _hardware != null,
                      onPressed: _launch,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LoadingSpinner
// ---------------------------------------------------------------------------

class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppLogo
// ---------------------------------------------------------------------------

class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Glow effect via Stack + BlurMask
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow layer
            Text(
              'deepThinkER',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.accent.withValues(alpha: 0.25),
                letterSpacing: 4,
              ),
            ),
            // Crisp top layer
            const Text(
              'deepThinkER',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Multi-agent AI · Extended Reach',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionLabel
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SessionNameRow
// ---------------------------------------------------------------------------

class _SessionNameRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool diceSpinning;
  final VoidCallback onGenerate;

  const _SessionNameRow({
    required this.controller,
    required this.focusNode,
    required this.diceSpinning,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter session name\u2026',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 🎲 Generate button
        AnimatedRotation(
          turns: diceSpinning ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 120),
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            onPressed: onGenerate,
            child: const Text(
              '\uD83C\uDFB2 Generate',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _HardwareInfoBar
// ---------------------------------------------------------------------------

class _HardwareInfoBar extends StatelessWidget {
  final String label;

  const _HardwareInfoBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.memory_outlined,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterGrid
// ---------------------------------------------------------------------------

class _CharacterGrid extends StatelessWidget {
  final List<Participant> participants;
  final void Function(int index, String modelId) onModelChanged;
  final void Function(int index, String prompt) onPromptChanged;

  const _CharacterGrid({
    required this.participants,
    required this.onModelChanged,
    required this.onPromptChanged,
  });

  @override
  Widget build(BuildContext context) {
    // On wide screens use 2×2 grid; on narrow screens a single column.
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 600;

        if (useGrid) {
          return Column(
            children: [
              // Row 0: WATSON + DEEP
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CharacterConfigCard(
                      participant: participants[0],
                      onModelChanged: (id) => onModelChanged(0, id),
                      onPromptChanged: (p) => onPromptChanged(0, p),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CharacterConfigCard(
                      participant: participants[1],
                      onModelChanged: (id) => onModelChanged(1, id),
                      onPromptChanged: (p) => onPromptChanged(1, p),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 1: NOVA + SAGE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CharacterConfigCard(
                      participant: participants[2],
                      onModelChanged: (id) => onModelChanged(2, id),
                      onPromptChanged: (p) => onPromptChanged(2, p),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CharacterConfigCard(
                      participant: participants[3],
                      onModelChanged: (id) => onModelChanged(3, id),
                      onPromptChanged: (p) => onPromptChanged(3, p),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // Single-column fallback
        return Column(
          children: List.generate(
            participants.length,
            (i) => Padding(
              padding: EdgeInsets.only(
                bottom: i < participants.length - 1 ? 16 : 0,
              ),
              child: CharacterConfigCard(
                participant: participants[i],
                onModelChanged: (id) => onModelChanged(i, id),
                onPromptChanged: (p) => onPromptChanged(i, p),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _LaunchButton
// ---------------------------------------------------------------------------

class _LaunchButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _LaunchButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? AppColors.accent : AppColors.border,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: enabled ? 2 : 0,
        ),
        onPressed: enabled ? onPressed : null,
        child: const Text(
          '\u25B6  Launch Session',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NetworkAccessSection
// ---------------------------------------------------------------------------

/// Per-character network access toggles + global rate cap + proactive toggle.
class _NetworkAccessSection extends StatefulWidget {
  final List<Participant> participants;

  const _NetworkAccessSection({required this.participants});

  @override
  State<_NetworkAccessSection> createState() => _NetworkAccessSectionState();
}

class _NetworkAccessSectionState extends State<_NetworkAccessSection> {
  // Per-character network enabled state (true = ON).
  late final List<bool> _networkEnabled;
  int _globalRateCap = 10;
  bool _proactiveEnabled = true;

  @override
  void initState() {
    super.initState();
    _networkEnabled = List.filled(widget.participants.length, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Per-character toggles
          ...List.generate(widget.participants.length, (i) {
            final p = widget.participants[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _networkEnabled[i] ? 'Network ON' : 'Network OFF',
                    style: TextStyle(
                      fontSize: 11,
                      color: _networkEnabled[i]
                          ? AppColors.accent.withValues(alpha: 0.8)
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _networkEnabled[i],
                    onChanged: (v) => setState(() => _networkEnabled[i] = v),
                    activeColor: AppColors.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 16, color: AppColors.border),

          // Global rate cap
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Global rate cap (searches/min)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  controller: TextEditingController(
                      text: _globalRateCap.toString()),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      setState(() => _globalRateCap = n);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Proactive injection toggle
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Proactive context injection',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: _proactiveEnabled,
                onChanged: (v) => setState(() => _proactiveEnabled = v),
                activeColor: AppColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SessionPickerDialog
// ---------------------------------------------------------------------------

/// Dialog that lists available .txt session files and lets the user choose
/// between Continue and Reflection mode for each.
class _SessionPickerDialog extends StatelessWidget {
  final List<FileSystemEntity> files;

  const _SessionPickerDialog({required this.files});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Load Past Session',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 440,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: files.length,
          itemBuilder: (ctx, i) {
            final filePath = files[i].path;
            final fileName = filePath
                .split(Platform.pathSeparator)
                .last;
            return ListTile(
              dense: true,
              title: Text(
                fileName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Continue mode
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      textStyle: const TextStyle(fontSize: 11),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    onPressed: () => Navigator.of(ctx)
                        .pop((filePath, ReplayMode.continueSession)),
                    child: const Text('Continue'),
                  ),
                  // Reflection mode
                  IconButton(
                    icon: const Text(
                      '\uD83D\uDD0D',
                      style: TextStyle(fontSize: 14),
                    ),
                    tooltip: 'Reflection Mode',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () => Navigator.of(ctx)
                        .pop((filePath, ReplayMode.reflection)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DeleteProgressDialog — live log shown while deletion runs
// ---------------------------------------------------------------------------

class _DeleteProgressDialog extends StatefulWidget {
  const _DeleteProgressDialog({super.key});

  @override
  State<_DeleteProgressDialog> createState() => _DeleteProgressDialogState();
}

class _DeleteProgressDialogState extends State<_DeleteProgressDialog> {
  final List<String> _lines = [];

  /// Called from outside the widget to push a new status line.
  void addLine(String line) {
    if (mounted) setState(() => _lines.add(line));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Deleting…',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 200,
        child: SingleChildScrollView(
          reverse: true,
          child: Text(
            _lines.join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
