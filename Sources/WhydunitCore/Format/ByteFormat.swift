import Foundation

/// Finder-style sizes (1000-based) without ByteCountFormatter, so output is identical on every platform and locale.
public enum ByteFormat {
    /// "999 bytes", "12 KB", "1.2 MB", "340 GB"; "At least 1.2 GB" for partial sums; "Unknown" for nil.
    public static func string(_ bytes: Int64?, lowerBound: Bool = false) -> String {
        guard let bytes else { return "Unknown" }
        let text = plain(bytes)
        return lowerBound ? "At least \(text)" : text
    }

    static func plain(_ bytes: Int64) -> String {
        if bytes < 1000 { return bytes == 1 ? "1 byte" : "\(bytes) bytes" }
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1000
        var unit = 0
        while true {
            // KB is always whole; larger units get one decimal below 100 (Finder shows "1.2 MB", "340 GB").
            let tenths = Int((value * 10).rounded())
            let oneDecimal = unit > 0 && tenths < 1000
            let whole = Int(value.rounded())
            if whole >= 1000 && unit < units.count - 1 {
                value /= 1000
                unit += 1
                continue
            }
            if oneDecimal && tenths % 10 != 0 { return "\(tenths / 10).\(tenths % 10) \(units[unit])" }
            return "\(oneDecimal ? tenths / 10 : whole) \(units[unit])"
        }
    }
}
