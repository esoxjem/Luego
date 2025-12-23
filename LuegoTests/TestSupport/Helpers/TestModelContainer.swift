import Foundation
import SwiftData
@testable import Luego

@MainActor
func createTestModelContainer() throws -> ModelContainer {
    let schema = Schema([Article.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}
