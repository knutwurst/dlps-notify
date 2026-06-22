import Foundation

public struct APIError: Error, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

/// Talks to the DLPS WordPress REST API.
///
/// Cloudflare returns 403 to clients without a browser-like User-Agent, so we
/// always send one. The `/wp-json/wp/v2/posts` endpoint itself needs no auth.
public final class APIClient {
    /// A realistic desktop-Chrome UA — verified to pass Cloudflare where the
    /// default URLSession UA gets a 403.
    public static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    public static let fields = "id,date,modified,link,title,categories"

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://dlpsgame.com")!,
                session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 30
            config.httpAdditionalHeaders = [
                "User-Agent": APIClient.userAgent,
                "Accept": "application/json",
                "Accept-Language": "en-US,en;q=0.9,de;q=0.8",
            ]
            self.session = URLSession(configuration: config)
        }
    }

    /// Most recently modified posts — used to seed state on first run.
    public func fetchLatest(perPage: Int = 50) async throws -> [GamePost] {
        let url = buildURL(page: 1, query: [
            .init(name: "per_page", value: String(perPage)),
            .init(name: "orderby", value: "modified"),
            .init(name: "order", value: "desc"),
            .init(name: "_fields", value: APIClient.fields),
        ])
        return try await fetchPosts(url)
    }

    /// Every post modified strictly after `watermark`, drained across pages in
    /// ascending order so a backlog (e.g. the app was closed for days) is fully
    /// captured rather than truncated. Empty watermark falls back to `fetchLatest`.
    public func fetchChanges(modifiedAfter watermark: String,
                             perPage: Int = 100,
                             maxPages: Int = 50) async throws -> [GamePost] {
        guard !watermark.isEmpty else { return try await fetchLatest(perPage: perPage) }

        var all: [GamePost] = []
        var page = 1
        while page <= maxPages {
            let url = buildURL(page: page, query: [
                .init(name: "per_page", value: String(perPage)),
                .init(name: "orderby", value: "modified"),
                .init(name: "order", value: "asc"),
                .init(name: "modified_after", value: watermark),
                .init(name: "_fields", value: APIClient.fields),
            ])

            let batch: [GamePost]
            do {
                batch = try await fetchPosts(url)
            } catch let error as APIError where error.message.contains("invalid_page") {
                break   // ran past the last available page
            }

            all.append(contentsOf: batch)
            if batch.count < perPage { break }
            page += 1
        }
        return all
    }

    private func buildURL(page: Int, query: [URLQueryItem]) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/wp-json/wp/v2/posts"
        var items = query
        if page > 1 { items.append(.init(name: "page", value: String(page))) }
        components.queryItems = items
        return components.url!
    }

    private func fetchPosts(_ url: URL) async throws -> [GamePost] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw APIError("No HTTP response")
        }
        guard http.statusCode == 200 else {
            if let body = String(data: data, encoding: .utf8),
               body.contains("rest_post_invalid_page_number") {
                throw APIError("invalid_page")
            }
            throw APIError("HTTP \(http.statusCode)")
        }
        do {
            return try JSONDecoder().decode([GamePost].self, from: data)
        } catch {
            throw APIError("Decode failed: \(error.localizedDescription)")
        }
    }
}
