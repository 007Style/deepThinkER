/// FilterConfig — configuration model for the content safety filter.
///
/// This file has zero Flutter imports — pure Dart only.
library filter_config;

// ---------------------------------------------------------------------------
// FilterConfig
// ---------------------------------------------------------------------------

/// Configuration for [ContentFilter].
///
/// Controls which categories are active and allows per-session custom
/// keyword additions on top of the bundled asset word lists.
class FilterConfig {
  /// Master on/off switch.  When `false`, [ContentFilter] is a no-op.
  final bool enabled;

  /// Active category identifiers.
  ///
  /// Recognised values: `'adult'`, `'violence'`, `'hate'`.
  /// Unknown values are silently ignored.
  final List<String> activeCategories;

  /// Additional keywords to scan for, keyed by category name.
  ///
  /// These are merged with the bundled asset lists at filter initialisation.
  final Map<String, List<String>> customKeywords;

  const FilterConfig({
    this.enabled = false,
    this.activeCategories = const ['adult', 'violence', 'hate'],
    this.customKeywords = const {},
  });

  FilterConfig copyWith({
    bool? enabled,
    List<String>? activeCategories,
    Map<String, List<String>>? customKeywords,
  }) {
    return FilterConfig(
      enabled: enabled ?? this.enabled,
      activeCategories: activeCategories ?? this.activeCategories,
      customKeywords: customKeywords ?? this.customKeywords,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'activeCategories': activeCategories,
        'customKeywords': customKeywords,
      };

  factory FilterConfig.fromJson(Map<String, dynamic> json) {
    final custom = <String, List<String>>{};
    final rawCustom = json['customKeywords'] as Map<String, dynamic>?;
    if (rawCustom != null) {
      for (final entry in rawCustom.entries) {
        custom[entry.key] =
            (entry.value as List<dynamic>).cast<String>();
      }
    }
    return FilterConfig(
      enabled: json['enabled'] as bool? ?? false,
      activeCategories:
          (json['activeCategories'] as List<dynamic>?)?.cast<String>() ??
              const ['adult', 'violence', 'hate'],
      customKeywords: custom,
    );
  }
}
