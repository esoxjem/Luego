import Foundation

struct SavedArticleImportFailureSample: Sendable, Equatable {
    let urlString: String
    let message: String
}

struct SavedArticleImportResult: Sendable, Equatable {
    let detectedURLCount: Int
    let uniqueURLCount: Int
    let importedCount: Int
    let skippedExistingCount: Int
    let skippedDuplicateInputCount: Int
    let failedCount: Int
    let failureSamples: [SavedArticleImportFailureSample]

    var didFindURLs: Bool {
        detectedURLCount > 0
    }
}

@MainActor
protocol SavedArticleImportServiceProtocol: Sendable {
    func importArticles(fromPlainText text: String) async -> SavedArticleImportResult
}

@MainActor
final class SavedArticleImportService: SavedArticleImportServiceProtocol {
    private let articleStore: ArticleStoreProtocol
    private let metadataDataSource: MetadataDataSourceProtocol

    init(
        articleStore: ArticleStoreProtocol,
        metadataDataSource: MetadataDataSourceProtocol
    ) {
        self.articleStore = articleStore
        self.metadataDataSource = metadataDataSource
    }

    func importArticles(fromPlainText text: String) async -> SavedArticleImportResult {
        let detectedURLs = SharedTextURLExtractor.extractSupportedWebURLs(from: text)
        let deduplicatedInput = deduplicateInputURLs(detectedURLs)
        let baseSavedDate = Date()

        var skippedDuplicateInputCount = detectedURLs.count - deduplicatedInput.count
        var skippedExistingCount = 0
        var importedCount = 0
        var failedCount = 0
        var failureSamples: [SavedArticleImportFailureSample] = []
        var validatedSeen: Set<String> = []

        for (index, inputURL) in deduplicatedInput.enumerated() {
            do {
                let validatedURL = try await metadataDataSource.validateURL(inputURL)

                if !validatedSeen.insert(validatedURL.absoluteString).inserted {
                    skippedDuplicateInputCount += 1
                    continue
                }

                if try articleStore.fetchArticle(url: validatedURL) != nil {
                    skippedExistingCount += 1
                    continue
                }

                let metadata = try await metadataDataSource.fetchMetadata(for: validatedURL)
                let article = Article(
                    id: UUID(),
                    url: validatedURL,
                    title: metadata.title,
                    content: nil,
                    savedDate: baseSavedDate.addingTimeInterval(-Double(index)),
                    thumbnailURL: metadata.thumbnailURL,
                    publishedDate: metadata.publishedDate,
                    readPosition: 0
                )

                do {
                    _ = try articleStore.saveArticle(article)
                    importedCount += 1
                } catch {
                    if try articleStore.fetchArticle(url: validatedURL) != nil {
                        skippedExistingCount += 1
                    } else {
                        failedCount += 1
                        appendFailure(
                            urlString: validatedURL.absoluteString,
                            message: error.localizedDescription,
                            to: &failureSamples
                        )
                    }
                }
            } catch {
                failedCount += 1
                appendFailure(
                    urlString: inputURL.absoluteString,
                    message: error.localizedDescription,
                    to: &failureSamples
                )
            }
        }

        let uniqueURLCount = max(0, detectedURLs.count - skippedDuplicateInputCount)

        return SavedArticleImportResult(
            detectedURLCount: detectedURLs.count,
            uniqueURLCount: uniqueURLCount,
            importedCount: importedCount,
            skippedExistingCount: skippedExistingCount,
            skippedDuplicateInputCount: skippedDuplicateInputCount,
            failedCount: failedCount,
            failureSamples: failureSamples
        )
    }

    private func deduplicateInputURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var deduplicated: [URL] = []

        for url in urls {
            if seen.insert(url.absoluteString).inserted {
                deduplicated.append(url)
            }
        }

        return deduplicated
    }

    private func appendFailure(
        urlString: String,
        message: String,
        to samples: inout [SavedArticleImportFailureSample]
    ) {
        guard samples.count < 5 else {
            return
        }

        samples.append(
            SavedArticleImportFailureSample(
                urlString: urlString,
                message: message
            )
        )
    }
}
