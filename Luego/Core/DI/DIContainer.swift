import Foundation
import SwiftData

@MainActor
final class DIContainer {
    static let shared = DIContainer()

    private init() {}
}
