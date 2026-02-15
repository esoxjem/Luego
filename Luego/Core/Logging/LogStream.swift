import Foundation

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let level: LogLevel
    let message: String
}

enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error

    var symbol: String {
        switch self {
        case .debug: "🔍"
        case .info: "ℹ️"
        case .warning: "⚠️"
        case .error: "❌"
        }
    }
}

@Observable
@MainActor
final class LogStream {
    static let shared = LogStream()

    private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    private init() {}

    func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
