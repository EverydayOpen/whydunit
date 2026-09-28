/// How much a finding matters. Ordered: a higher value is worse.
/// `.unknown` and `.info` never change the overall verdict.
public enum Severity: Int, Codable, Comparable, CaseIterable, Sendable {
    case ok, unknown, info, warning, critical

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// Word shown and spoken next to the symbol, so severity never relies on color alone.
    public var word: String {
        switch self {
        case .ok: "OK"
        case .unknown: "Couldn't check"
        case .info: "Note"
        case .warning: "Worth a look"
        case .critical: "Needs attention"
        }
    }
}
