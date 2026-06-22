import Foundation

/// Parses the API's timestamp format (`yyyy-MM-dd'T'HH:mm:ss`, no timezone).
///
/// `date` and `modified` are both in the site's local zone, so a fixed parser
/// produces correct *differences* between them even though the absolute zone is
/// assumed. Watermark comparisons elsewhere use plain string ordering, which is
/// valid because the format is fixed-width.
public enum DLPSDate {
    public static func parse(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: string)
    }

    /// Formats a `Date` back into the API's timestamp format (used for watermarks).
    public static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }
}
