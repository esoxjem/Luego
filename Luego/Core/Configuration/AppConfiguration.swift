import Foundation

struct AppConfiguration {
    static let defaultTimeout: TimeInterval = 30
    static let minContentLength = 100

    static let luegoAPIBaseURL = URL(string: "https://esoxjem.com")!
    static let luegoAPIKey = Secrets.luegoAPIKey
    static let luegoAPITimeout: TimeInterval = 30

    static let sdkBundleNames = ["linkedom", "readability", "turndown", "parser"]

    static let cloudKitContainerIdentifier = "iCloud.com.esoxjem.Luego"
}
