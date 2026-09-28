import AppKit

@MainActor public enum FinderBridge {
    /// Finder opens one window per folder, so ask first when that is more than a few.
    public static func reveal(_ paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        let windows = Set(urls.map { $0.deletingLastPathComponent().path }).count
        if windows > 5 {
            let alert = NSAlert()
            alert.messageText = "This opens \(windows) Finder windows"
            alert.informativeText = "The selected items are in \(windows) different folders."
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Cancel")
            // A sheet on the window, like the app's other alerts.
            if let window = NSApp.keyWindow {
                alert.beginSheetModal(for: window) { if $0 == .alertFirstButtonReturn { NSWorkspace.shared.activateFileViewerSelecting(urls) } }
            } else if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// System Settings › Apple Account › iCloud.
    public static func openICloudSettings() {
        // VERIFY on 15 and 26: third-party lists (tested on 15.2) give this form, not "…AppleIDSettings*iCloud".
        open("x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?iCloud")
    }

    /// System Settings › Privacy & Security › Files & Folders.
    public static func openPrivacySettings() {
        // VERIFY on 26: the legacy pane id still resolves; newer lists also show
        // "com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders".
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")
    }

    private static func open(_ link: String) {
        if let url = URL(string: link), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
