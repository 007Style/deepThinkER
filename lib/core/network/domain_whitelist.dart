/// DomainWhitelist — restricts which URLs can be fetched by [NetworkFetchTool].
///
/// When the whitelist is non-empty, only URLs whose hostname appears in
/// [allowedDomains] can be fetched. An empty list disables the whitelist
/// (all fetches are permitted).
///
/// This file has zero Flutter imports — pure Dart only.
library domain_whitelist;

import 'dart:convert';
import 'dart:io';

import '../paths/app_paths.dart';

// ---------------------------------------------------------------------------
// DomainWhitelist
// ---------------------------------------------------------------------------

/// Per-session configurable domain whitelist for [FETCH:] tool calls.
///
/// Usage:
/// ```dart
/// DomainWhitelist.instance.allowedDomains = ['en.wikipedia.org'];
/// if (!DomainWhitelist.instance.isAllowed(url)) { /* block */ }
/// ```
class DomainWhitelist {
  DomainWhitelist._();

  static final DomainWhitelist instance = DomainWhitelist._();

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  /// Hostnames allowed for fetching. Empty = whitelist disabled.
  List<String> allowedDomains = [];

  /// Whether the whitelist is active (true when allowedDomains is non-empty).
  bool get enabled => allowedDomains.isNotEmpty;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns `true` if [url] is permitted under the current whitelist.
  ///
  /// If [allowedDomains] is empty, always returns `true`.
  bool isAllowed(String url) {
    if (!enabled) return true;
    final hostname = _extractHostname(url);
    if (hostname == null) return false;
    return allowedDomains.any((d) => d == hostname);
  }

  /// Extracts the hostname from a URL string.
  String? _extractHostname(String url) {
    try {
      final uri = Uri.parse(url.contains('://') ? url : 'http://$url');
      return uri.host.isEmpty ? null : uri.host;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the hostname from a URL (public, for error messages).
  String hostnameOf(String url) => _extractHostname(url) ?? url;

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  static String get _filePath => AppPaths.whitelist;

  /// Loads the whitelist from disk. No-op on error (whitelist stays empty).
  Future<void> load() async {
    final file = File(_filePath);
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['allowedDomains'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [];
      allowedDomains = list;
    } catch (_) {}
  }

  /// Saves the current whitelist to disk.
  Future<void> save() async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    final json = jsonEncode({'allowedDomains': allowedDomains});
    await file.writeAsString(json);
  }
}
