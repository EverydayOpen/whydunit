import AppKit
import os
import WhydunitMac

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: AppStore

    override init() {
        // Before any file access (AppStore.init already reads iCloud locations and backups):
        // reading a file's status must never download its contents.
        let ok = Materialization.disableForProcess()
        assert(ok, "materialization policy not applied")
        store = AppStore()
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Runs before SwiftUI creates the window; didFinish would be too late to drop the Tab menu items.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = Updater.shared   // start Sparkle's scheduled checks now, not when the app menu is first built
        trashLeftoverProbe()
        reportRecovered()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// During Retry Upload no item moves out once quitting, and an item already out goes back before quitting.
    /// During the upload check, stop it so it trashes its test file instead of leaving it in iCloud Drive.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let out = store.retryGate.withLock { state -> Bool in
            state.quitting = true
            return state.out
        }
        let probing = if case .scanning(let phase, _, _) = store.scanState { phase == AppStore.probePhase } else { false }
        guard probing || out else { return .terminateNow }
        store.stopRequested = true
        Task {
            if probing { await store.stopScanAndWait(timeout: .seconds(5)) }
            // ponytail: polls; an item is out about 40 s at most (10 s wait, 30 s coordination timeout, a rename),
            // so a callback isn't worth it.
            while store.retryGate.withLock({ $0.out }) { try? await Task.sleep(for: .milliseconds(250)) }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// No check runs before the first scan, so any of this Mac's test files still there is from a quit, crash or
    /// force quit. The folder syncs, so another Mac's probe is trashed only once it's an hour old, as UploadProbe does.
    /// ponytail: not awaited; a scan reaches its check long after this listing, and if it ever didn't, that
    /// check would only come back "Unknown". Await it from runScan if that shows up.
    private func trashLeftoverProbe() {
        guard let folder = store.locations.cloudDocs?.appendingPathComponent(UploadProbe.folderName, isDirectory: true) else { return }
        // UploadProbe names this Mac's probes "probe-<id>-<uuid>.bin" with the id under the same key.
        let defaults = UserDefaults.standard
        let installID = defaults.string(forKey: "probeInstallID") ?? UUID().uuidString
        defaults.set(installID, forKey: "probeInstallID")
        Task.detached {   // off the main thread: iCloud Drive calls can block on a busy fileproviderd
            let fm = FileManager.default
            for name in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasPrefix("probe-") && name.hasSuffix(".bin") {
                let probe = folder.appendingPathComponent(name)
                let date = try? probe.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                guard name.hasPrefix("probe-\(installID)-") || date.map({ Date().timeIntervalSince($0) > 3600 }) == true else { continue }
                try? fm.trashItem(at: probe, resultingItemURL: nil)
            }
            // ponytail: this listing can predate another Mac's in-flight probe syncing down, so its folder (and
            // probe) can go from under it; that costs one "Unknown" check. Per-Mac subfolders if that shows up.
            if let rest = try? fm.contentsOfDirectory(atPath: folder.path), rest.allSatisfy({ $0.hasPrefix(".") }) {
                try? fm.trashItem(at: folder, resultingItemURL: nil)
            }
        }
    }

    /// A quit, crash or power loss during Retry Upload can leave items in the hidden staging folder;
    /// AppStore puts them back off the main thread. Once it has, say so, and show where they are.
    private func reportRecovered() {
        Task {
            let paths = await store.recovery.value
            guard !paths.isEmpty else { return }
            let stuck = paths.filter { $0.hasPrefix(AppStore.stagingRoot.path + "/") }.count
            let back = paths.count - stuck
            let alert = NSAlert()
            alert.messageText = back > 0
                ? "Whydunit put back \(itemCount(back)) that \(back == 1 ? "was" : "were") moved out for Retry Upload when it last quit."
                : "Whydunit quit during Retry Upload and couldn't put \(stuck == 1 ? "an item" : "some items") back."
            if stuck > 0 {
                alert.informativeText = "\(itemCount(stuck)) couldn't be moved and \(stuck == 1 ? "is" : "are") still in a holding folder. Move \(stuck == 1 ? "it" : "them") back to \(stuck == 1 ? "its" : "their") folder in iCloud Drive. Your Backups folder has a verified copy."
            }
            alert.addButton(withTitle: "Show in Finder")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn { FinderBridge.reveal(paths) }
        }
    }

    /// Dock click with no visible window: returning true lets SwiftUI reopen (or deminiaturize) the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true   // VERIFY: SwiftUI reopens the closed `Window(id: "main")` scene here, as it does for WindowGroup.
    }
}
