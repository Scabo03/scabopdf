// Unified diagnostic logging channel for ScaboPDF.
//
// One emission primitive (Apple `os.Logger`, subsystem "com.scabo.scabopdf",
// already fixed by the architecture contract in docs/ARCHITECTURE.md), two
// privacy regimes:
//
//   - `event(...)`  — content-free structured metrics + errors. Emitted in BOTH
//     production and test mode at `.notice`/`.error`, which os_log PERSISTS, so
//     they surface on a real device through Console.app and Settings → Privacy &
//     Security → Analytics & Improvements, and on the Simulator through
//     `xcrun simctl spawn booted log stream`. Per the contract, these carry NO
//     document content — counts, sizes, durations, error kinds, and (allowed)
//     filenames only.
//
//   - `snapshot(...)` — heavy JSON (node/role tree, raw extraction) that MAY
//     contain document text. A NO-OP unless test mode is on, and even then it is
//     written to a FILE under Caches (not to os_log, which truncates large
//     messages); only a content-free `snapshot_written` event hits the stream.
//     Test mode runs only on the Simulator against gitignored, copyright fixtures.
//
// Test mode is requested by the XCUITest harness via the `--scabo-test-mode`
// launch argument and read once here. The `NativeDiagnostics` TurboModule
// re-exports `isTestMode` to JavaScript so the TypeScript pipeline gates its own
// snapshots and the whole chain (Swift extraction + TS plugin/layout) lands on
// one channel.

import Foundation
import os

/// Stable category vocabulary. Kept in sync with the JS side (`diag.ts`).
@objc public enum ScaboLogCategory: Int, CaseIterable {
  case pdfExtraction
  case plugin
  case rendering
  case navigation
  case error
  case lifecycle
  case test

  var rawName: String {
    switch self {
    case .pdfExtraction: return "pdf-extraction"
    case .plugin: return "plugin"
    case .rendering: return "rendering"
    case .navigation: return "navigation"
    case .error: return "error"
    case .lifecycle: return "lifecycle"
    case .test: return "test"
    }
  }

  static func from(name: String) -> ScaboLogCategory {
    ScaboLogCategory.allCases.first { $0.rawName == name } ?? .lifecycle
  }
}

@objc public final class ScaboLog: NSObject {

  /// The architecture-fixed subsystem. Console.app and the Analytics pipeline
  /// filter on this string.
  @objc public static let subsystem = "com.scabo.scabopdf"

  /// Verbose, content-bearing snapshots are enabled only when the harness asks
  /// for them. Read once at process start; never true in a shipped build unless
  /// someone passes the flag, which the App Store binary never does.
  @objc public static let isTestMode: Bool =
    ProcessInfo.processInfo.arguments.contains("--scabo-test-mode")

  // One Logger per category, created lazily and cached behind a lock.
  private static let lock = NSLock()
  private static var loggers: [String: Logger] = [:]

  private static func logger(for category: ScaboLogCategory) -> Logger {
    lock.lock()
    defer { lock.unlock() }
    if let existing = loggers[category.rawName] {
      return existing
    }
    let created = Logger(subsystem: subsystem, category: category.rawName)
    loggers[category.rawName] = created
    return created
  }

  // MARK: - Content-free events (Swift call site)

  /// Emit a content-free structured event. `name` is a short, stable event
  /// identifier; `metadata` is a flat map of scalars (counts, sizes, ms, error
  /// kinds, filenames). NEVER pass document text here — the dynamic parts are
  /// logged `.public` precisely because they must be content-free.
  public static func event(_ category: ScaboLogCategory,
                           _ name: String,
                           _ metadata: [String: Any] = [:],
                           level: OSLogType = .default) {
    emit(categoryName: category.rawName,
         levelName: levelName(for: level),
         name: name,
         metadataJSON: jsonString(metadata))
  }

  /// Convenience for the error category at `.error` level (persisted).
  public static func error(_ name: String, _ metadata: [String: Any] = [:]) {
    event(.error, name, metadata, level: .error)
  }

  // MARK: - ObjC / bridge entry points

  /// Bridge entry point used by the `NativeDiagnostics` TurboModule. Strings
  /// keep the ObjC surface simple; `metadataJSON` is already-serialised,
  /// content-free JSON produced on the JS side.
  @objc public static func emit(categoryName: String,
                                levelName: String,
                                name: String,
                                metadataJSON: String) {
    let category = ScaboLogCategory.from(name: categoryName)
    let level = osLogType(for: levelName)
    let log = logger(for: category)
    let payload = metadataJSON.isEmpty ? "{}" : metadataJSON
    log.log(level: level, "\(name, privacy: .public) \(payload, privacy: .public)")
  }

  /// Test-mode-only heavy snapshot. Writes `json` to a file under Caches and
  /// emits a content-free `snapshot_written` event so the stream records that a
  /// snapshot happened without carrying its (possibly copyright) content. A
  /// no-op outside test mode.
  @objc public static func snapshot(categoryName: String,
                                    name: String,
                                    json: String) {
    guard isTestMode else { return }
    let bytes = json.utf8.count
    if let url = writeSnapshotFile(name: name, json: json) {
      event(.test, "snapshot_written",
            ["name": name, "category": categoryName, "bytes": bytes,
             "path": url.lastPathComponent],
            level: .default)
    } else {
      event(.error, "snapshot_write_failed",
            ["name": name, "category": categoryName, "bytes": bytes],
            level: .error)
    }
  }

  // MARK: - Snapshot file storage

  /// Directory under Caches where test-mode snapshots are written. The host
  /// harness collects them via `simctl get_app_container <udid> <bundle> data`.
  @objc public static func snapshotDirectoryPath() -> String? {
    snapshotDirectoryURL()?.path
  }

  private static func snapshotDirectoryURL() -> URL? {
    guard let caches = FileManager.default.urls(for: .cachesDirectory,
                                                in: .userDomainMask).first else {
      return nil
    }
    let dir = caches.appendingPathComponent("scabo-diagnostics", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir,
                                               withIntermediateDirectories: true)
    }
    return dir
  }

  private static func writeSnapshotFile(name: String, json: String) -> URL? {
    guard let dir = snapshotDirectoryURL() else { return nil }
    let safe = name.replacingOccurrences(of: "/", with: "_")
                   .replacingOccurrences(of: " ", with: "_")
    let url = dir.appendingPathComponent("\(safe).json")
    do {
      try json.data(using: .utf8)?.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
  }

  // MARK: - Helpers

  private static func jsonString(_ metadata: [String: Any]) -> String {
    guard !metadata.isEmpty,
          JSONSerialization.isValidJSONObject(metadata),
          let data = try? JSONSerialization.data(withJSONObject: metadata,
                                                 options: [.sortedKeys]),
          let json = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return json
  }

  private static func osLogType(for levelName: String) -> OSLogType {
    switch levelName.lowercased() {
    case "debug": return .debug
    case "info": return .info
    case "notice", "default": return .default
    case "error": return .error
    case "fault": return .fault
    default: return .default
    }
  }

  private static func levelName(for level: OSLogType) -> String {
    switch level {
    case .debug: return "debug"
    case .info: return "info"
    case .error: return "error"
    case .fault: return "fault"
    default: return "default"
    }
  }
}
