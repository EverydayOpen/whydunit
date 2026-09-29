#if DEBUG
import AppKit
import WhydunitCore
import WhydunitMac

/// Screenshots without a Mac user (.github/workflows/screens.yml). A Debug build launched with
/// `-demoScreen <welcome|summary|finding|backups|activity|backUpSheet>` shows a made-up scan on that screen, and
/// `-demoAppearance light|dark` sets the look (the global AppleInterfaceStyle default doesn't reach a new app).
/// Nothing is scanned, opened, written or moved: the sample items don't exist, and AppStore skips its staging recovery
/// and its history read. iCloud Drive's folder must exist (the workflow makes an empty one), or every screen is
/// "iCloud Drive Is Off": ICloudLocations has no public initializer to fake it with.
@MainActor enum Demo {
    enum Screen: String { case welcome, summary, finding, backups, activity, backUpSheet }

    static let screen = UserDefaults.standard.string(forKey: "demoScreen").flatMap(Screen.init(rawValue:))

    static func fill(_ store: AppStore, _ screen: Screen) {
        if let look = UserDefaults.standard.string(forKey: "demoAppearance") {
            // Next turn: AppDelegate.init builds the store, maybe before NSApp exists.
            Task { NSApp.appearance = NSAppearance(named: look == "dark" ? .darkAqua : .aqua) }
        }
        guard screen != .welcome else { return }   // never scanned
        let scanned = Date().addingTimeInterval(-120)   // "Scanned 2 minutes ago"
        let home = SystemInfo.homeDirectory
        let cloud = store.locations.cloudDocs ?? home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")

        /// Waiting to upload unless `edit` says otherwise.
        func item(_ relativePath: String, _ bytes: Int64, hoursAgo: Double, package: Bool = false,
                  _ edit: (inout ItemRecord) -> Void = { _ in }) -> ItemRecord {
            let modified = scanned.addingTimeInterval(-hoursAgo * 3600)
            var record = ItemRecord(
                path: cloud.appendingPathComponent(relativePath).path, root: .iCloudDrive, relativePath: relativePath,
                isDirectory: package, isPackage: package, logicalSize: bytes, allocatedSize: bytes,
                modified: modified, inPlaceSince: modified, isUbiquitous: true, isUploaded: false, isUploading: false,
                downloadingStatus: .current, hasUnresolvedConflicts: false, isExcludedFromSync: false, bsdFlags: 0)
            edit(&record)
            return record
        }
        let nameTaken = ItemError(domain: "NSFileProviderErrorDomain", code: -1001,
                                  message: "An item with the same name already exists in this folder.")
        // The real classifier turns these into Only on This Mac, Stuck Uploads, Upload Errors, Conflicts, Moved Files
        // and Not Synced by Design, so every title and step is the app's own copy.
        let items = [
            item("Finance/Taxes 2025.numbers", 2_480_000, hoursAgo: 31, package: true),
            item("Finance/Budget 2026.numbers", 1_960_000, hoursAgo: 27, package: true),
            item("Work/Q3 Review.key", 184_300_000, hoursAgo: 20, package: true),
            item("Work/Client Brief.pages", 12_600_000, hoursAgo: 9, package: true),
            item("Photos Export/IMG_4820.HEIC", 3_700_000, hoursAgo: 52) { $0.isUploaded = true },
            item("Photos Export/IMG_4821.HEIC", 3_900_000, hoursAgo: 52),
            item("Photos Export/IMG_4822.HEIC", 4_200_000, hoursAgo: 52),
            item("Video/Summer Edit.mov", 1_842_000_000, hoursAgo: 96),
            item("Scans/Lease Agreement.pdf", 6_100_000, hoursAgo: 0.05) { $0.isUploading = true },
            item("Work/Invoices/Invoice 0412.pdf", 410_000, hoursAgo: 40) { $0.uploadingError = nameTaken },
            item("Work/Invoices/invoice 0412.pdf", 402_000, hoursAgo: 40) { $0.uploadingError = nameTaken },
            item("Notes/Reading List.rtf", 48_000, hoursAgo: 5) { $0.isUploaded = true; $0.hasUnresolvedConflicts = true },
            item("Projects/render-cache.nosync", 820_000_000, hoursAgo: 70) { $0.isDirectory = true },
        ]
        let context = ScanContext(now: scanned, os: OSVersion(26), probe: .uploaded(seconds: 14), freeBytes: 182_400_000_000,
                                  relocatedFolders: [home.appendingPathComponent("iCloud Drive (Archive)").path])
        var diagnosis = ICloudClassifier.classify(items, context: context)
        diagnosis.checkedCount = 4_213   // the synced rest of a real iCloud Drive, left out of `items`
        store.diagnosis = diagnosis
        store.itemsByPath = Dictionary(uniqueKeysWithValues: items.map { ($0.path, $0) })
        store.probe = context.probe
        store.freeBytes = context.freeBytes
        store.lastScanDate = scanned
        store.scanState = .done

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH.mm.ss"   // BackupService's folder names
        func backup(hoursAgo: Double, _ picked: ArraySlice<ItemRecord>) -> BackupManifest {
            let created = scanned.addingTimeInterval(-hoursAgo * 3600)
            let folder = store.backupsRoot.appendingPathComponent(stamp.string(from: created))
            return BackupManifest(created: created, folder: folder.path, entries: picked.map {
                BackupManifest.Entry(source: $0.path,
                                     copy: folder.appendingPathComponent($0.root.displayName).appendingPathComponent($0.relativePath).path,
                                     bytes: $0.logicalSize ?? 0, sha256: "", verified: true)
            })
        }
        let recent = backup(hoursAgo: 3, items[0..<3]), older = backup(hoursAgo: 50, items[4..<7])
        store.backups = [recent, older]   // newest first, like BackupService.listBackups

        func entry(_ hoursAgo: Double, _ action: FixAction, _ target: String, _ detail: String,
                   outcome: AuditEntry.Outcome = .succeeded) -> AuditEntry {
            AuditEntry(date: scanned.addingTimeInterval(-hoursAgo * 3600), action: action, target: target,
                       outcome: outcome, detail: detail)
        }
        func backedUp(_ m: BackupManifest, hoursAgo: Double) -> [AuditEntry] {
            m.entries.reversed().map { entry(hoursAgo, .backUp, $0.source, "Copied and verified in \((m.folder as NSString).abbreviatingWithTildeInPath)") }
        }
        let trashed = store.backupsRoot.appendingPathComponent(stamp.string(from: scanned.addingTimeInterval(-11 * 86_400)))
        // Newest first, like ActivityLog.all. Retries only of items with a verified backup, as the app does.
        store.activity = [
            [entry(2.95, .retryUpload, items[3].path, "Back up first", outcome: .skipped),
             entry(2.97, .retryUpload, items[2].path, "Moved out and back; still waiting for iCloud to upload it")],
            backedUp(recent, hoursAgo: 3),
            [entry(26, .backUp, trashed.path, AppStore.trashedBackupDetail),
             entry(49.9, .restartSync, "bird", "Asked iCloud's sync process to restart"),
             entry(49.95, .retryUpload, items[4].path, "Uploaded after 38 s")],
            backedUp(older, hoursAgo: 50),
        ].flatMap { $0 }

        switch screen {
        case .welcome, .summary: break
        case .backups: store.route = .backups
        case .activity: store.route = .activity
        case .finding, .backUpSheet:
            store.route = .finding(.onlyOnThisMac)
            // The same four rows in both shots, not the page's full pre-selection (an accent slab over half the table).
            // Once the window is up, so the sheet has a window to attach to, and after the page's own pre-selection,
            // so the subtitle and the table's rows agree with the sheet.
            Task {
                try? await Task.sleep(for: .seconds(1))
                let picked = items[0..<4].map(\.path)
                store.selection = Set(picked)
                if screen == .backUpSheet { store.sheet = .backUp(paths: picked) }
            }
        }
    }
}
#endif
