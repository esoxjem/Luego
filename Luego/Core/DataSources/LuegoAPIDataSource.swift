import Foundation

protocol LuegoAPIDataSourceProtocol: Sendable {
    func fetchArticle(for url: URL) async throws -> LuegoAPIResponse
}

final class LuegoAPIDataSource: LuegoAPIDataSourceProtocol, Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let timeout: TimeInterval

    init(
        baseURL: URL = AppConfiguration.luegoAPIBaseURL,
        apiKey: String = AppConfiguration.luegoAPIKey,
        timeout: TimeInterval = AppConfiguration.luegoAPITimeout
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.timeout = timeout
    }

    func fetchArticle(for url: URL) async throws -> LuegoAPIResponse {
        let endpoint = baseURL.appendingPathComponent("api/luego/parse")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = timeout

        let body = ["url": url.absoluteString]
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("[LuegoAPI] Fetching: \(url.absoluteString)")
        #endif

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("[LuegoAPI] Network error: \(error.localizedDescription)")
            #endif
            throw LuegoAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LuegoAPIError.networkError(URLError(.badServerResponse))
        }

        #if DEBUG
        print("[LuegoAPI] Status: \(httpResponse.statusCode)")
        #endif

        switch httpResponse.statusCode {
        case 200:
            return try decodeResponse(from: data)
        case 400:
            throw LuegoAPIError.invalidURL
        case 401:
            throw LuegoAPIError.unauthorized
        case 422:
            let errorMessage = extractErrorMessage(from: data)
            throw LuegoAPIError.serverError(statusCode: 422, message: errorMessage)
        case 429:
            throw LuegoAPIError.serviceUnavailable
        case 500, 502, 503:
            throw LuegoAPIError.serviceUnavailable
        default:
            throw LuegoAPIError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    private func decodeResponse(from data: Data) throws -> LuegoAPIResponse {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(LuegoAPIResponse.self, from: data)
        } catch {
            #if DEBUG
            print("[LuegoAPI] Decoding error: \(error)")
            #endif
            throw LuegoAPIError.decodingError(error)
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let error: String
        }
        return try? JSONDecoder().decode(ErrorResponse.self, from: data).error
    }
}
