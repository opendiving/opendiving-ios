import Foundation

struct EmptyResponse: Decodable {}

final class APIClient {
    static let shared = APIClient()

    // Point this at your deployed HTTPS API. The refresh-token cookie your
    // backend sets is `Secure`, so it will silently be dropped over plain
    // HTTP - use an HTTPS-reachable instance, even for local dev.
    private let baseURL = URL(string: "https://your-api-host/api/v1")!

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init() {}

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        contentType: String = "application/json",
        authenticated: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        if authenticated, let token = KeychainHelper.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(statusCode: -1, message: "Invalid response")
        }

        if httpResponse.statusCode == 401, authenticated {
            // Access token expired - try a refresh, then retry once.
            if try await refreshAccessToken() {
                return try await self.request(
                    path: path, method: method, body: body,
                    contentType: contentType, authenticated: authenticated
                )
            }
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?
                .detail.displayMessage ?? "Request failed (\(httpResponse.statusCode))"
            throw APIError(statusCode: httpResponse.statusCode, message: message)
        }

        // Some endpoints (e.g. PATCH) return a simple {"message": "..."} body;
        // callers that don't need a decoded value can request `EmptyResponse`.
        return try decoder.decode(T.self, from: data)
    }

    @discardableResult
    private func refreshAccessToken() async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("refresh"))
        request.httpMethod = "POST"

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let token = try? decoder.decode(AuthToken.self, from: data)
        else {
            KeychainHelper.delete()
            return false
        }

        KeychainHelper.save(token.accessToken)
        return true
    }
}
