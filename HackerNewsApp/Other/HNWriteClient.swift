import Foundation

struct HNWriteClient {
    let baseURL = URL(string: "https://news.ycombinator.com")!
    let session: URLSession
    let userAgent: String

    init(session: URLSession, userAgent: String = "HackerPillarDebug/1.0") {
        self.session = session
        self.userAgent = userAgent
    }

    func get(path: String, queryItems: [URLQueryItem] = []) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw HNWriteError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HNWriteError.invalidResponse
        }
        return (data, http)
    }

    func post(path: String, body: [String: String]) async throws -> (Data, HTTPURLResponse) {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HNWriteError.invalidResponse
        }
        return (data, http)
    }
}

enum HNWriteError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case notLoggedIn
    case tokenParseFailed(context: String)
    case serverError(status: Int)
    case writeFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .notLoggedIn:
            return "Not logged in"
        case .tokenParseFailed(let context):
            return "Token parsing failed: \(context)"
        case .serverError(let status):
            return "Server error: \(status)"
        case .writeFailed(let reason):
            return "Write failed: \(reason)"
        }
    }
}
