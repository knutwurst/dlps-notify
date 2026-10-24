import Foundation

public enum GameEvent: Equatable, Sendable {
    case new(GamePost)
    case updated(GamePost)

    public var post: GamePost {
        switch self {
        case .new(let post): return post
        case .updated(let post): return post
        }
    }

    public var isNew: Bool {
        if case .new = self { return true }
        return false
    }
}

// lastModified: high-water mark for the next poll
// seen: post id -> last modified I already handled
public struct DetectorState: Codable, Equatable, Sendable {
    public var lastModified: String
    public var seen: [String: String]

    public init(lastModified: String = "", seen: [String: String] = [:]) {
        self.lastModified = lastModified
        self.seen = seen
    }
}

public enum ChangeDetector {
    // modified within this window of date = new game, later = update
    public static let newGameThreshold: TimeInterval = 24 * 60 * 60

    // unparseable timestamps -> just call it new
    public static func classifyFirstSeen(_ post: GamePost) -> GameEvent {
        guard let published = DLPSDate.parse(post.date),
              let modified = DLPSDate.parse(post.modified) else {
            return .new(post)
        }
        return modified.timeIntervalSince(published) > newGameThreshold
            ? .updated(post)
            : .new(post)
    }

    // seeding = first run: fill the state but stay quiet. nobody wants 300 notifications at once.
    public static func detect(state: DetectorState,
                              fetched: [GamePost],
                              seeding: Bool = false) -> (events: [GameEvent], state: DetectorState) {
        var newState = state
        var events: [GameEvent] = []

        // oldest first
        let ordered = fetched.sorted { $0.modified < $1.modified }

        for post in ordered {
            let key = String(post.id)
            var event: GameEvent?

            if let previousModified = newState.seen[key] {
                if post.modified > previousModified {
                    event = .updated(post)
                }
                // seen that exact change already
            } else {
                event = classifyFirstSeen(post)
            }

            if let event {
                newState.seen[key] = post.modified
                if !seeding { events.append(event) }
            }

            if post.modified > newState.lastModified {
                newState.lastModified = post.modified
            }
        }

        return (events, newState)
    }
}
