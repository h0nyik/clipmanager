import Foundation
import OSLog

// MARK: - Log
// Unified Logging (Console.app → filter "io.clipmanager.app").
// Never log clipboard contents — only types, sizes and counts.

enum Log {
    static let subsystem = "io.clipmanager.app"

    static let app       = Logger(subsystem: subsystem, category: "app")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let paste     = Logger(subsystem: subsystem, category: "paste")
    static let store     = Logger(subsystem: subsystem, category: "store")
    static let hotkey    = Logger(subsystem: subsystem, category: "hotkey")
    static let update    = Logger(subsystem: subsystem, category: "update")
    static let settings  = Logger(subsystem: subsystem, category: "settings")

    /// Collects this process's log entries (since launch) as text for a bug report.
    static func exportDiagnostics() throws -> String {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries(matching: NSPredicate(format: "subsystem == %@", subsystem))

        let formatter = ISO8601DateFormatter()
        let info = Bundle.main.infoDictionary
        var lines = [
            "ClipManager \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "",
        ]
        for case let entry as OSLogEntryLog in entries {
            lines.append("\(formatter.string(from: entry.date)) [\(entry.category)] \(entry.composedMessage)")
        }
        return lines.joined(separator: "\n")
    }
}
