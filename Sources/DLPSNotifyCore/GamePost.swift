import Foundation

/// A single entry from the DLPS WordPress REST API (`/wp-json/wp/v2/posts`).
///
/// Each "game" on the daily-update page is a WordPress post. We only decode the
/// fields we ask for via `_fields=id,date,modified,link,title,categories`.
public struct GamePost: Decodable, Equatable, Sendable {
    public let id: Int
    /// Publication timestamp, e.g. `2026-06-22T00:56:36` (site-local, no timezone).
    public let date: String
    /// Last-modified timestamp, same format. A value well after `date` means the
    /// game was updated (new version/patch) rather than freshly published.
    public let modified: String
    /// Canonical URL of the game page.
    public let link: String
    public let title: Title
    /// WordPress category ids; used to derive the platform (PS4/PS5/…).
    public let categories: [Int]

    public struct Title: Decodable, Equatable, Sendable {
        public let rendered: String
        public init(rendered: String) { self.rendered = rendered }
    }

    /// Human-readable, HTML-entity-decoded title (WordPress renders `&amp;` etc.).
    public var name: String { title.rendered.decodingHTMLEntities() }

    public var url: URL? { URL(string: link) }

    /// Recognized platforms for this post (may be empty if none match).
    public var platforms: [Platform] { Platforms.platforms(for: categories) }

    public init(id: Int, date: String, modified: String, link: String,
                title: String, categories: [Int] = []) {
        self.id = id
        self.date = date
        self.modified = modified
        self.link = link
        self.title = Title(rendered: title)
        self.categories = categories
    }

    enum CodingKeys: String, CodingKey {
        case id, date, modified, link, title, categories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        modified = try container.decode(String.self, forKey: .modified)
        link = try container.decode(String.self, forKey: .link)
        title = try container.decode(Title.self, forKey: .title)
        // Be tolerant: not every response variant includes categories.
        categories = (try? container.decode([Int].self, forKey: .categories)) ?? []
    }
}
