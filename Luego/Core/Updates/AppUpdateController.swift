import Foundation

#if os(macOS)
import Sparkle

@MainActor
final class AppUpdateController {
    private let updaterController: SPUStandardUpdaterController?

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    init() {
        if Self.isRunningTests || Self.isDebugBuild {
            self.updaterController = nil
        } else {
            self.updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
#endif
