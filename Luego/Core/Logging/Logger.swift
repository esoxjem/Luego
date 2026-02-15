import OSLog

final class Logger: Sendable {
    private let osLogger: os.Logger
    private let category: String

    init(category: String) {
        self.category = category
        self.osLogger = os.Logger(subsystem: "com.esoxjem.Luego", category: category)
    }

    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
        #if os(macOS)
        stream(message, level: .debug)
        #endif
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
        #if os(macOS)
        stream(message, level: .info)
        #endif
    }

    func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
        #if os(macOS)
        stream(message, level: .warning)
        #endif
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
        #if os(macOS)
        stream(message, level: .error)
        #endif
    }

    #if os(macOS)
    private func stream(_ message: String, level: LogLevel) {
        let cat = category
        Task { @MainActor in
            LogStream.shared.append(
                LogEntry(timestamp: Date(), category: cat, level: level, message: message)
            )
        }
    }
    #endif
}

extension Logger {
    static let sdk = Logger(category: "SDK")
    static let api = Logger(category: "API")
    static let parser = Logger(category: "Parser")
    static let content = Logger(category: "Content")
    static let cache = Logger(category: "Cache")
    static let article = Logger(category: "Article")
    static let sharing = Logger(category: "Sharing")
    static let cloudKit = Logger(category: "CloudKit")
    static let reader = Logger(category: "Reader")
}
