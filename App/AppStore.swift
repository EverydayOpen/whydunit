import AppKit
import Observation
import os
import WhydunitCore
import WhydunitMac

enum Route: Hashable { case summary, finding(RuleID), backups, activity }

enum ScanState: Equatable {
    case never, scanning(phase: String, itemsSeen: Int, fraction: Double?), done, failed(String)
}

enum ActiveSheet: Identifiable {
    /// `thenRetry`: opened from Retry Upload's "Back Up These…", so Done can continue to that retry.
    case backUp(paths: [String], thenRetry: [String]? = nil), retryUpload(paths: [String]), restartSync

    var id: String {
        switch self {
        case .backUp: "backUp"
        case .retryUpload: "retryUpload"
        case .restartSync: "restartSync"
        }
    }
}

/// The single source of truth for the UI. Scanning and actions run in WhydunitMac off the main actor;
/// only their results land here.
@Observable @MainActor final class AppStore {
    var route: Route? = .summary
    var scanState: ScanState = .never
    var diagnosis: Diagnosis?
    var itemsByPath: [String: ItemRecord] = [:]
    var probe: ProbeResult = .notRun
    /// Free space when the last scan ran, the value the Not Enough Space rule was classified with.
    var freeBytes: Int64?
    /// The I11 finding is showing; Retry Upload skips every item then.
    var isSyncStalled: Bool { diagnosis?.findings.contains { $0.rule == .syncStalled } == true }
    var locations: ICloudLocations
    var selection: Set<String> = []
    var inspectorShown = false
    var sheet: ActiveSheet?
    var backups: [BackupManifest] = []
    var activity: [AuditEntry] = []
    var backupsRoot: URL {
        didSet {
            UserDefaults.standard.set(backupsRoot.path, forKey: "backupsRoot")
            backups = BackupService(backupsRoot: backupsRoot, locations: locations).listBackups()
        }
    }
    var lastScanDate: Date?
    /// Set by Stop or Quit during Retry Upload; checked between items, so the current item always goes back first.
    var stopRequested = false
    private(set) var isRetrying = false
    /// Shared with UploadRetrier: `out` while an item is out of iCloud Drive; once `quitting`, no item moves out.
    /// Quit waits only for `out`, never for a stalled FileProvider read or the upload wait.
    let retryGate = OSAllocatedUnfairLock(initialState: (quitting: false, out: false))

    static let probePhase = "Checking that iCloud is accepting uploads…"
    /// Activity shows entries with this detail as "Move to Trash", not "Back Up".
    static let trashedBackupDetail = "Moved this backup to the Trash"
    /// Home volume, so the move out and back is a rename, not a copy.
    static var stagingRoot: URL { BackupService.defaultRoot.appendingPathComponent(".staging", isDirectory: true) }

    private let scanner = ICloudScanner()
    private let log = ActivityLog(url: ActivityLog.defaultURL)
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    /// The last scan started; cancelScan() doesn't clear it, so the next scan can wait for it to really end.
    @ObservationIgnored private var scanWorker: Task<Void, Never>?
    /// Progress hops to the main actor asynchronously; updates from a finished or cancelled scan are dropped.
    @ObservationIgnored private var progressToken: UUID?
    /// Items a quit or crash during Retry Upload left in staging, put back at launch. Where each one is now:
    /// its original path, "… (Whydunit restored)" beside it, or still the staging path if the move failed.
    /// Off the main thread: its coordinated writes can block on a wedged fileproviderd, and launch mustn't hang.
    let recovery: Task<[String], Never>

    init() {
        locations = ICloudLocations.current()
        backupsRoot = UserDefaults.standard.string(forKey: "backupsRoot")
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? BackupService.defaultRoot
        // retryUpload awaits it, so it finishes before any retry can start.
        let stagingRoot = Self.stagingRoot
        let recovery = Task.detached { UploadRetrier.recoverStaged(in: stagingRoot) }
        self.recovery = recovery
        let stagingPrefix = stagingRoot.path + "/"
        Task {
            for path in await recovery.value {
                await log.append(AuditEntry(
                    date: Date(), action: .retryUpload, target: path, outcome: .failed,
                    detail: path.hasPrefix(stagingPrefix)
                        ? "Whydunit quit during Retry Upload and couldn't put this back at next launch"
                        : "Put back at next launch after Whydunit quit during Retry Upload"))
            }
            await refreshHistory()
        }
    }

    // MARK: Scan

    func scan() {
        // A cancelled scan can stay blocked in fileproviderd until its GCD worker returns: the next one waits for it,
        // so two walks never overlap. The state and dropped progress show the new scan meanwhile.
        let previous = scanWorker
        scanTask?.cancel()
        progressToken = nil
        scanState = .scanning(phase: "Finding iCloud Drive…", itemsSeen: 0, fraction: nil)
        scanTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await runScan()
        }
        scanWorker = scanTask
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        progressToken = nil
        if case .scanning = scanState { scanState = diagnosis == nil ? .never : .done }
    }

    /// Quit during the upload check: cancelling it makes the probe trash its test file. Waits for that, at most `timeout`.
    func stopScanAndWait(timeout: Duration) async {
        guard let task = scanTask else { return }
        cancelScan()
        let (ended, end) = AsyncStream<Void>.makeStream()
        Task { await task.value; end.finish() }
        Task { try? await Task.sleep(for: timeout); end.finish() }
        for await _ in ended {}
    }

    private func runScan() async {
        let token = UUID()
        progressToken = token
        // Off the main actor: both can block on a busy fileproviderd.
        let (locs, free) = await Task.detached {
            (ICloudLocations.current(), SystemInfo.freeBytes(at: SystemInfo.homeDirectory))
        }.value
        guard !Task.isCancelled else { return }   // cancelScan() or a newer scan owns the state now
        locations = locs
        guard let cloudDocs = locations.cloudDocs else {
            progressToken = nil
            // The old findings name paths that are gone now; don't offer actions on them.
            diagnosis = nil
            itemsByPath = [:]
            selection = []
            probe = .notRun
            if isFindingRoute { route = .summary }
            scanState = .failed("iCloud Drive isn't turned on for this Mac.")
            return
        }
        do {
            // Process-wide and idempotent: re-applied because the launch check is only an assert, gone in Release.
            guard Materialization.disableForProcess() else {
                throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey:
                    "Whydunit couldn't make sure scanning won't download files from iCloud, so it didn't scan."])
            }
            // The scanner already throttles its callback to about 10 per second.
            let output = try await scanner.scan(roots: locations.roots) { p in
                Task { @MainActor in
                    guard self.progressToken == token else { return }
                    self.scanState = .scanning(phase: p.phase, itemsSeen: p.itemsSeen, fraction: p.fraction)
                }
            }
            // Every check below runs on the main actor right after resuming, so a cancelled or
            // superseded scan never touches state that a newer scan owns.
            try Task.checkCancellation()
            progressToken = nil
            scanState = .scanning(phase: Self.probePhase, itemsSeen: output.items.count, fraction: nil)
            let probe = await UploadProbe.run(cloudDocs: cloudDocs)
            try Task.checkCancellation()

            let context = ScanContext(
                now: Date(), os: SystemInfo.osVersion(), probe: probe, freeBytes: free,
                deniedRoots: output.deniedRoots, relocatedFolders: locations.relocatedFolders)
            let items = output.items
            let (diagnosis, byPath) = await Task.detached(priority: .userInitiated) { () -> (Diagnosis, [String: ItemRecord]) in
                (ICloudClassifier.classify(items, context: context),
                 Dictionary(items.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first }))
            }.value
            try Task.checkCancellation()

            self.probe = probe
            freeBytes = free
            self.diagnosis = diagnosis
            itemsByPath = byPath
            lastScanDate = context.now
            selection = selection.filter { byPath[$0] != nil }
            if case .finding(let rule)? = route, finding(rule) == nil { route = .summary }
            scanState = .done
            announce("Scan finished. \(diagnosis.headline?.title ?? "No problems found")")
            await refreshHistory()
        } catch {
            guard !Task.isCancelled else { return }   // cancelScan() or a newer scan owns the state now
            progressToken = nil
            scanState = .failed(error.localizedDescription)
            announce("The scan didn't finish. \(error.localizedDescription)")
        }
    }

    /// The toolbar spinner just disappears, so VoiceOver says when a scan ends (UI_SPEC §3.8).
    /// High priority, so a sheet closing right after doesn't cut it off.
    func announce(_ text: String) {
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    // MARK: Queries

    /// Only finding pages have rows, so only they have an inspector.
    var isFindingRoute: Bool {
        if case .finding? = route { return true }
        return false
    }

    func finding(_ rule: RuleID) -> Finding? {
        diagnosis?.findings.first { $0.rule == rule }
    }

    func items(for finding: Finding) -> [ItemRecord] {
        finding.itemPaths.compactMap { itemsByPath[$0] }
    }

    // MARK: Actions

    /// Back Up, Retry Upload and Restart iCloud Sync open their consent sheet; the others run right away.
    func request(_ action: FixAction, for finding: Finding, paths: [String]) {
        let targets = paths.isEmpty ? finding.itemPaths : paths
        switch action {
        case .backUp: present(.backUp(paths: targets))
        case .retryUpload: present(.retryUpload(paths: targets))
        case .restartSync: present(.restartSync)
        case .showInFinder: FinderBridge.reveal(targets.isEmpty ? locations.relocatedFolders : targets)
        case .copyCommand: if let command = finding.command { copyToPasteboard(command) }
        case .openICloudSettings: FinderBridge.openICloudSettings()
        case .openPrivacySettings: FinderBridge.openPrivacySettings()
        }
    }

    /// Stops a running scan first: one finishing under the sheet would swap the items the user is reviewing.
    private func present(_ next: ActiveSheet) {
        cancelScan()
        sheet = next
    }

    func backUp(paths: [String], progress: @escaping (BackupProgress) -> Void) async throws -> BackupManifest {
        let items = paths.compactMap { itemsByPath[$0] }
        // Fresh, not the last scan's: Desktop & Documents may have joined iCloud since.
        let service = BackupService(backupsRoot: backupsRoot, locations: ICloudLocations.current())
        do {
            let manifest = try await service.backUp(items, now: Date()) { p in
                Task { @MainActor in progress(p) }
            }
            for entry in manifest.entries {
                await log.append(AuditEntry(
                    date: manifest.created, action: .backUp, target: entry.source,
                    outcome: entry.verified ? .succeeded : .failed,
                    detail: entry.verified ? "Copied and verified in \(manifest.folder)"
                                           : "The copy didn't match the original"))
            }
            await refreshHistory()
            return manifest
        } catch {
            var thrown = error, outcome = AuditEntry.Outcome.failed
            if error is CancellationError {
                // The service writes the manifest for the copies verified before the stop; `backups` isn't refreshed yet.
                let known = Set(backups.map(\.id))
                let kept = service.listBackups().first { !known.contains($0.id) }?.entries.filter(\.verified).count ?? 0
                let detail = "Stopped. \(kept == 1 ? "1 verified copy was" : "\(kept) verified copies were") kept."
                thrown = CocoaError(.userCancelled, userInfo: [NSLocalizedDescriptionKey: detail])
                outcome = .skipped
            }
            await log.append(AuditEntry(date: Date(), action: .backUp, target: backupsRoot.path,
                                        outcome: outcome, detail: thrown.localizedDescription))
            await refreshHistory()
            throw thrown
        }
    }

    func trashBackup(_ m: BackupManifest) async throws {
        try BackupService(backupsRoot: backupsRoot, locations: locations).trashBackup(m)
        await log.append(AuditEntry(date: Date(), action: .backUp, target: m.folder, outcome: .succeeded,
                                    detail: Self.trashedBackupDetail))
        await refreshHistory()
    }

    /// One item at a time. `progress(path, nil)` when an item starts, `progress(path, outcome)` when it ends.
    /// Items without a verified backup are skipped. Stops between items once `stopRequested` is set.
    func retryUpload(paths: [String], progress: @escaping (String, RetryOutcome?) -> Void) async {
        stopRequested = false
        // Items a crash left in staging go back before anything else moves out. Not isRetrying yet: nothing is out.
        _ = await recovery.value
        isRetrying = true
        defer { isRetrying = false }
        backups = BackupService(backupsRoot: backupsRoot, locations: locations).listBackups()
        let retrier = UploadRetrier(scanner: scanner, stagingRoot: Self.stagingRoot, gate: retryGate)
        for path in paths {
            if stopRequested { break }
            progress(path, nil)
            let outcome: RetryOutcome
            if !Materialization.disableForProcess() {
                // The checksum walk of a package would otherwise download its evicted files.
                outcome = .skipped(reason: "Whydunit couldn't make sure this won't download files from iCloud.")
            } else if isSyncStalled {
                // I11: with sync stalled as a whole, the move out and back would only queue behind the stuck daemon.
                // Keyed to the finding, not the probe: a busy iCloud (probe waited, other files uploading) isn't stalled.
                outcome = .skipped(reason: "iCloud isn't uploading right now. Restart iCloud Sync first.")
            } else if let item = itemsByPath[path], let rootURL = locations.roots[item.root] {
                // `backups` is newest first, so this is the newest verified copy.
                if let entry = backups.lazy.compactMap({ $0.verifiedEntry(for: path) }).first {
                    outcome = await retrier.retry(item, rootURL: rootURL, backup: entry)
                    // Off the main actor: a package re-read walks up to 10,000 children.
                    let fresh = await Task.detached { [scanner] in
                        scanner.record(at: URL(fileURLWithPath: path), root: item.root, rootURL: rootURL)
                    }.value
                    if let fresh { itemsByPath[path] = fresh }
                } else {
                    outcome = .skipped(reason: "Back up first")
                }
            } else {
                outcome = .skipped(reason: "No longer in the scan results")
            }
            // Any failure is unexpected (maybe systemic): stop, so it can't strand the rest in staging too.
            if case .failed = outcome { stopRequested = true }
            progress(path, outcome)
            let logged: (outcome: AuditEntry.Outcome, detail: String) = switch outcome {
            case .uploaded(let seconds): (.succeeded, "Uploaded after \(Int(seconds.rounded())) s")
            case .stillWaiting: (.succeeded, "Moved out and back; still waiting for iCloud to upload it")
            case .skipped(let reason): (.skipped, reason)
            case .failed(let reason): (.failed, reason)
            }
            await log.append(AuditEntry(date: Date(), action: .retryUpload, target: path,
                                        outcome: logged.outcome, detail: logged.detail))
        }
        await refreshHistory()
    }

    /// Returns the logged entry, so the sheet can tell "restarted", "wasn't running" and "failed" apart.
    func restartSync() async -> AuditEntry {
        let entry: AuditEntry
        do {
            let signalled = try await SyncService.restartBird()
            entry = AuditEntry(date: Date(), action: .restartSync, target: "bird",
                               outcome: signalled ? .succeeded : .skipped,
                               detail: signalled ? "Asked iCloud's sync process to restart"
                                                 : "iCloud's sync process wasn't running")
        } catch {
            entry = AuditEntry(date: Date(), action: .restartSync, target: "bird",
                               outcome: .failed, detail: error.localizedDescription)
        }
        await log.append(entry)
        await refreshHistory()
        return entry
    }

    // MARK: Export

    func copyDiagnosis() {
        guard let diagnosis else { return }
        copyToPasteboard(DiagnosisText.render(diagnosis, items: itemsByPath, os: SystemInfo.osVersion(),
                                              home: SystemInfo.homeDirectory.path))
    }

    func exportCSV(for finding: Finding) -> String {
        CSVExport.render(items(for: finding))
    }

    // MARK: Private

    private func refreshHistory() async {
        backups = BackupService(backupsRoot: backupsRoot, locations: locations).listBackups()
        activity = await log.all()
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
