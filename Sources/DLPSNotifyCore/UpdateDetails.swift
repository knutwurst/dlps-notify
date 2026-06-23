import Foundation

/// Best-effort description of what an update changed.
///
/// The source has no version field or changelog, but each post lists its
/// "download entries" — region + release group / format, e.g.
/// `PPSA01474 – EUR (@DUPLEX)`. By snapshotting these per post and diffing on the
/// next update, we can say what was added ("+ USA (@DUPLEX)"). Returns nil when
/// nothing parseable changed, so callers fall back to a plain "Update".
public enum UpdateDetails {
    // PlayStation title code, then region (USA/EUR/JPN/…) + optional (group)/(format).
    private static let pattern =
        #"(?:CUSA|PPSA|PCS[A-Z]|BL[EU]S|BC[EU]S|BCAS|NP[A-Z]{2})\d{3,5}\s*[-–—]\s*([A-Z]{2,5}(?:/[A-Z]{2,5})?)\s*((?:\([^)]*\)\s*)*)"#
    private static let regex = try? NSRegularExpression(pattern: pattern)

    /// The normalized download entries found in a post's HTML content.
    public static func entries(fromHTML html: String) -> [String] {
        guard let regex else { return [] }
        let text = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .decodingHTMLEntities()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let ns = text as NSString
        var result: [String] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard match.range(at: 1).location != NSNotFound else { continue }
            let region = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            var extras = ""
            if match.range(at: 2).location != NSNotFound {
                extras = ns.substring(with: match.range(at: 2))
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            let entry = extras.isEmpty ? region : "\(region) \(extras)"
            if !entry.isEmpty, !result.contains(entry) { result.append(entry) }
        }
        return result
    }

    /// A short summary of what `new` has that `old` didn't, or nil if nothing was
    /// added (e.g. a re-upload of the same entries, or no parseable entries).
    public static func summarize(old: [String], new: [String]) -> String? {
        let oldSet = Set(old)
        let added = new.filter { !oldSet.contains($0) }
        guard !added.isEmpty else { return nil }
        let shown = added.prefix(3).joined(separator: ", ")
        let more = added.count > 3 ? " +\(added.count - 3)" : ""
        return "+ \(shown)\(more)"
    }
}
