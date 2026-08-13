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
  /// We kill the Ollama child process synchronously here so it cannot be
  /// left running as an orphan after the app exits.
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

    // SIGKILL — no mercy, we need the GPU memory freed immediately.
    kill(pid, SIGKILL)

    // Remove the PID file so a subsequent launch doesn't try to kill a
    // recycled PID.
    try? FileManager.default.removeItem(atPath: path)
  }
}
