import SwiftUI
import WhydunitCore

/// Spacing in points (UI_SPEC §2.1). `l` is the window and sheet padding.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum Motion {
    /// Opacity-only and shorter when Reduce Motion is on.
    static func standard(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.28)
    }
}

extension Severity {
    /// `.info` is gray, not blue: blue already means "clickable" (accent).
    var color: Color {
        switch self {
        case .ok: .green
        case .unknown, .info: .secondary
        case .warning: .orange
        case .critical: .red
        }
    }

    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }
}

extension FixAction {
    /// Title case, verb first. Back Up, Retry Upload and Restart iCloud Sync open a sheet, so their buttons add "…".
    var actionTitle: String {
        switch self {
        case .backUp: "Back Up"
        case .retryUpload: "Retry Upload"
        case .restartSync: "Restart iCloud Sync"
        case .openICloudSettings: "Open iCloud Settings"
        case .openPrivacySettings: "Open Privacy Settings"
        case .showInFinder: "Show in Finder"
        case .copyCommand: "Copy Command"
        }
    }
}

/// "1 item", "4,213 items".
func itemCount(_ n: Int) -> String { n == 1 ? "1 item" : "\(n.formatted()) items" }
