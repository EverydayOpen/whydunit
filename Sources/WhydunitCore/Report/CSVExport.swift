import Foundation

/// "Export List" for a finding's items. RFC 4180: CRLF line ends, fields with , " CR or LF are quoted, and so is a
/// field that would start a formula, after a leading '.
public enum CSVExport {
    public static func render(_ items: [ItemRecord]) -> String {
        let iso = ISO8601DateFormatter()
        let header = ["Name", "Folder", "Size bytes", "Status", "Modified ISO8601", "Path"]
        let rows = items.map { item in
            [item.name, item.displayFolder, item.logicalSize.map { "\($0)" } ?? "",
             ICloudClassifier.status(of: item).label, item.modified.map { iso.string(from: $0) } ?? "", item.path]
        }
        return ([header] + rows).map { $0.map(field).joined(separator: ",") + "\r\n" }.joined()
    }

    static func field(_ value: String) -> String {
        // A leading = + - @ tab or CR makes a spreadsheet run the field as a formula, and iCloud Drive names aren't
        // always the user's own (shared folders, downloads). A leading ' neutralises it (OWASP CSV injection).
        let formula = value.unicodeScalars.first.map { "=+-@\t\r".unicodeScalars.contains($0) } ?? false
        let value = formula ? "'" + value : value
        // Unicode scalars, because "\r\n" is one Character and would slip past a Character check.
        guard formula || value.unicodeScalars.contains(where: { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
