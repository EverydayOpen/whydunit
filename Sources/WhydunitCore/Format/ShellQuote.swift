import Foundation

/// POSIX shell quoting for commands the user copies into Terminal. The app never runs them.
public enum ShellQuote {
    /// Wraps in single quotes; an embedded `'` becomes `'\''`.
    public static func quote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
