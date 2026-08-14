/// Session lifecycle manager for deepThink.
///
/// Handles session creation, auto-naming, on-disk log writing, session
/// indexing, and cumulative app-stats persistence.
///
/// Log file location:
/// - macOS:   `~/Library/Application Support/deepThinkER/sessions/<name>_<timestamp>.txt`
/// - Windows: `%APPDATA%\deepThinkER\sessions\<name>_<timestamp>.txt`
///
/// This file has zero Flutter imports — pure Dart only.
library session_manager;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../conversation/message.dart';
import '../conversation/participant.dart';
import '../paths/app_paths.dart';
import 'app_stats.dart';
import 'name_generator.dart';
import 'session.dart';

// ---------------------------------------------------------------------------
// SessionManager
// ---------------------------------------------------------------------------

/// Manages the full lifecycle of [Session] objects.
///
/// Typical usage:
/// ```dart
/// final manager = SessionManager();
/// final session = await manager.createSession(participants: Participant.defaults());
/// await manager.startLogging(session, conversationLog.messageStream);
/// // … conversation runs …
/// await manager.endSession(session);
/// ```
class SessionManager {
  final NameGenerator _nameGenerator;

  /// Names of sessions created in the current app run, used to avoid
  /// duplicate auto-generated names within a single process lifetime.
  final Set<String> _usedNames = {};

  /// Creates a [SessionManager].
  ///
  /// Supply a [NameGenerator] for deterministic testing; leave null to use
  /// the default cryptographically seeded generator.
  SessionManager({NameGenerator? nameGenerator})
      : _nameGenerator = nameGenerator ?? NameGenerator();

  // -------------------------------------------------------------------------
  // Directory / path helpers
  // -------------------------------------------------------------------------

  /// Returns the base app-data directory path.
  static String _baseDir() => AppPaths.base;

  /// Returns the `…/sessions/` directory path.
  static String _sessionsDir() => AppPaths.sessions;

  /// Public accessor so the UI can open the sessions directory in Finder.
  static String sessionsDir() => _sessionsDir();

  /// Returns the absolute path to `stats.json`.
  static String _statsPath() => AppPaths.stats;

  /// Returns the absolute path to `sessions/index.json`.
  static String _indexPath() =>
      [_sessionsDir(), 'index.json'].join(Platform.pathSeparator);

  /// Ensures [dirPath] exists, creating it (and any intermediate directories)
  /// if necessary.
  static Future<void> _ensureDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Creates a new [Session].
  ///
  /// If [name] is null or empty an auto-generated lowerCamelCase name is used.
  /// The log file and the sessions directory are created immediately.
  ///
  /// [participants] is a snapshot of the configuration chosen at session-start
  /// time and is embedded in the log file header.
  Future<Session> createSession({
    String? name,
    required List<Participant> participants,
  }) async {
    await _ensureDir(_sessionsDir());

    // Determine the session name.
    final sessionName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : _nameGenerator.generateUnique(_usedNames);
    _usedNames.add(sessionName);

    final now = DateTime.now().toLocal();
    final id = 'session-${now.millisecondsSinceEpoch}';

    // Sanitise name for use as a filename (replace spaces with underscores,
    // strip characters that are illegal on Windows).
    final safeName = sessionName.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_');
    // Use a human-readable datetime suffix so the filename sorts and reads well.
    final dateSuffix = '${now.year}-${_p(now.month)}-${_p(now.day)}'
        '_${_p(now.hour)}-${_p(now.minute)}-${_p(now.second)}';
    final logFileName = '${safeName}_$dateSuffix.txt';
    final logFilePath =
        [_sessionsDir(), logFileName].join(Platform.pathSeparator);

    final session = Session(
      id: id,
      name: sessionName,
      startTime: now,
      participants: participants,
      logFilePath: logFilePath,
      isActive: true,
    );

    // Write the log file header.
    await _writeLogHeader(session);

    return session;
  }

  /// Subscribes to [messageStream] and appends each non-pass [Message] to the
  /// session log file immediately (non-blocking).
  ///
  /// The returned [StreamSubscription] is also stored on [session] so that
  /// [endSession] can cancel it automatically. The caller may ignore the
  /// return value unless they need manual control of the subscription.
  Future<StreamSubscription<Message>> startLogging(
    Session session,
    Stream<Message> messageStream,
  ) async {
    final logFile = File(session.logFilePath);
    final sink = logFile.openWrite(mode: FileMode.append);

    final sub = messageStream.listen(
      (message) {
        // Skip pass messages — they carry no content worth logging.
        if (message.isPass) return;

        // Update session stats.
        session.totalMessages++;
        if (message.isUser) session.totalUserMessages++;

        // Write formatted line immediately (non-blocking IOSink).
        sink.writeln(message.toPlainText());
      },
      // Do NOT close the sink here — endSession owns the sink lifecycle.
      // Closing it twice (once here, once in endSession) can cause a hang.
      onDone: () {},
      onError: (_) {},
      cancelOnError: false,
    );

    // Keep a reference so endSession can flush & close cleanly.
    _logSinks[session.id] = sink;

    return sub;
  }

  // Internal map of open IOSinks keyed by session id.
  final Map<String, IOSink> _logSinks = {};

  /// Marks [session] as ended, flushes the log file, writes a summary footer,
  /// updates the session index, and persists updated [AppStats].
  Future<void> endSession(Session session) async {
    session.endTime = DateTime.now().toUtc();
    session.isActive = false;

    // Flush and close the log sink if it is still open.
    final sink = _logSinks.remove(session.id);
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }

    // Append the summary footer.
    await _writeLogFooter(session);

    // Persist session to index.
    await _appendToIndex(session);

    // Update cumulative stats.
    final stats = await loadStats();
    stats.totalSessionsRun++;
    stats.totalMessagesGenerated += session.totalMessages;
    stats.totalTokensProcessed += session.totalTokens;
    stats.lastSessionDate = session.endTime;
    stats.firstSessionDate ??= session.startTime;
    await saveStats(stats);
  }

  /// Loads all past sessions from `sessions/index.json`.
  ///
  /// Returns an empty list if the index does not exist yet.
  /// [participants] is passed through to [Session.fromJson]; omit it to get
  /// sessions with an empty participants list (fine for display-only use).
  Future<List<Session>> loadPastSessions({
    List<Participant>? participants,
  }) async {
    final indexFile = File(_indexPath());
    if (!await indexFile.exists()) return [];

    try {
      final raw = await indexFile.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Session.fromJson(
                e as Map<String, dynamic>,
                participants: participants,
              ))
          .toList();
    } on FormatException {
      // Corrupted index — return empty rather than crashing.
      return [];
    }
  }

  /// Loads cumulative [AppStats] from `stats.json`.
  ///
  /// Returns [AppStats.empty] if the file does not exist yet.
  Future<AppStats> loadStats() async {
    final statsFile = File(_statsPath());
    if (!await statsFile.exists()) return AppStats.empty();

    try {
      final raw = await statsFile.readAsString();
      return AppStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return AppStats.empty();
    }
  }

  /// Persists [stats] to `stats.json`.
  Future<void> saveStats(AppStats stats) async {
    await _ensureDir(_baseDir());
    final statsFile = File(_statsPath());
    await statsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(stats.toJson()),
    );
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Writes the human-readable header to a newly created log file.
  Future<void> _writeLogHeader(Session session) async {
    final buf = StringBuffer();
    buf.writeln('═' * 60);
    buf.writeln('  deepThinkER Session Log');
    buf.writeln('  Session : ${session.name}');
    buf.writeln('  ID      : ${session.id}');
    buf.writeln('  Started : ${_formatDatetime(session.startTime)}');
    buf.writeln('  Participants:');
    for (final p in session.participants) {
      buf.writeln('    • ${p.name}  (${p.assignedModelId})');
    }
    buf.writeln('═' * 60);
    buf.writeln();
    await File(session.logFilePath)
        .writeAsString(buf.toString(), mode: FileMode.write);
  }

  /// Appends the summary footer when a session ends.
  Future<void> _writeLogFooter(Session session) async {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;
    final buf = StringBuffer();
    buf.writeln();
    buf.writeln('─' * 60);
    buf.writeln('  Session ended : ${_formatDatetime(session.endTime ?? DateTime.now().toUtc())}');
    buf.writeln('  Duration      : ${_formatDuration(duration)}');
    buf.writeln('  Messages      : ${session.totalMessages}');
    buf.writeln('  User messages : ${session.totalUserMessages}');
    buf.writeln('  Tokens        : ${session.totalTokens}');
    buf.writeln('─' * 60);
    await File(session.logFilePath)
        .writeAsString(buf.toString(), mode: FileMode.append);
  }

  /// Appends [session] metadata to `sessions/index.json`.
  Future<void> _appendToIndex(Session session) async {
    await _ensureDir(_sessionsDir());
    final indexFile = File(_indexPath());

    List<dynamic> existing = [];
    if (await indexFile.exists()) {
      try {
        final raw = await indexFile.readAsString();
        existing = jsonDecode(raw) as List<dynamic>;
      } on FormatException {
        existing = [];
      }
    }

    // Remove any prior entry with the same id (e.g. re-saving an active session).
    existing.removeWhere(
      (e) => (e as Map<String, dynamic>)['id'] == session.id,
    );
    existing.add(session.toJson());

    await indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(existing),
    );
  }

  // -------------------------------------------------------------------------
  // Formatting utilities
  // -------------------------------------------------------------------------

  static String _formatDatetime(DateTime dt) {
    final local = dt.toLocal();
    final date =
        '${local.year}-${_p(local.month)}-${_p(local.day)}';
    final time =
        '${_p(local.hour)}:${_p(local.minute)}:${_p(local.second)}';
    return '$date $time';
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${_p(m)}m ${_p(s)}s';
    if (m > 0) return '${m}m ${_p(s)}s';
    return '${s}s';
  }

  /// Zero-pads a single integer to two digits.
  static String _p(int v) => v.toString().padLeft(2, '0');
}
