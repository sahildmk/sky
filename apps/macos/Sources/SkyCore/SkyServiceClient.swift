import Foundation

/// A request to the Sky service that failed.
public enum SkyServiceError: Error, Equatable {
    /// Nothing answered at the service's address, or the answer was not the service's.
    case unreachable
    /// The service answered with an error, such as 404 for a thread that no longer exists.
    case rejected(status: Int, message: String)
}

/// Reads threads from the Sky service's HTTP API, and resolves and reopens them.
public struct SkyServiceClient: Sendable {
    public static let defaultBaseURL = URL(string: "http://127.0.0.1:4747")!

    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = defaultBaseURL) {
        self.baseURL = baseURL
        // The service is on this Mac: anything slower than this means it isn't running properly.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        session = URLSession(configuration: configuration)
    }

    /// The client for the address in `SKY_SERVICE_URL`, or the default one.
    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> SkyServiceClient {
        SkyServiceClient(baseURL: environment["SKY_SERVICE_URL"].flatMap(URL.init(string:)) ?? defaultBaseURL)
    }

    /// Open threads, most recently active first.
    public func openThreads() async throws(SkyServiceError) -> [SkyThread] {
        try await request("threads", query: [URLQueryItem(name: "status", value: "open")])
    }

    public func thread(id: String) async throws(SkyServiceError) -> SkyThreadDetail {
        try await request("threads/\(id)")
    }

    public func setResolved(_ resolved: Bool, threadID: String) async throws(SkyServiceError) -> SkyThread {
        try await request("threads/\(threadID)", method: "PATCH", body: ["resolved": resolved])
    }

    private func request<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: [String: Bool]? = nil
    ) async throws(SkyServiceError) -> T {
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .unreachable
        }
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw .unreachable }
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "HTTP \(status)"
            throw .rejected(status: status, message: message)
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw .unreachable
        }
    }

    private struct ErrorBody: Decodable { var error: String }

    /// Decodes the service's JSON, whose dates are ISO 8601 with milliseconds.
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let withMilliseconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            guard let date = (try? withMilliseconds.parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text)) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(text)"))
            }
            return date
        }
        return decoder
    }()
}
