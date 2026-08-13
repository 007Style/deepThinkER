// NetworkToggle — per-character network access switch.
//
// Calls TrustManager.setNetworkEnabled on change.
import 'package:flutter/material.dart';

import '../../../core/trust/trust_manager.dart';
import '../app_theme.dart';

// ---------------------------------------------------------------------------
// NetworkToggle
// ---------------------------------------------------------------------------

/// A compact Switch widget that enables/disables network access for a character.
///
/// On change, calls [TrustManager.setNetworkEnabled] which applies the
/// trust score delta and notifies the LLM via a system message.
class NetworkToggle extends StatefulWidget {
  final String characterName;
  final bool initialEnabled;
  final TrustManager trustManager;

  const NetworkToggle({
    required this.characterName,
    required this.initialEnabled,
    required this.trustManager,
    super.key,
  });

  @override
  State<NetworkToggle> createState() => _NetworkToggleState();
}

class _NetworkToggleState extends State<NetworkToggle> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _enabled = value);
    await widget.trustManager.setNetworkEnabled(widget.characterName, value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NET',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _enabled
                ? AppColors.accent.withValues(alpha: 0.85)
                : AppColors.textSecondary.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 32,
          height: 18,
          child: Transform.scale(
            scale: 0.7,
            child: Switch(
              value: _enabled,
              onChanged: _onChanged,
              activeColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
