import Foundation

// there's no changelog, so diff the download entries (region + group) between snapshots
public enum UpdateDetails {
    // title code - region (group)(format)
    private static let pattern =
        #"(?:CUSA|PPSA|PCS[A-Z]|BL[EU]S|BC[EU]S|BCAS|NP[A-Z]{2})\d{3,5}\s*[-–—]\s*([A-Z]{2,5}(?:/[A-Z]{2,5})?)\s*((?:\([^)]*\)\s*)*)"#
    private static let regex = try? NSRegularExpression(pattern: pattern)
    private static let codeRegex =
        try? NSRegularExpression(pattern: #"(?:CUSA|PPSA|PCS[A-Z]|BL[EU]S|BC[EU]S|BCAS|NP[A-Z]{2})\d{3,5}"#)
    private static let versionRegex =
        try? NSRegularExpression(pattern: #"[vV](\d+(?:\.\d+)+)"#)

    public static func codes(fromHTML html: String) -> [String] {
        guard let codeRegex else { return [] }
        let text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let ns = text as NSString
        var result: [String] = []
        for match in codeRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let code = ns.substring(with: match.range).uppercased()
            if !result.contains(code) { result.append(code) }
        }
        return result
    }

    public static func versionStrings(fromHTML html: String) -> [String] {
        guard let versionRegex else { return [] }
        let text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let ns = text as NSString
        var result: [String] = []
        for match in versionRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let version = ns.substring(with: match.range(at: 1))
            if !result.contains(version) { result.append(version) }
        }
        return result
    }

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

    // nil if nothing new showed up (re-uploads etc.)
    public static func summarize(old: [String], new: [String]) -> String? {
        let oldSet = Set(old)
        let added = new.filter { !oldSet.contains($0) }
        guard !added.isEmpty else { return nil }
        let shown = added.prefix(3).joined(separator: ", ")
        let more = added.count > 3 ? " +\(added.count - 3)" : ""
        return "+ \(shown)\(more)"
    }
}
