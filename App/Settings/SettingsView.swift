import AppKit
import SwiftUI
import WhydunitMac

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            AdvancedSettings().tabItem { Label("Advanced", systemImage: "gearshape.2") }
        }
    }
}

private extension View {
    /// Grouped forms are scroll-backed; without this a Settings pane can collapse or grow too tall.
    func settingsPane() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .frame(width: 520)
            .fixedSize(horizontal: false, vertical: true)   // VERIFY: each tab sizes to its content on 15 and 26.
    }
}

/// Our own failures are gray with an icon, as in the Back Up sheet (UI_SPEC §2.5), never red.
private struct ErrorLabel: View {
    let text: String

    var body: some View {
        Label { Text(text) } icon: { Image(systemName: "exclamationmark.circle") }
            .foregroundStyle(.secondary)
    }
}

private struct GeneralSettings: View {
    @Environment(AppStore.self) private var store
    @ObservedObject private var updater = Updater.shared
    @State private var folderError: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $updater.automaticallyChecksForUpdates) {
                    Text("Automatically check for updates")
                    Text("Checks once a day.")
                }
            }
            Section {
                LabeledContent {
                    Button("Choose…", action: chooseFolder)
                } label: {
                    Text("Backups folder")
                    Text((store.backupsRoot.path as NSString).abbreviatingWithTildeInPath)
                }
                if let folderError {
                    ErrorLabel(text: folderError)
                }
            } footer: {
                // Otherwise the Backups page looks emptied, and it covers Reset too.
                Text("Changing it doesn't move earlier backups; move them into the new folder to keep using them.")
            }
        }
        .settingsPane()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where Whydunit saves backup copies."
        // A sheet on the Settings window; app-modal only when there's no window.
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { if $0 == .OK, let url = panel.url { use(url) } }
        } else if panel.runModal() == .OK, let url = panel.url {
            use(url)
        }
    }

    private func use(_ url: URL) {
        // Fresh locations plus the folder's own flag: the last scan's may be stale.
        if ICloudLocations.current().contains(url)
            || (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true {
            folderError = "Choose a folder outside iCloud Drive, so your backups don't depend on iCloud."
        } else {
            folderError = nil
            store.backupsRoot = url
        }
    }
}

private struct AdvancedSettings: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Button("Open Folder", action: openActivityLogFolder)
                } label: {
                    Text("Activity log")
                    Text("A record of every change Whydunit makes.")
                }
            }
            Section {
                LabeledContent {
                    Button("Reset Whydunit…") { confirmReset = true }
                } label: {
                    Text("Reset")
                    Text("Clears settings on this Mac. Backups are kept.")
                }
            }
        }
        .settingsPane()
        .confirmationDialog("Reset Whydunit?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive, action: reset)
            Button("Cancel", role: .cancel) { confirmReset = false }
        } message: {
            Text("Settings are cleared. Your backups and activity log are kept.")
        }
    }

    private func openActivityLogFolder() {
        let folder = ActivityLog.defaultURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private func reset() {
        store.backupsRoot = BackupService.defaultRoot
        if let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
    }
}
