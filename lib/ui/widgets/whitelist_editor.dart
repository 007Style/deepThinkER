// WhitelistEditor — add/remove domain entries, toggle whitelist on/off.
import 'package:flutter/material.dart';

import '../../core/network/domain_whitelist.dart';
import 'app_theme.dart';

// ---------------------------------------------------------------------------
// WhitelistEditor
// ---------------------------------------------------------------------------

/// Editable domain whitelist widget. Can be embedded in a settings screen.
///
/// Shows current allowed domains with delete buttons, a text field to add
/// new domains, and an enable/disable indicator.
class WhitelistEditor extends StatefulWidget {
  const WhitelistEditor({super.key});

  @override
  State<WhitelistEditor> createState() => _WhitelistEditorState();
}

class _WhitelistEditorState extends State<WhitelistEditor> {
  final _ctrl = TextEditingController();
  List<String> _domains = [];

  @override
  void initState() {
    super.initState();
    _domains = List<String>.from(DomainWhitelist.instance.allowedDomains);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final raw = _ctrl.text.trim().toLowerCase();
    if (raw.isEmpty) return;
    // Strip protocol if present.
    final clean = raw.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    if (_domains.contains(clean)) {
      _ctrl.clear();
      return;
    }
    setState(() => _domains.add(clean));
    _ctrl.clear();
    DomainWhitelist.instance.allowedDomains = List.from(_domains);
    await DomainWhitelist.instance.save();
  }

  Future<void> _remove(String domain) async {
    setState(() => _domains.remove(domain));
    DomainWhitelist.instance.allowedDomains = List.from(_domains);
    await DomainWhitelist.instance.save();
  }

  @override
  Widget build(BuildContext context) {
    final active = _domains.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with status indicator
        Row(
          children: [
            const Text(
              'Domain Whitelist',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF00C853).withValues(alpha: 0.15)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                active ? 'Active (${_domains.length} domains)' : 'Disabled',
                style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? const Color(0xFF00C853)
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Info text
        const Text(
          'When enabled, FETCH calls are blocked unless the domain is listed below. '
          'SEARCH always works. Leave empty to allow all domains.',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        // Domain list
        if (_domains.isNotEmpty)
          ...(_domains.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _remove(d),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 14,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ))),
        const SizedBox(height: 4),
        // Add domain row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. en.wikipedia.org',
                  hintStyle: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _add,
              child: const Text(
                'Add Domain',
                style: TextStyle(
                    fontSize: 11, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
