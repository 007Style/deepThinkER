// Help menu widget for deepThink.
//
// Adds a "?" icon button in the top bar. Tapping it shows a popup menu:
//   • User Guide          → DocsScreen (tab 0)
//   • Architecture        → DocsScreen (tab 1)
//   • Development Guide   → DocsScreen (tab 2)
//   • Model Downloads     → ModelHelpScreen
//   • About deepThink     → AboutScreen
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/ollama/hardware_detector.dart';
import '../../core/session/session_manager.dart';
import '../widgets/app_theme.dart';
import '../screens/about_screen.dart';
import '../screens/docs_screen.dart';
import '../screens/memory_panel_screen.dart';
import '../screens/model_help_screen.dart';

// ---------------------------------------------------------------------------
// HelpMenuButton
// ---------------------------------------------------------------------------

/// A small "?" icon button that pops up the Help menu.
///
/// Designed to be placed at the trailing end of a top-bar [Row].
/// Pass [hardware] if it has already been detected so the About screen
/// does not need to re-detect it.
class HelpMenuButton extends StatelessWidget {
  /// Pre-detected hardware info.  May be null; About screen will detect it.
  final HardwareInfo? hardware;

  const HelpMenuButton({this.hardware, super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HelpItem>(
      tooltip: 'Help',
      icon: const Icon(
        Icons.help_outline,
        size: 18,
        color: AppColors.textSecondary,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      offset: const Offset(0, 36),
      itemBuilder: (_) => [
        _menuItem(
          value: _HelpItem.userGuide,
          icon: Icons.menu_book_rounded,
          label: 'User Guide',
        ),
        _menuItem(
          value: _HelpItem.architecture,
          icon: Icons.account_tree_outlined,
          label: 'Architecture',
        ),
        _menuItem(
          value: _HelpItem.development,
          icon: Icons.code_rounded,
          label: 'Development Guide',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: _HelpItem.modelInstall,
          icon: Icons.download_outlined,
          label: 'Model Downloads & Installation',
        ),
        _menuItem(
          value: _HelpItem.transcripts,
          icon: Icons.history_rounded,
          label: 'Session Transcripts',
        ),
        _menuItem(
          value: _HelpItem.memories,
          icon: Icons.psychology_outlined,
          label: 'Character Memories',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: _HelpItem.about,
          icon: Icons.info_outline,
          label: 'About deepThink',
        ),
      ],
      onSelected: (item) => _onSelected(context, item),
    );
  }

  PopupMenuItem<_HelpItem> _menuItem({
    required _HelpItem value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<_HelpItem>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _onSelected(BuildContext context, _HelpItem item) {
    switch (item) {
      case _HelpItem.userGuide:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DocsScreen(initialTab: 0),
        ));
      case _HelpItem.architecture:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DocsScreen(initialTab: 1),
        ));
      case _HelpItem.development:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const DocsScreen(initialTab: 2),
        ));
      case _HelpItem.modelInstall:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const ModelHelpScreen(),
        ));
      case _HelpItem.transcripts:
        _openTranscriptsFolder(context);
      case _HelpItem.memories:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const MemoryPanelScreen(),
        ));
      case _HelpItem.about:
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => AboutScreen(hardware: hardware),
        ));
    }
  }
  Future<void> _openTranscriptsFolder(BuildContext context) async {
    final dir = SessionManager.sessionsDir();
    // Ensure the directory exists so Finder doesn't error.
    await Directory(dir).create(recursive: true);
    if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    }
  }
}

// ---------------------------------------------------------------------------
// _HelpItem
// ---------------------------------------------------------------------------

enum _HelpItem {
  userGuide,
  architecture,
  development,
  modelInstall,
  transcripts,
  memories,
  about,
}
