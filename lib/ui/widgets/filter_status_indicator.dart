// FilterStatusIndicator — small shield icon showing content filter state.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// FilterStatusIndicator
// ---------------------------------------------------------------------------

/// A small shield [Icon] widget that is grey when the content filter is off
/// and green when it is on.
///
/// ```dart
/// FilterStatusIndicator(isEnabled: settingsProvider.current.contentFilterEnabled)
/// ```
class FilterStatusIndicator extends StatelessWidget {
  /// Whether the content safety filter is currently enabled.
  final bool isEnabled;

  /// Icon size.  Defaults to 18.
  final double size;

  const FilterStatusIndicator({
    super.key,
    required this.isEnabled,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.shield,
      size: size,
      color: isEnabled ? Colors.green : Colors.grey,
      semanticLabel: isEnabled ? 'Content filter enabled' : 'Content filter disabled',
    );
  }
}
