import Foundation

/// Compact date rendering for the menu's recent list (no timezone conversion —
/// shows the same wall-clock the site uses). Today → just "HH:mm"; same year →
/// "dd.MM. HH:mm"; otherwise "dd.MM.yyyy HH:mm". The history window uses the
/// fuller `DateDisplay.full` instead.
enum RecentDate {
    static func display(_ apiTimestamp: String?, now: Date = Date()) -> String? {
        guard let value = apiTimestamp else { return nil }
        let halves = value.split(separator: "T")
        guard halves.count == 2 else { return nil }
        let date = halves[0].split(separator: "-")   // yyyy, MM, dd
        let time = halves[1].split(separator: ":")    // HH, mm, ss
        guard date.count == 3, time.count >= 2 else { return nil }
        let (yyyy, mm, dd) = (String(date[0]), String(date[1]), String(date[2]))
        let hhmm = "\(time[0]):\(time[1])"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)

        if "\(yyyy)-\(mm)-\(dd)" == today { return hhmm }
        if yyyy == today.prefix(4) { return "\(dd).\(mm). \(hhmm)" }
        return "\(dd).\(mm).\(yyyy) \(hhmm)"
    }
}
