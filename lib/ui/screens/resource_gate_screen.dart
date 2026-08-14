// Resource Gate Screen for deepThink.
//
// Shown at startup when free RAM is below the safe threshold (~24 GB).
// Displays a live RAM gauge, per-process breakdown, per-model readiness,
// and automatically triggers Ollama provisioning the moment the user frees
// enough resources.
//
// The screen watches a ResourceMonitor stream every 2 seconds and advances
// to WelcomeScreen automatically once RAM is sufficient.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ollama/hardware_detector.dart';
import '../../core/ollama/model_manager.dart';
import '../../core/ollama/model_registry.dart';
import '../../core/ollama/ollama_client.dart';
import '../../core/ollama/ollama_launcher.dart';
import '../../core/system/resource_monitor.dart';
import '../avatars/avatar_registry.dart';
import '../avatars/avatar_widget.dart';
import '../widgets/app_theme.dart';
import 'welcome_screen.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Full stack RAM: mistral 4.1 + llama3 4.7 + gemma2 5.5 + phi3 8.2 = 22.5 GB
const double _kStackGb = 22.5;

/// Warn threshold — below this the banner turns orange.
const double _kWarnGb = 24.0;

/// Minimum free RAM to attempt starting Ollama + provisioning.
const double _kMinProvisionGb = 20.0;

// ---------------------------------------------------------------------------
// ResourceGateScreen
// ---------------------------------------------------------------------------

class ResourceGateScreen extends StatefulWidget {
  final HardwareInfo hardware;
  final List<ModelStatus> modelStatuses;

  const ResourceGateScreen({
    required this.hardware,
    required this.modelStatuses,
    super.key,
  });

  @override
  State<ResourceGateScreen> createState() => _ResourceGateScreenState();
}

class _ResourceGateScreenState extends State<ResourceGateScreen>
    with SingleTickerProviderStateMixin {
  late final ResourceMonitor _monitor;
  StreamSubscription<ResourceSnapshot>? _sub;

  ResourceSnapshot? _latest;
  bool _provisioning = false;
  bool _provisionDone = false;
  String _provisionStatus = '';

  // Pulse animation for the RAM bar
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _monitor = ResourceMonitor();
    _sub = _monitor.snapshots.listen(_onSnapshot);
    _monitor.start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _monitor.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Snapshot handler — called every 2 s
  // -------------------------------------------------------------------------

  void _onSnapshot(ResourceSnapshot snap) {
    if (!mounted) return;
    setState(() => _latest = snap);

    // If we've already advanced, do nothing.
    if (_provisionDone) return;

    // Once enough RAM is free, start provisioning (once).
    if (!_provisioning && snap.freeGb >= _kMinProvisionGb) {
      _startProvisioning(snap);
    }
  }

  Future<void> _startProvisioning(ResourceSnapshot snap) async {
    if (_provisioning) return;
    setState(() {
      _provisioning = true;
      _provisionStatus = 'Starting Ollama engine…';
    });

    try {
      // Step 1 — (Re-)start Ollama if needed.
      final launcher = OllamaLauncher();
      await launcher.start();
      if (!mounted) return;
      setState(() => _provisionStatus = 'Checking installed models…');

      // Step 2 — Re-check model statuses.
      final statuses =
          await ModelManager(client: OllamaClient()).checkModels();
      if (!mounted) return;

      // Step 3 — Re-detect hardware with fresh free-RAM reading.
      final hardware = await HardwareDetector.detect();
      if (!mounted) return;

      setState(() {
        _provisionDone = true;
        _provisionStatus = 'Ready!';
      });

      // Small pause so the user sees "Ready!" before we switch.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WelcomeScreen(
            hardware: hardware,
            modelStatuses: statuses,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _provisioning = false;
        _provisionStatus = 'Error: $e — retrying next cycle…';
      });
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final snap = _latest;
    final freeGb = snap?.freeGb ?? widget.hardware.freeRamGb;
    final totalGb = snap?.totalGb ?? widget.hardware.totalRamGb;
    final fraction = totalGb > 0 ? (freeGb / totalGb).clamp(0.0, 1.0) : 0.0;
    final isCritical = freeGb < 16.0;
    final isWarn = freeGb < _kWarnGb;
    final barColor = isCritical
        ? const Color(0xFFF44336)
        : isWarn
            ? const Color(0xFFFF9800)
            : const Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(freeGb, isCritical),
                const SizedBox(height: 28),
                _buildRamGauge(freeGb, totalGb, fraction, barColor),
                const SizedBox(height: 24),
                _buildStackRequirement(freeGb),
                const SizedBox(height: 24),
                if (snap != null && snap.topProcesses.isNotEmpty) ...[
                  _buildProcessList(snap.topProcesses),
                  const SizedBox(height: 24),
                ],
                _buildModelReadiness(freeGb),
                const SizedBox(height: 24),
                _buildProvisionStatus(freeGb),
                const SizedBox(height: 16),
                _buildTips(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(double freeGb, bool isCritical) {
    final snap = _latest;
    final hasData = snap != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: AvatarRegistry.build(
            'energyOrb',
            state: AvatarState.idle,
            characterName: 'DEEP',
            size: 52,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'deepThinkER needs more memory',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasData
                    ? 'Monitoring every 2 s — ${freeGb.toStringAsFixed(1)} GB free right now. '
                      'Free up at least ${(_kMinProvisionGb - freeGb).clamp(0, 99).toStringAsFixed(1)} GB more to continue.'
                    : 'Scanning your system…',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        // Live pulse dot
        if (hasData)
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: _pulseAnim.value,
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCritical
                      ? const Color(0xFFF44336)
                      : const Color(0xFF4CAF50),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── RAM gauge ──────────────────────────────────────────────────────────────

  Widget _buildRamGauge(
      double freeGb, double totalGb, double fraction, Color barColor) {
    final usedGb = (totalGb - freeGb).clamp(0.0, totalGb);
    // Where the "safe" threshold line falls on the bar
    final safeLineFrac = (totalGb > 0)
        ? (1.0 - (_kMinProvisionGb / totalGb)).clamp(0.0, 1.0)
        : 0.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('System Memory',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5)),
              Text(
                '${freeGb.toStringAsFixed(1)} GB free  /  '
                '${totalGb.toStringAsFixed(0)} GB total',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Gauge bar
          LayoutBuilder(builder: (ctx, cst) {
            final w = cst.maxWidth;
            final safeX = safeLineFrac * w;
            return SizedBox(
              height: 22,
              child: Stack(
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Used (from left)
                  FractionallySizedBox(
                    widthFactor: (usedGb / totalGb).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Free segment (right portion)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Safe-threshold marker line
                  Positioned(
                    left: safeX,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: const Color(0xFFFFFFFF).withOpacity(0.35),
                    ),
                  ),
                  // Labels inside bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Used  ${usedGb.toStringAsFixed(1)} GB',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Free  ${freeGb.toStringAsFixed(1)} GB',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                  width: 2,
                  height: 10,
                  color: Colors.white38),
              const SizedBox(width: 4),
              Text(
                '${_kMinProvisionGb.toStringAsFixed(0)} GB free needed to launch  '
                '(${_kStackGb.toStringAsFixed(1)} GB stack + headroom)',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stack requirement ──────────────────────────────────────────────────────

  Widget _buildStackRequirement(double freeGb) {
    final models = ModelRegistry.all;
    double cumulative = 0.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Model Stack',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...models.map((m) {
            cumulative += m.ramGb;
            final willFit = freeGb >= cumulative;
            final statusColor = willFit
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    willFit
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.displayName,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '~${m.ramGb.toStringAsFixed(1)} GB',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'cumulative: ${cumulative.toStringAsFixed(1)} GB',
                      style: TextStyle(
                          fontSize: 10,
                          color: willFit
                              ? AppColors.textSecondary
                              : const Color(0xFFFF9800),
                          fontFamily: 'monospace'),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: AppColors.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total stack:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text(
                '~${_kStackGb.toStringAsFixed(1)} GB',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Process list ───────────────────────────────────────────────────────────

  Widget _buildProcessList(List<ProcessMemInfo> procs) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Top Memory Consumers',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5)),
              SizedBox(width: 8),
              Text('— close these to free RAM',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          ...procs.map((p) {
            // Highlight AI/LLM processes in orange — they're the main culprits.
            final isAi = _isAiProcess(p.name);
            final nameColor =
                isAi ? const Color(0xFFFF9800) : AppColors.textPrimary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  if (isAi)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.psychology_rounded,
                          size: 12, color: Color(0xFFFF9800)),
                    )
                  else
                    const SizedBox(width: 17),
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                          fontSize: 12, color: nameColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${p.rssGb.toStringAsFixed(1)} GB',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAi
                          ? const Color(0xFFFF9800)
                          : AppColors.textSecondary,
                      fontFamily: 'monospace',
                      fontWeight:
                          isAi ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Model readiness ────────────────────────────────────────────────────────

  Widget _buildModelReadiness(double freeGb) {
    final ready = freeGb >= _kMinProvisionGb;
    return _Card(
      borderColor: ready
          ? const Color(0xFF1e3a1e)
          : const Color(0xFF3a2a00),
      child: Row(
        children: [
          Icon(
            ready
                ? Icons.rocket_launch_rounded
                : Icons.hourglass_top_rounded,
            color: ready
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ready
                  ? 'Enough memory available — starting Ollama and loading models…'
                  : 'Waiting for ${(_kMinProvisionGb - freeGb).clamp(0, 99).toStringAsFixed(1)} GB more free RAM. '
                    'Close apps above to continue automatically.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ready
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Provision status ───────────────────────────────────────────────────────

  Widget _buildProvisionStatus(double freeGb) {
    if (!_provisioning && !_provisionDone) return const SizedBox.shrink();
    return Row(
      children: [
        if (!_provisionDone)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          )
        else
          const Icon(Icons.check_circle_rounded,
              size: 14, color: Color(0xFF4CAF50)),
        const SizedBox(width: 8),
        Text(
          _provisionStatus,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ── Tips ───────────────────────────────────────────────────────────────────

  Widget _buildTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Tips to free memory',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
        SizedBox(height: 6),
        _Tip(
            icon: Icons.psychology_outlined,
            text:
                'Quit any other AI tools (LM Studio, Ollama CLI sessions, ChatGPT desktop, etc.)'),
        _Tip(
            icon: Icons.web_rounded,
            text:
                'Close browser tabs — each tab can use 100–500 MB of RAM'),
        _Tip(
            icon: Icons.apps_rounded,
            text:
                'Quit unused apps via ⌘Q, not just closing their windows'),
        _Tip(
            icon: Icons.memory_rounded,
            text:
                'On macOS: Activity Monitor → Memory tab → sort by Memory to find hogs'),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _isAiProcess(String name) {
    const aiKeywords = [
      'ollama', 'llama', 'lmstudio', 'lm studio', 'chatgpt',
      'claude', 'mistral', 'python', 'node', 'whisper', 'stable',
    ];
    final lower = name.toLowerCase();
    return aiKeywords.any((k) => lower.contains(k));
  }
}

// ---------------------------------------------------------------------------
// Reusable sub-widgets
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: child,
      );
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
            ),
          ],
        ),
      );
}
