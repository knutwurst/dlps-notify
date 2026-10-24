import Foundation

extension String {
    // WordPress titles are full of &amp; and &#8217;. good enough for game names.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        var result = self
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&nbsp;": " ", "&hellip;": "…",
            "&ndash;": "–", "&mdash;": "—",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
            "&trade;": "™", "&reg;": "®", "&copy;": "©",
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.replacingNumericHTMLEntities()
    }

    private func replacingNumericHTMLEntities() -> String {
        guard contains("&#") else { return self }

        var output = ""
        output.reserveCapacity(count)
        var index = startIndex
        while index < endIndex {
            if self[index] == "&", let semicolon = range(of: ";", range: index..<endIndex) {
                let token = self[index..<semicolon.lowerBound]   // "&#038" or "&#x1F3AE"
                if token.hasPrefix("&#") {
                    let digits = token.dropFirst(2)
                    let scalarValue: UInt32?
                    if let first = digits.first, first == "x" || first == "X" {
                        scalarValue = UInt32(digits.dropFirst(), radix: 16)
                    } else {
                        scalarValue = UInt32(digits, radix: 10)
                    }
                    if let value = scalarValue, let scalar = Unicode.Scalar(value) {
                        output.unicodeScalars.append(scalar)
                        index = semicolon.upperBound
                        continue
                    }
                }
            }
            output.append(self[index])
            index = self.index(after: index)
        }
        return output
    }
}
