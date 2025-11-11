import Foundation

protocol ArticleRepositoryProtocol: Sendable {
    func getAll() async throws -> [Domain.Article]
    func save(_ article: Domain.Article) async throws -> Domain.Article
    func delete(id: UUID) async throws
    func update(_ article: Domain.Article) async throws
    func updateReadPosition(articleId: UUID, position: Double) async throws
}
