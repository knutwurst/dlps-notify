import Foundation

// one WordPress post = one game. only decodes what _fields asks for.
public struct GamePost: Decodable, Equatable, Sendable {
    public let id: Int
    public let date: String
    // way after date = the game got an update
    public let modified: String
    public let link: String
    public let title: Title
    public let categories: [Int]

    public struct Title: Decodable, Equatable, Sendable {
        public let rendered: String
        public init(rendered: String) { self.rendered = rendered }
    }

    public var name: String { title.rendered.decodingHTMLEntities() }

    public var url: URL? { URL(string: link) }

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
        // some responses come without categories. whatever.
        categories = (try? container.decode([Int].self, forKey: .categories)) ?? []
    }
}
