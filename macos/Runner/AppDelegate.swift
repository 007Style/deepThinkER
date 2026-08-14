import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Called by macOS before the app process exits — guaranteed for ⌘Q,
  /// Dock → Quit, and window close (because shouldTerminateAfterLastWindowClosed = true).
  ///
  /// We kill the Ollama child process **and its entire process group** so
  /// that every `llama-server` child spawned by Ollama is also terminated.
  override func applicationWillTerminate(_ notification: Notification) {
    killOllamaIfRunning()
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private func pidFilePath() -> String {
    // Must match OllamaLauncher._pidFilePath in Dart:
    //   (TMPDIR env var stripped of trailing slash) + "/deepthink_ollama.pid"
    var tmp = NSTemporaryDirectory()
    if tmp.hasSuffix("/") {
      tmp = String(tmp.dropLast())
    }
    return "\(tmp)/deepthink_ollama.pid"
  }

  private func killOllamaIfRunning() {
    let path = pidFilePath()
    guard
      let contents = try? String(contentsOfFile: path, encoding: .utf8),
      let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)),
      pid > 0
    else { return }

    // Kill the entire process group so that every llama-server child that
    // Ollama spawns is also SIGKILL'd.  killpg(pgid, sig) sends the signal
    // to every process whose process group ID equals pgid.
    killpg(pid_t(pid), SIGKILL)

    // Belt-and-suspenders: sweep any llama-server orphans whose pgid may
    // have changed (e.g. double-forked children).
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
    task.arguments = ["-9", "-f", "llama-server"]
    try? task.run()
    // We do not wait — this fires async; the app is already exiting.

    // Remove the PID file so a subsequent launch doesn't try to kill a
    // recycled PID.
    try? FileManager.default.removeItem(atPath: path)
  }
}
