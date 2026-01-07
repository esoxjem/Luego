import OSLog

final class Logger: Sendable {
    private let osLogger: os.Logger

    init(category: String) {
        self.osLogger = os.Logger(subsystem: "com.esoxjem.Luego", category: category)
    }

    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
    }
}

extension Logger {
    static let sdk = Logger(category: "SDK")
    static let api = Logger(category: "API")
    static let parser = Logger(category: "Parser")
    static let content = Logger(category: "Content")
    static let cache = Logger(category: "Cache")
    static let article = Logger(category: "Article")
    static let sharing = Logger(category: "Sharing")
}
