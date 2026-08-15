import Foundation

/// One entry from the user's own library file, e.g.
/// `Alan Wake II Deluxe Edition [PPSA02572] [v01.200.007] [PS5]`.
public struct LibraryGame: Equatable, Sendable {
    public let code: String        // uppercased TitleID, e.g. "PPSA02572"
    public let name: String
    public let version: String?    // without the leading "v", e.g. "01.200.007"
    public let platform: String?   // "PS4", "PS5", …

    public init(code: String, name: String, version: String?, platform: String?) {
        self.code = code
        self.name = name
        self.version = version
        self.platform = platform
    }
}

/// Fast lookup over a parsed library, by TitleID (exact) and normalized name (fallback).
public struct LibraryIndex: Sendable {
    public private(set) var byCode: [String: LibraryGame] = [:]
    private var byNamePlatform: [String: LibraryGame] = [:]
    public var count: Int { byCode.count }
    public var isEmpty: Bool { byCode.isEmpty && byNamePlatform.isEmpty }

    public init(games: [LibraryGame]) {
        for game in games {
            byCode[game.code] = game
            let key = LibraryIndex.nameKey(game.name, game.platform)
            if let existing = byNamePlatform[key] {
                // On duplicate name+platform keep the higher version (e.g. two "Valhalla" editions).
                if preferNew(existing: existing, candidate: game) { byNamePlatform[key] = game }
            } else {
                byNamePlatform[key] = game
            }
        }
    }

    private func preferNew(existing: LibraryGame, candidate: LibraryGame) -> Bool {
        switch (existing.version, candidate.version) {
        case (nil, .some): return true
        case (.some(let e), .some(let c)): return VersionCompare.isNewer(c, than: e) == true
        default: return false
        }
    }

    public func game(forCode code: String) -> LibraryGame? { byCode[code.uppercased()] }

    /// Name match requires the same platform — a PS4 title must not match a PS5 post.
    public func game(forName name: String, platform: String?) -> LibraryGame? {
        byNamePlatform[LibraryIndex.nameKey(name, platform)]
    }

    public static func normalize(_ string: String) -> String {
        String(string.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// Combined normalized-name + platform key for platform-aware matching.
    public static func nameKey(_ name: String, _ platform: String?) -> String {
        normalize(name) + "|" + (platform ?? "").uppercased()
    }
}

public enum LibraryParser {
    /// Parse "Name [CODE] [vVERSION] [PLATFORM]" lines (version optional, tokens any order).
    public static func parse(_ text: String) -> [LibraryGame] {
        text.split(whereSeparator: \.isNewline).compactMap { parseLine(String($0)) }
    }

    static func parseLine(_ line: String) -> LibraryGame? {
        guard let firstBracket = line.firstIndex(of: "[") else { return nil }
        let name = line[line.startIndex..<firstBracket].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        var code: String?, version: String?, platform: String?
        for token in bracketTokens(line) {
            if token.range(of: "^[A-Z]{4}[0-9]{4,5}$", options: .regularExpression) != nil {
                code = token.uppercased()
            } else if let first = token.first, first == "v" || first == "V",
                      token.dropFirst().first?.isNumber == true {
                version = String(token.dropFirst())
            } else if token.range(of: "^PS[0-9]$", options: .regularExpression) != nil {
                platform = token.uppercased()
            }
        }
        guard let code else { return nil }
        return LibraryGame(code: code, name: name, version: version, platform: platform)
    }

    private static func bracketTokens(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inside = false
        for ch in line {
            switch ch {
            case "[": inside = true; current = ""
            case "]": if inside { tokens.append(current) }; inside = false
            default: if inside { current.append(ch) }
            }
        }
        return tokens
    }
}

public enum VersionCompare {
    /// Is `a` a newer version than `b`? nil if either can't be parsed as dotted numbers.
    public static func isNewer(_ a: String, than b: String) -> Bool? {
        let x = components(a), y = components(b)
        guard !x.isEmpty, !y.isEmpty else { return nil }
        for i in 0..<max(x.count, y.count) {
            let xi = i < x.count ? x[i] : 0
            let yi = i < y.count ? y[i] : 0
            if xi != yi { return xi > yi }
        }
        return false
    }

    private static func components(_ string: String) -> [Int] {
        let trimmed = string.hasPrefix("v") || string.hasPrefix("V") ? String(string.dropFirst()) : string
        return trimmed.split(separator: ".").compactMap { Int($0) }
    }
}
