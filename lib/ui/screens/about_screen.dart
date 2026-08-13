// Animated About screen for deepThink.
//
// Full-screen Stack:
//   • Bottom layer: NeuralBackgroundPainter (full-screen, continuously animated)
//   • Middle layer: WanderingCharactersLayer (emoji characters in margins)
//   • Top layer:    scrollable content with app title, character bios,
//                   app stats, and system information.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ollama/hardware_detector.dart';
import '../../core/ollama/model_registry.dart';
import '../../core/session/app_stats.dart';
import '../../core/session/session_manager.dart';
import '../about/neural_background_painter.dart';
import '../about/wandering_characters_layer.dart';
import '../avatars/avatar_widget.dart';
import '../avatars/energy_orb/energy_orb_avatar.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// AboutScreen
// ---------------------------------------------------------------------------

/// The fully animated About screen — the showpiece of the app.
///
/// All animations run continuously.  Stats are loaded asynchronously.
class AboutScreen extends StatefulWidget {
  /// Pre-detected hardware info.  If null, the screen will detect it itself.
  final HardwareInfo? hardware;

  const AboutScreen({this.hardware, super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _neuralCtrl;
  late final AnimationController _glowCtrl;

  // ── Async data ────────────────────────────────────────────────────────────
  AppStats? _stats;
  HardwareInfo? _hardware;

  @override
  void initState() {
    super.initState();

    // Neural background: 6-second continuous loop.
    _neuralCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // App title glow: 3-second continuous pulse.
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _loadData();
  }

  @override
  void dispose() {
    _neuralCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final manager = SessionManager();
    final stats = await manager.loadStats();
    final hw = widget.hardware ?? await HardwareDetector.detect();
    if (mounted) {
      setState(() {
        _stats = stats;
        _hardware = hw;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Layer 1: Neural network background ──────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _neuralCtrl,
              builder: (context, _) => CustomPaint(
                painter: NeuralBackgroundPainter(
                  animationValue: _neuralCtrl.value,
                ),
              ),
            ),
          ),

          // ── Layer 2: Wandering characters ────────────────────────────────
          const Positioned.fill(
            child: WanderingCharactersLayer(),
          ),

          // ── Layer 3: Scrollable content ──────────────────────────────────
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  // Close / back button row
                  _CloseBar(),
                  // Scrollable body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 8,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── App title ──────────────────────────────
                              _AnimatedTitle(glowCtrl: _glowCtrl),
                              const SizedBox(height: 36),

                              // ── IBM history ────────────────────────────
                              _SectionLabel(label: 'A LOVE LETTER TO IBM\'S AI HISTORY'),
                              const SizedBox(height: 16),
                              _IbmHistorySection(),
                              const SizedBox(height: 32),

                              // ── Character bio cards ────────────────────
                              _SectionLabel(label: 'THE TEAM'),
                              const SizedBox(height: 12),
                              const _CharacterBioGrid(),
                              const SizedBox(height: 32),

                              // ── App statistics ─────────────────────────
                              _SectionLabel(label: 'APPLICATION STATISTICS'),
                              const SizedBox(height: 12),
                              _StatsSection(stats: _stats),
                              const SizedBox(height: 32),

                              // ── System information ─────────────────────
                              _SectionLabel(label: 'SYSTEM INFORMATION'),
                              const SizedBox(height: 12),
                              _SystemInfoSection(hardware: _hardware),
                              const SizedBox(height: 32),

                              // ── Credits ────────────────────────────────
                              _SectionLabel(label: 'CREDITS'),
                              const SizedBox(height: 12),
                              _CreditsSection(),
                              const SizedBox(height: 32),

                              // ── Dijkstra quote ─────────────────────────
                              _QuoteSection(),
                              const SizedBox(height: 48),
                            ],
                          ),
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// _CloseBar
// ---------------------------------------------------------------------------

class _CloseBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 16),
            label: const Text(
              'Close',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AnimatedTitle
// ---------------------------------------------------------------------------

class _AnimatedTitle extends StatelessWidget {
  final AnimationController glowCtrl;

  const _AnimatedTitle({required this.glowCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (context, _) {
        final glowOpacity =
            0.15 + 0.35 * ((math.sin(glowCtrl.value * math.pi * 2) + 1) / 2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App name with animated glow
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow halo
                Text(
                  'deepThink',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent.withValues(alpha: glowOpacity),
                    letterSpacing: 5,
                  ),
                ),
                // Crisp foreground text
                const Text(
                  'deepThink',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Version
            const Text(
              'v1.0.2',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            // Tagline
            const Text(
              'From the minds of Daneyand & IBM\'s Bob',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
                letterSpacing: 0.4,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // Contact link
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse('mailto:daneyand@ibm.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Text(
                'daneyand@ibm.com',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accent,
                ),
              ),
            ),
          ],
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: AppColors.border),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterBioGrid — 2×2 grid of character bios
// ---------------------------------------------------------------------------

class _CharacterBioGrid extends StatelessWidget {
  const _CharacterBioGrid();

  static const _bios = [
    (
      name: 'WATSON',
      ibm: 'IBM Watson AI',
      personality: 'The Analyst',
      model: 'gemma2:9b',
    ),
    (
      name: 'DEEP',
      ibm: 'Deep Blue chess computer',
      personality: 'The Host · Strategist',
      model: 'phi3:14b',
    ),
    (
      name: 'NOVA',
      ibm: 'IBM POWER systems',
      personality: 'The Visionary',
      model: 'llama3:8b',
    ),
    (
      name: 'SAGE',
      ibm: 'IBM NL research',
      personality: 'The Challenger',
      model: 'mistral:7b',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 520;

        if (useGrid) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _CharacterBioCard(bio: _bios[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _CharacterBioCard(bio: _bios[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _CharacterBioCard(bio: _bios[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _CharacterBioCard(bio: _bios[3])),
                ],
              ),
            ],
          );
        }

        return Column(
          children: _bios
              .map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CharacterBioCard(bio: b),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _CharacterBioCard extends StatelessWidget {
  final ({
    String name,
    String ibm,
    String personality,
    String model,
  }) bio;

  const _CharacterBioCard({required this.bio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orb avatar (48 px, idle state)
          EnergyOrbAvatar(
            state: AvatarState.idle,
            characterName: bio.name,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bio.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bio.ibm,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  bio.personality,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                _ModelChip(model: bio.model),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  final String model;

  const _ModelChip({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        model,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatsSection
// ---------------------------------------------------------------------------

class _StatsSection extends StatelessWidget {
  final AppStats? stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Loading…',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final s = stats!;
    return _InfoCard(
      rows: [
        ('Total sessions run', _fmt(s.totalSessionsRun)),
        ('Total messages generated', _fmt(s.totalMessagesGenerated)),
        ('Total tokens processed', _fmt(s.totalTokensProcessed)),
        ('Web searches performed', _fmt(s.totalSearchesPerformed)),
        (
          'Web bytes fetched',
          '${(s.totalBytesFetched / 1024).toStringAsFixed(1)} KB',
        ),
      ],
    );
  }

  static String _fmt(int n) {
    // Format with commas: e.g. 1234567 → "1,234,567"
    final chars = n.toString().split('').reversed.toList();
    final result = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) result.add(',');
      result.add(chars[i]);
    }
    return result.reversed.join();
  }
}

// ---------------------------------------------------------------------------
// _SystemInfoSection
// ---------------------------------------------------------------------------

class _SystemInfoSection extends StatelessWidget {
  final HardwareInfo? hardware;

  const _SystemInfoSection({required this.hardware});

  @override
  Widget build(BuildContext context) {
    final hw = hardware;
    final totalRam = ModelRegistry.all.fold<double>(0, (s, m) => s + m.ramGb);
    final platform = Platform.isMacOS ? 'macOS' : 'Windows';

    if (hw == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Detecting hardware…',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return _InfoCard(
      rows: [
        (
          'Models installed',
          '${ModelRegistry.all.length} models · '
              '${totalRam.toStringAsFixed(1)} GB total',
        ),
        (
          'Detected hardware',
          '${hw.totalRamGb.toStringAsFixed(0)} GB RAM  ·  '
              '${hw.backendDisplayName}  ·  '
              '${(hw.standardContextWindow / 1024).round()}k ctx',
        ),
        ('Platform', platform),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _InfoCard — generic key/value card
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: AppColors.border),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _IbmHistorySection — timeline of IBM AI milestones
// ---------------------------------------------------------------------------

class _IbmHistorySection extends StatelessWidget {
  static const _events = [
    (
      year: '1956',
      title: 'The Birth of AI',
      body: 'The Dartmouth Conference. IBM researchers in the room. '
          'A bet that machines could reason. It took 70 years, but here we are.',
    ),
    (
      year: '1981',
      title: 'IBM PC — computing comes home',
      body: 'The open platform that made personal computing real — and set the '
          'stage for the idea that powerful software should live on your desk, '
          'not in a data center.',
    ),
    (
      year: '1985',
      title: 'Deep Thought',
      body: "IBM's research group builds a chess computer that evaluates "
          "700,000 positions per second. Named after the computer in "
          "The Hitchhiker's Guide to the Galaxy that spent 7.5 million years "
          "computing the answer to Life, the Universe, and Everything. "
          "(It was 42.)",
    ),
    (
      year: '1989',
      title: 'Deep Thought II',
      body: 'Beats every grandmaster except Kasparov. A machine that thinks '
          'about thinking. Sound familiar?',
    ),
    (
      year: '1997',
      title: 'Deep Blue defeats Kasparov',
      body: 'Game 6. Brønstein Variation of the Caro-Kann Defense. '
          'Move 19: Bd6. Kasparov resigns. For the first time, a machine '
          'beats the reigning world chess champion in a match. '
          'The world watches and wonders: what comes next?',
    ),
    (
      year: '2011',
      title: 'Watson wins Jeopardy!',
      body: 'Not chess moves — language. Context. Puns. Ken Jennings wrote: '
          '"I, for one, welcome our new computer overlords." '
          "IBM's Watson didn't just process — it understood well enough "
          'to win \$1 million on national television.',
    ),
    (
      year: '2026',
      title: 'deepThinkER',
      body: 'Four language models, running in parallel, on your machine, '
          'debating each other — now with controlled internet access, a '
          'trust system, and extensible tool calls.\n\n'
          'Deep Blue would approve.',
    ),
  ];

  const _IbmHistorySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _events.asMap().entries.map((e) {
        final isLast = e.key == _events.length - 1;
        return _TimelineEntry(
          event: e.value,
          isLast: isLast,
          highlight: isLast,
        );
      }).toList(),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ({String year, String title, String body}) event;
  final bool isLast;
  final bool highlight;

  const _TimelineEntry({
    required this.event,
    required this.isLast,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor =
        highlight ? AppColors.accent : AppColors.textSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline spine ──────────────────────────────────────────────
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  event.year,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dotColor,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.border,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Content card ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlight
                      ? AppColors.accent.withValues(alpha: 0.07)
                      : AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: highlight
                        ? AppColors.accent.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: highlight
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
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
// _CreditsSection
// ---------------------------------------------------------------------------

class _CreditsSection extends StatelessWidget {
  const _CreditsSection();

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _CreditRow(
            label: 'Vision & direction',
            value: 'Daneyand',
            onTap: () => _launch('mailto:daneyand@ibm.com'),
            linkStyle: true,
          ),
          const _HDivider(),
          const _CreditRow(
            label: 'Architecture & engineering',
            value: "IBM's Bob",
          ),
          const _HDivider(),
          _CreditRow(
            label: 'Ollama runtime',
            value: 'ollama.com',
            onTap: () => _launch('https://ollama.com'),
            linkStyle: true,
          ),
          const _HDivider(),
          _CreditRow(
            label: 'Source code',
            value: 'github.com/007Style/deepThinkER',
            onTap: () => _launch('https://github.com/007Style/deepThinkER'),
            linkStyle: true,
          ),
          const _HDivider(),
          _CreditRow(
            label: 'Mistral 7B',
            value: 'mistral.ai',
            onTap: () => _launch('https://mistral.ai'),
            linkStyle: true,
          ),
          const _HDivider(),
          _CreditRow(
            label: 'Llama 3 8B',
            value: 'Meta AI',
            onTap: () => _launch('https://ai.meta.com'),
            linkStyle: true,
          ),
          const _HDivider(),
          _CreditRow(
            label: 'Gemma 2 9B',
            value: 'Google DeepMind',
            onTap: () => _launch('https://deepmind.google'),
            linkStyle: true,
          ),
          const _HDivider(),
          _CreditRow(
            label: 'Phi-3 14B',
            value: 'Microsoft Research',
            onTap: () => _launch('https://research.microsoft.com'),
            linkStyle: true,
          ),
          const _HDivider(),
          const _CreditRow(
            label: 'AI heritage',
            value: 'IBM Research — 70 years of asking\n"what if machines could think?"',
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool linkStyle;

  const _CreditRow({
    required this.label,
    required this.value,
    this.onTap,
    this.linkStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      value,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: linkStyle ? AppColors.accent : AppColors.textPrimary,
        decoration: linkStyle ? TextDecoration.underline : null,
        decorationColor: AppColors.accent,
        height: 1.4,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: onTap != null
                ? GestureDetector(onTap: onTap, child: valueWidget)
                : valueWidget,
          ),
        ],
      ),
    );
  }
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.border);
}

// ---------------------------------------------------------------------------
// _QuoteSection — Dijkstra quote + version footer
// ---------------------------------------------------------------------------

class _QuoteSection extends StatelessWidget {
  const _QuoteSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            '"The question of whether a machine can think is about as\n'
            'interesting as the question of whether a submarine can swim."',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textPrimary,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '— Edsger W. Dijkstra',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(
                  const ClipboardData(text: 'deepThinkER v1.0.0'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Version copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              "deepThinkER v1.0.0  ·  © 2026 Daneyand & IBM's Bob",
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
