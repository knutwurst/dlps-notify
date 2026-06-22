import Foundation

/// Something worth notifying the user about.
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

/// Persisted detection state.
///
/// - `lastModified`: high-water mark; the next poll asks the API for everything
///   `modified_after` this value.
/// - `seen`: maps post id (as string, for JSON) to the last `modified` value we
///   already processed, so a repeated fetch of the same change is not re-notified.
public struct DetectorState: Codable, Equatable, Sendable {
    public var lastModified: String
    public var seen: [String: String]

    public init(lastModified: String = "", seen: [String: String] = [:]) {
        self.lastModified = lastModified
        self.seen = seen
    }
}

/// Pure decision logic: given the current state and a batch of freshly fetched
/// posts, decide which are new games, which are updates, and what the next state
/// should be. No network, no disk, no UI — so it is trivially unit-testable.
public enum ChangeDetector {
    /// A post whose `modified` is within this window of its `date` counts as a
    /// brand-new game; a larger gap means an update to an existing game.
    public static let newGameThreshold: TimeInterval = 24 * 60 * 60

    /// Classify a post we are seeing for the first time, using only its own
    /// timestamps. Falls back to `.new` when timestamps can't be parsed.
    public static func classifyFirstSeen(_ post: GamePost) -> GameEvent {
        guard let published = DLPSDate.parse(post.date),
              let modified = DLPSDate.parse(post.modified) else {
            return .new(post)
        }
        return modified.timeIntervalSince(published) > newGameThreshold
            ? .updated(post)
            : .new(post)
    }

    /// - Parameters:
    ///   - state: current persisted state.
    ///   - fetched: posts returned by the API (any order).
    ///   - seeding: first run — prime the state but emit no events (so the user
    ///     is not flooded with a notification for every existing game).
    /// - Returns: events to notify (chronological, oldest first) and the new state.
    public static func detect(state: DetectorState,
                              fetched: [GamePost],
                              seeding: Bool = false) -> (events: [GameEvent], state: DetectorState) {
        var newState = state
        var events: [GameEvent] = []

        // Oldest change first, so notifications arrive in chronological order.
        let ordered = fetched.sorted { $0.modified < $1.modified }

        for post in ordered {
            let key = String(post.id)
            var event: GameEvent?

            if let previousModified = newState.seen[key] {
                if post.modified > previousModified {
                    event = .updated(post)
                }
                // else: already processed this exact modification — dedup, skip.
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
