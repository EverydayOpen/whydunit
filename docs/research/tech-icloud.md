# Technical feasibility: finding and safely recovering stuck iCloud Drive files

**Target:** a non-sandboxed, Developer ID–signed, notarized macOS app (macOS 14–27) with **no iCloud entitlement**.
**Date of research:** 2026-09-27. Status labels: **VERIFIED** means a primary source (Apple docs, an Apple DTS forum reply, or Apple Support) was read. **REPORTED** means one or more third-party sources say it but Apple does not confirm it. **UNVERIFIED** means I could not confirm it.

> Note on method: the session's web-search budget ran out partway through. After that, only known URLs were fetched. Gaps that remain are marked UNVERIFIED.

---

## 0. Bottom line

| Question | Answer | Confidence |
|---|---|---|
| Can a non-sandboxed, non-entitled app read files in `~/Library/Mobile Documents/com~apple~CloudDocs`? | Yes. Apple DTS (Quinn) showed a plain `String(contentsOf:)` read of a CloudDocs file succeeds with App Sandbox off and fails with `EPERM` with the sandbox on. | VERIFIED ([forum 727902](https://developer.apple.com/forums/thread/727902)) |
| Do the `ubiquitousItem*` URL resource keys work without an entitlement? | Mostly yes: open-source tools and Eclectic Light's apps read them from unentitled processes. But keys can come back **nil**. One tool reports `ubiquitousItemDownloadingStatus` = nil for 150/150 materialized files on macOS 26, and iCloud Drive does not support `ubiquitousItemIsExcludedFromSync`. Design every field as `Optional` and fall back to `lstat`/`SF_DATALESS`. | REPORTED plus partly VERIFIED |
| `startDownloadingUbiquitousItem(at:)` / `evictUbiquitousItem(at:)` without an entitlement? | Work, according to two independent tools (one unsigned CLI, one Developer ID app on macOS 26.5.1). Apple documents no entitlement requirement for them. | REPORTED |
| `NSMetadataQuery` + `NSMetadataQueryUbiquitousDocumentsScope`? | **Not usable.** The scope is defined as the app's own iCloud container(s), which need `com.apple.developer.icloud-container-identifiers`. The iCloud `NSMetadata*` attributes are "valid only when requested from iCloud files", i.e. through ubiquitous scopes. Spotlight also cannot find evicted files. | VERIFIED (docs) + REPORTED |
| Is there a public "force re-upload" API? | macOS **26+ only**: `pauseSyncForUbiquitousItem`, `uploadLocalVersionOfUbiquitousItem(at:withConflictResolutionPolicy:)`, `resumeSyncForUbiquitousItem(at:with:)`, `fetchLatestRemoteVersionOfItem`. Whether they work on iCloud Drive items from a non-entitled app is **UNVERIFIED**. Gate on `ubiquitousItemSupportedSyncControlsKey`. | Docs VERIFIED; behavior UNVERIFIED |
| Reading the unified log (FileProvider/CloudKit) to explain why a file is stuck? | Works: `OSLogStore` `.system`/`local()` from a **non-sandboxed app run by an admin user**, with no entitlement needed. | VERIFIED (Quinn, [forum 666679](https://developer.apple.com/forums/thread/666679)) |
| Can this be tested in GitHub Actions? | Only unit tests with fixtures. CI runners have no iCloud account, so all sync behavior has to be tested on real Macs signed into iCloud. | Inference |

---

## 1. URLResourceKey ubiquitous keys: facts, availability, and known bugs

### 1.1 Key list and availability (Apple docs)

| Swift key | ObjC | macOS | Notes |
|---|---|---|---|
| `.isUbiquitousItemKey` | `NSURLIsUbiquitousItemKey` | 10.7+ | DTS: means the object is "under the control of iCloud Drive or a File Provider" ([forum 781427](https://developer.apple.com/forums/thread/781427)). `FileManager.isUbiquitousItem(at:)` is true if the item is *targeted* for iCloud, not proof that it has uploaded. |
| `.ubiquitousItemDownloadingStatusKey` | `NSURLUbiquitousItemDownloadingStatusKey` | 10.9+ | Values `URLUbiquitousItemDownloadingStatus.current` / `.downloaded` (stale local copy) / `.notDownloaded` ([docs](https://developer.apple.com/documentation/foundation/urlubiquitousitemdownloadingstatus)). |
| `.ubiquitousItemIsUploadedKey` | `NSURLUbiquitousItemIsUploadedKey` | 10.7+ | Apple note: don't poll it inside a coordinated-read block, because it needs a coordinated read itself and would deadlock ([docs](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadedkey)). |
| `.ubiquitousItemIsUploadingKey` | `NSURLUbiquitousItemIsUploadingKey` | 10.7+ | |
| `.ubiquitousItemUploadingErrorKey` | `NSURLUbiquitousItemUploadingErrorKey` | 10.9+ | `NSError`. See error codes in §6. |
| `.ubiquitousItemDownloadingErrorKey` | `NSURLUbiquitousItemDownloadingErrorKey` | 10.9+ | |
| `.ubiquitousItemIsDownloadingKey` | | 10.7+ | |
| `.ubiquitousItemDownloadRequestedKey` | | 10.9+ | Reported to stay `false` on one corrupted device ([forum 826061](https://developer.apple.com/forums/thread/826061)). |
| `.ubiquitousItemHasUnresolvedConflictsKey` | | 10.7+ | Use it together with `NSFileVersion.unresolvedConflictVersionsOfItem(at:)`. |
| `.ubiquitousItemIsSharedKey` + `ubiquitousSharedItem*` keys | | 10.12+ (UNVERIFIED exact version) | |
| `.ubiquitousItemContainerDisplayNameKey` | | 10.10+ (UNVERIFIED exact version) | |
| `.ubiquitousItemIsExcludedFromSyncKey` | `NSURLUbiquitousItemIsExcludedFromSyncKey` | **11.3+** ([docs](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisexcludedfromsynckey)) | **iCloud Drive does not support it.** Quinn (DTS): reading returns nil, and `setResourceValues` **hangs forever** in XPC (tested 11.6/12). Bug FB9733892 ([forum 692661](https://developer.apple.com/forums/thread/692661)). **Never set it.** Treat it as nil for iCloud Drive. |
| `.ubiquitousItemIsSyncPausedKey` | `NSURLUbiquitousItemIsSyncPausedKey` | **26.0+** | ([docs](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemissyncpausedkey)) |
| `.ubiquitousItemSupportedSyncControlsKey` → `NSFileManagerSupportedSyncControls` (`.pauseSync`, `.failUploadOnConflict`) | | **26.0+** | ([docs](https://developer.apple.com/documentation/foundation/nsfilemanagersupportedsynccontrols)) |
| Deprecated: `ubiquitousItemIsDownloadedKey`, `ubiquitousItemPercentDownloadedKey`, `ubiquitousItemPercentUploadedKey` | | | No per-byte progress. APFS swaps extents atomically, so allocated size jumps from 0 to full ([icloud-tools](https://github.com/icanhasjonas/icloud-tools)). |

### 1.2 Known bugs and quirks relevant to a scanner

- **`ubiquitousItemIsExcludedFromSync`**: unsupported by iCloud Drive; setting it hangs (VERIFIED, Quinn, FB9733892).
- **`ubiquitousItemDownloadingStatus` returns nil on macOS 26**: "verified: 150/150 materialized files", per [icloud-guard](https://github.com/rexbrahh/icloud-guard) (Developer ID, notarized). The author falls back to `lstat` `SF_DATALESS` plus `st_blocks > 0`. [halo-mac PR #12](https://github.com/prasad-rently/halo-mac/pull/12) also saw nil and treats it as "unknown", not "local". **REPORTED.** Your code must handle nil for every key.
- **The iOS 18.4 `.downloaded` state no longer auto-refreshes** (FB17662379, [forum 785030](https://developer.apple.com/forums/thread/785030)). iOS only; macOS impact UNVERIFIED.
- **Resource values are cached per `URL` instance.** Call `url.removeAllCachedResourceValues()` (or create a fresh URL) before each poll. Standard Foundation behavior; not specific to iCloud.
- **Sonoma+ has no more `.name.icloud` stubs.** Evicted files keep their real name and logical size and are *dataless* (`SF_DATALESS` in `st_flags`). Pre-Sonoma code that looks for `.icloud` placeholders is obsolete ([Eclectic Light](https://eclecticlight.co/2023/10/25/macos-sonoma-has-changed-icloud-drive-radically/)). Some 2026 code still assumes stubs, e.g. halo-mac.
- **Folders**: `ubiquitousItemDownloadingStatus` is file-oriented. For a dataless *folder*, Apple DTS points to `SF_DATALESS` and TN3150 ([forum 813369](https://developer.apple.com/forums/thread/813369)).
- **Tahoe Finder tag colors come back gray** for iCloud Drive items (`NSURLLabelNumberKey` = 1) ([iCloud Drive tag list, thread 815556](https://developer.apple.com/forums/tags/icloud-drive)). REPORTED.
- **`NSFileProviderManager(for:)` returns nil** when called from a process that is not the provider extension (macOS 26.5.1), so File Provider management APIs are out of reach. `FileManager.evictUbiquitousItem(at:)` still works ([icloud-guard](https://github.com/rexbrahh/icloud-guard)). REPORTED.

### 1.3 Scanner code (Swift)

```swift
import Foundation
import Darwin

let cloudDocs = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

let scanKeys: [URLResourceKey] = [
    .nameKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
    .fileSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey,
    .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
    .ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey,
    .ubiquitousItemUploadingErrorKey, .ubiquitousItemDownloadingErrorKey,
    .ubiquitousItemIsDownloadingKey, .ubiquitousItemHasUnresolvedConflictsKey,
    .ubiquitousItemIsSharedKey,
]

struct ItemState {
    let url: URL
    let v: URLResourceValues
    let stFlags: UInt32?          // from lstat; nil if lstat failed
    var isDataless: Bool { (stFlags ?? 0) & UInt32(SF_DATALESS) != 0 }   // SF_DATALESS = 0x40000000 (xnu sys/stat.h)
}

func lstatFlags(_ url: URL) -> UInt32? {
    var st = stat()
    return lstat(url.path, &st) == 0 ? st.st_flags : nil
}

/// TN3150: stop the scan from downloading dataless files. Thread-scoped, so run the whole
/// scan on ONE dedicated Thread (not across Swift-concurrency hops), or use IOPOL_SCOPE_PROCESS.
func withoutMaterialization<T>(_ body: () throws -> T) rethrows -> T {
    let old = getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD)
    _ = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD,
                       IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
    defer { if old >= 0 { _ = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD, old) } }
    return try body()
}

func scan(root: URL = cloudDocs) -> [ItemState] {
    withoutMaterialization {
        // Do NOT pass .skipsHiddenFiles. Treat packages as single items.
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: scanKeys,
                                                     options: [.skipsPackageDescendants],
                                                     errorHandler: { _, _ in true }) else { return [] }
        var out: [ItemState] = []
        for case let url as URL in e {
            guard let v = try? url.resourceValues(forKeys: Set(scanKeys)) else { continue }
            out.append(ItemState(url: url, v: v, stFlags: lstatFlags(url)))
        }
        return out
    }
}
```

- Under the materialization-off policy, reading a dataless file's data fails with **`EDEADLK`**. Handle it instead of treating it as corruption ([TN3150](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files)).
- TN3150 warns that `stat()`/`getattrlist()` can still materialize dataless *intermediate folders* in the path.
- For large trees, `getattrlistbulk(2)` (one syscall per directory batch) is what icloud-guard uses on a drive of about 425k files. REPORTED.
- `IOPOL_*` macros and `SF_DATALESS` should import into Swift from `Darwin`. Confirm on the first CI build; if one doesn't import, define `let SF_DATALESS: UInt32 = 0x40000000`.

### 1.4 Stuck-item classifier (heuristics)

```swift
enum Verdict { case ok, uploading, stuckUpload(reason: String), ineligible(String), excludedByDesign(String), conflict, unknown }

func classify(_ s: ItemState, now: Date = .init(), grace: TimeInterval = 30*60) -> Verdict {
    let v = s.v, name = v.name ?? s.url.lastPathComponent
    if let r = excludedReason(name: name, path: s.url.path) { return .excludedByDesign(r) }
    if let f = s.stFlags, f & UInt32(SF_IMMUTABLE | SF_APPEND | UF_APPEND) != 0 {
        return .ineligible("BSD flag schg/sappnd/uappnd blocks iCloud Drive sync (tested macOS 26.5)")
    }
    if (v.fileSize ?? 0) > 50_000_000_000 { return .ineligible("over 50 GB per-item limit") }   // Apple: 50 GB per file/folder
    if v.ubiquitousItemHasUnresolvedConflicts == true { return .conflict }
    if let err = v.ubiquitousItemUploadingError { return .stuckUpload(reason: describe(err)) }
    guard v.isUbiquitousItem == true, let uploaded = v.ubiquitousItemIsUploaded else { return .unknown } // nil => unknown, never "ok"
    if uploaded { return .ok }
    if v.ubiquitousItemIsUploading == true { return .uploading }
    let age = now.timeIntervalSince(v.contentModificationDate ?? now)
    return age > grace ? .stuckUpload(reason: "not uploaded, not uploading, unchanged for \(Int(age/60)) min") : .uploading
}
```

`excludedReason` should cover names ending in `.nosync` or `.tmp` (and anything inside such folders), plus Apple's automatic exclusions: `.DS_Store`, names starting `(A Document Being Saved`, `.ubd`, `.weakpkg`, `desktop.ini`, names starting `~$`, `$RECYCLE.BIN`, `Icon\r`, `.photoslibrary`/`.photolibrary`/`.aplibrary`, and Dropbox / Microsoft User Data folders ([Eclectic Light 2026-01-06](https://eclecticlight.co/2026/01/06/exclude-or-include-items-in-backup-search-icloud-drive-and-quicklook-preview/)).

---

## 2. NSMetadataQuery / Spotlight alternatives

- `NSMetadataQueryUbiquitousDocumentsScope` / `...UbiquitousDataScope` search the **app's own iCloud containers**, which need the container entitlement ([iCloud File Management archive](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html)). `NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope` "doesn't behave as documented" per DTS (FB9631965). **Do not use.**
- iCloud attributes such as `NSMetadataItemIsUbiquitousKey`, `NSMetadataUbiquitousItemIsUploadedKey`, `...IsUploadingKey`, `...DownloadingStatusKey` and `...HasUnresolvedConflictsKey` are **`NSMetadataQuery` keys, not Spotlight `kMDItem*` attributes**. They are only valid for iCloud files ([iCloud Metadata Attributes](https://developer.apple.com/library/archive/documentation/CoreServices/Reference/MetadataAttributesRef/Articles/iCloudAttrs.html)). **I found no `kMDItemIsUbiquitous` Spotlight attribute: UNVERIFIED / likely nonexistent.**
- Spotlight cannot find evicted (dataless) iCloud files (Oakley, [2025-10-26 comments](https://eclecticlight.co/2025/10/26/last-week-on-my-mac-why-spotlight-cant-find-some-files/)). So `mdfind` is not a complete inventory.
- A third-party developer found `NSMetadataQuery` returns nothing for iCloud Drive folders outside the app's container ([forum 709721](https://developer.apple.com/forums/thread/709721)).
- **Use instead:** a `FileManager.enumerator` scan plus URL resource values plus `lstat`, as in §1.3. For change notification, use **FSEvents** (`FSEventStreamCreate` on the CloudDocs root, per-file events) and re-read the resource values of changed paths. `brctl monitor` uses `NSMetadataQuery` but runs with Apple's entitlements.

---

## 3. FileManager / NSFileVersion / NSFileCoordinator without an entitlement

| API | Status for non-entitled, non-sandboxed app | Source |
|---|---|---|
| `FileManager.startDownloadingUbiquitousItem(at:)` | Works (REPORTED). Unsigned CLI, "No entitlements, no code signing, no sandbox". Bailiff/Cirrus also do this. | [icloud-tools](https://github.com/icanhasjonas/icloud-tools), [Bailiff](https://eclecticlight.co/2018/06/12/bailiff-1-0-now-available-take-control-of-icloud-drive/) |
| `FileManager.evictUbiquitousItem(at:)` | Works (REPORTED on macOS 26.5.1). **Don't wrap it in a coordinated write.** Apple says it takes its own. It only removes the local copy. | [icloud-guard](https://github.com/rexbrahh/icloud-guard), [docs](https://developer.apple.com/documentation/foundation/filemanager/evictubiquitousitem(at:)) |
| Deleting with `removeItem` | Apple: deleting from iCloud "can't be undone". **Use `FileManager.trashItem(at:resultingItemURL:)`**, never `removeItem`, for anything under CloudDocs. | [docs](https://developer.apple.com/documentation/foundation/filemanager/evictubiquitousitem(at:)) |
| `FileManager.setUbiquitous(_:itemAt:destinationURL:)` | Intended for moving into or out of *your* container. For CloudDocs, a plain coordinated `moveItem` is what Finder-equivalent tools do. Using `setUbiquitous` without an entitlement is UNVERIFIED. | |
| "Keep Downloaded" (pinning, macOS 15+) | Pinning uses xattr `com.apple.fileprovider.pinned` (tools write `com.apple.fileprovider.pinned#PX`, value `0x31`). A folder pin sits only on the folder, so walk ancestors to decide if a file is pinned. Pinning needs Optimise Mac Storage ON. | [Oakley](https://eclecticlight.co/2024/10/02/pinning-icloud-drive-in-sequoia-is-bizarre-and-an-update-to-cirrus/), icloud-tools |
| `NSFileVersion` (`currentVersionOfItem(at:)`, `otherVersionsOfItem(at:)`, `unresolvedConflictVersionsOfItem(at:)`, `isResolved`, `removeOtherVersionsOfItem(at:)`, `replaceItem(at:options:)`, `getNonlocalVersionsOfItem(at:completionHandler:)`) | Public API with no documented entitlement. Behavior on CloudDocs from a non-entitled app is **UNVERIFIED**, so test on a real Mac. Local versions **do not sync**. Each Mac has its own history, and versions don't move between volumes. A 14.4 bug lost versions on eviction (fixed 14.4.1). | [docs](https://developer.apple.com/documentation/foundation/nsfileversion), [Oakley](https://eclecticlight.co/2024/03/18/how-icloud-drive-works-in-macos-sonoma/), [Oakley 2026-05-12](https://eclecticlight.co/2026/05/12/what-gets-synced-in-icloud-drive/) |
| `NSFileCoordinator` (`coordinate(readingItemAt:options:error:byAccessor:)` with `.withoutChanges`) | No entitlement is documented. Use it for all reads and moves under CloudDocs. | Inference; Apple docs don't list entitlements |
| **macOS 26+** `pauseSyncForUbiquitousItem(at:)`, `resumeSyncForUbiquitousItem(at:with:)` (`NSFileManagerResumeSyncBehavior`: `.preserveLocalChanges`, `.afterUploadWithFailOnConflict`, `.dropLocalChanges`), `uploadLocalVersionOfUbiquitousItem(at:withConflictResolutionPolicy:)` (`.conflictPolicyDefault`, `.conflictPolicyFailOnConflict`), `fetchLatestRemoteVersionOfItem(at:)` | Documented (VERIFIED). **Pause fails with `featureUnsupported` on a regular (non-package) directory.** It fails with `NSFileWriteUnknownError` + underlying `EBUSY` if the provider is applying changes. A pause **survives app crash or relaunch**, so the app must always resume. An upload conflict gives `NSFileWriteUnknownError` + underlying `NSFileProviderError.localVersionConflictingWithServer`. Offline gives underlying `.serverUnreachable`. Whether iCloud Drive honors these for a non-entitled caller is **UNVERIFIED**. Check `ubiquitousItemSupportedSyncControls?.contains(.pauseSync)` first. | [pause](https://developer.apple.com/documentation/foundation/filemanager/pausesyncforubiquitousitem(at:completionhandler:)), [upload](https://developer.apple.com/documentation/foundation/filemanager/uploadlocalversionofubiquitousitem(at:withconflictresolutionpolicy:completionhandler:)) |

If you use the macOS 26 APIs, persist a "paused items" journal to disk *before* calling pause. On every launch, resume anything left in the journal.

---

## 4. Command-line tools

### brctl (`/usr/bin/brctl`)
Subcommands captured in a completion script: `diagnose [--collect-mobile-documents <container>] [--sysdiagnose] [--name]`, `download <path>`, `evict <path>`, `log [--color --path --home --filter --multiline -n --page --wait --shorten --digest]`, `dump [--output --database-path]`, `monitor [--scope DOCS|DATA|BOTH]`, `versions [--all]` ([argc-completions](https://github.com/sigoden/argc-completions/blob/main/completions/macos/brctl.sh), macOS version not stated). Also seen: `status`, `quota`.

| Subcommand | Evidence on current macOS | Root? |
|---|---|---|
| `brctl status` | Works on **macOS 27.0** (forum post shows `client:blocked-app-uninstalled SYNC DISABLED (app not installed)`) ([848148](https://developer.apple.com/forums/thread/848148)). Also Tahoe ([flohgro 2026-02](https://flohgro.com/blog/fixing-fileproviderd-on-macos-tahoe/)). Output is undocumented and thousands of lines long. Users read "Client Truth Unclean Items" as stuck queue items. | No sudo in any source |
| `brctl log -w --shorten` | Works on Tahoe (flohgro) | No sudo shown |
| `brctl quota` | Used by [icloud-monitor](https://github.com/jhkchan/icloud-monitor) | UNVERIFIED |
| `brctl diagnose` | Produces a very large `.tgz` (94 MB on 10.13). Listed as attempted on 26.5.2 ([837682](https://developer.apple.com/forums/thread/837682)). | Root requirement **UNVERIFIED** |
| `brctl dump` | "several MB of opaque information" (Oakley) | UNVERIFIED |
| `brctl download` / `evict` | **Conflicting.** icloud-tools says they were removed in Sonoma 14+. A March 2026 blog ([clews](https://clews.id.au/til/reclaiming-disk-space-from-icloud-drive-on-macos/)) reports `brctl evict` freeing about 400 GB, and a 26.5.2 forum post lists `brctl download` as attempted. **Don't depend on them**; use the FileManager APIs. | |

### fileproviderctl
- macOS **14.4 removed** `listproviders`, `thumbnail`, `attributes`, `signal`, `materialize`, `evict`, `coordinate`, `stabilize`, `domain`, `interactive-scheduling`. Apple says it will not fix this (FB13580772) ([forum 748036](https://developer.apple.com/forums/thread/748036)).
- Remaining after 14.4: `dump`, `evaluate`, `check`/`repair` (FPCK), `obfuscate` ([i2h3](https://i2h3.de/fileproviderctl-changes-macos-14.4/)). `diagnose` is also REPORTED on 26.
- Seen in use on Tahoe: `fileproviderctl check -v`, `fileproviderctl repair -v -a ~/Library/Mobile\ Documents` ([flohgro](https://flohgro.com/blog/fixing-fileproviderd-on-macos-tahoe/)).
- `fileproviderctl check -P` **hung** on 26.5.2 ([837682](https://developer.apple.com/forums/thread/837682)).
- **Recommendation:** never automate `repair`. At most, run `check` read-only with a hard timeout.

### Restarting daemons
- `killall bird` (the CloudDocs daemon) is a common community step. launchd respawns it, and an interrupted transfer resumes. No sourced reports of data loss. **Don't loop it**, because it destroys the log timeline you need for diagnosis. `killall bird; killall cloudd` escalates ([TidBITS](https://tidbits.com/2023/10/12/cloudy-with-a-chance-of-insanity-unsticking-icloud-drive/)).
- **macOS 26.4.1 HTTP/3 upload deadlock** (FB22476701, [forum 822534](https://developer.apple.com/forums/thread/822534)): uploads hang silently. Detection:
  `log show --predicate 'process == "cloudd"' --last 5m | grep "putContainer.*err=T.*requestDuration=-1.000.*protocol=h3"`.
  The workaround kills only the **user-level** `cloudd` and `nsurlsessiond` (never `--system` / `--privileged`). This is a strong "explain why it's stuck" signal the app can detect read-only. Have the user approve any kill.
- Deleting `~/Library/Application Support/CloudDocs` and `~/Library/Caches/CloudKit` appears in blogs ([mattgoodrich](https://mattgoodrich.com/posts/fixing-icloud-drive-sync-issues-macos/)). **The app must never do this automatically.** It forces a full resync. Also, macOS 27's new Application Support protection may block access (see §5).

### Unified log (the best evidence of why a file is stuck)
- Subsystems: `com.apple.FileProvider` (primary since Sonoma), `com.apple.clouddocs`, `com.apple.cloudkit`, `com.apple.mmcs`. Processes: `bird`, `cloudd`, `fileproviderd`, `nsurlsessiond` ([Oakley](https://eclecticlight.co/2023/11/21/icloud-drive-in-sonoma-fileprovider-and-eviction/)). Pinning shows up as `FPPinOperation`/`FPUnpinOperation`.
- API: `OSLogStore(scope: .system)` (macOS 12+) or `OSLogStore.local()`. Apple's docs claim `com.apple.logging.local-store` is required, but **third parties cannot get it**, and non-sandboxed apps run by an **admin** user don't need it (Quinn, [666679](https://developer.apple.com/forums/thread/666679)). Sandboxed apps get "Connection to logd failed". Cirrus likewise needs an admin user for its log features.

```swift
import OSLog
let store = try OSLogStore(scope: .system)                       // admin user, non-sandboxed
let since = store.position(date: Date().addingTimeInterval(-3600))
let pred = NSPredicate(format: "subsystem IN %@ OR process IN %@",
    ["com.apple.FileProvider", "com.apple.clouddocs", "com.apple.cloudkit", "com.apple.mmcs"],
    ["bird", "cloudd", "fileproviderd"])
for case let e as OSLogEntryLog in try store.getEntries(at: since, matching: pred) {
    // match e.composedMessage against the item's filename / FileProvider item id
}
```

---

## 5. TCC / privacy

| Location | Prompt / requirement | Confidence |
|---|---|---|
| `~/Library/Mobile Documents/com~apple~CloudDocs/**` (plain iCloud Drive) | Non-sandboxed read works (DTS demo). No Files & Folders category covers it in Apple's user guide. | VERIFIED read; "no prompt" is REPORTED (icloud-tools, halo-mac) |
| `~/Desktop`, `~/Documents` (also when "Desktop & Documents Folders" is in iCloud) | Files & Folders TCC (`kTCCServiceSystemPolicyDesktopFolder` / `...DocumentsFolder`) prompts on first access. Apple's macOS 27 guide lists Desktop, Downloads, Documents ([Apple Support](https://support.apple.com/guide/mac-help/control-access-to-files-and-folders-on-mac-mchld5a35146/mac)). Add `NSDesktopFolderUsageDescription` / `NSDocumentsFolderUsageDescription` to Info.plist (key names not re-fetched this session). **Whether reading the same files via `CloudDocs/Desktop` also triggers the prompt: UNVERIFIED.** | Partly VERIFIED |
| `kTCCServiceUbiquity` ("iCloud" access) | Applies to apps that *use* iCloud through entitlements. On Tahoe, denying it leaves no Settings UI; recovery needs `tccutil reset All <bundle-id>` (FB22746525, [827374](https://developer.apple.com/forums/thread/827374)). Not triggered by plain file reads as far as found. | REPORTED |
| `kTCCServiceFileProviderDomain` | A TCC service for access to File Provider–managed files exists. When it prompts for iCloud Drive: **UNVERIFIED**. | UNVERIFIED |
| **macOS 27** | (a) Cross-team `~/Library/Containers/*` and `~/Library/Group Containers/*` access now **fails silently with no prompt** ([blakecrosley](https://blakecrosley.com/blog/macos-27-cross-team-container-access)). (b) `com.apple.macl` protection now covers `~/Library/Application Support/<name>` for a hand-picked set of non-sandboxed apps, hardcoded in sandboxd and updatable via XProtect. Full Disk Access reportedly does **not** override it ([mjtsai](https://mjtsai.com/blog/2026/07/24/golden-gate-application-support-protection/)). Whether `~/Library/Application Support/CloudDocs` or `FileProvider` is on that list: **UNVERIFIED**. | REPORTED |

**Design:** treat `EPERM` on any path as "needs permission", not "missing". Offer optional Full Disk Access (it can't be requested programmatically; send the user to System Settings). Never assume Full Disk Access unlocks macOS 27–protected folders.

---

## 6. Documented causes of stuck or unsyncable items (with detectors)

| Cause | Detector | Source |
|---|---|---|
| Item over **50 GB** (file or folder) → "Ineligible" | `fileSize` / folder total > 50 GB | [Apple Support](https://support.apple.com/guide/mac-help/mchlc994344b/mac) (macOS 15/26/27 page) |
| **iCloud storage full** → "Out of Space" | `ubiquitousItemUploadingError`: `NSCocoaErrorDomain` 4354 `NSUbiquitousFileNotUploadedDueToQuotaError` (`CocoaError.ubiquitousFileNotUploadedDueToQuota`), or `NSFileProviderErrorDomain` -1003 `insufficientQuota`; `brctl quota` | Apple Support; [go-bindings raw values](https://pkg.go.dev/github.com/deploymenttheory/go-bindings-macosplatform/bindings/frameworks/fileprovider) |
| Server unreachable | 4355 `NSUbiquitousFileUbiquityServerNotAvailable` / FP -1004 `serverUnreachable` | same |
| Generic sync failure | FP **-2005 `cannotSynchronize`** (Quinn confirmed -2005 = CannotSynchronize, [740765](https://developer.apple.com/forums/thread/740765)) | VERIFIED |
| Other FP codes | -2007 `unsyncedEdits`, -2008 `nonEvictable`, -2006 `nonEvictableChildren`, -2011 `domainDisabled`, -2012 `providerDomainTemporarilyUnavailable`, -2015 `localVersionConflictingWithServer`, `excludedFromSync` (raw value UNVERIFIED). Match on `NSFileProviderError.Code` symbols, not raw ints. | [Apple enum](https://developer.apple.com/documentation/fileprovider/nsfileprovidererror/code) |
| **Packages failed to sync on macOS 26.2** (-2005; `.xcodeproj`, `.pages`, `.numbers`, bundles). Fixed in 26.3 (FB21363976, FB21663069). | `isPackage` + OS build | [810671](https://developer.apple.com/forums/thread/810671) |
| **BSD flags**: `schg`, `sappnd`, `uappnd` → "failed to sync to iCloud Drive". `uchg` (Locked) is silently stripped (macOS 26.5). | `lstat` `st_flags` & `SF_IMMUTABLE`/`SF_APPEND`/`UF_APPEND`. Fix: `chflags nouappnd`. `schg`/`sappnd` need root. | [Oakley 2026-06-02](https://eclecticlight.co/2026/06/02/bsd-flags-are-incompatible-with-icloud-drive/) |
| **Excluded by design**: `.nosync`, `.tmp` names/folders, plus the auto-exclusion list in §1.4 | name rules | [Oakley 2026-01-06](https://eclecticlight.co/2026/01/06/exclude-or-include-items-in-backup-search-icloud-drive-and-quicklook-preview/) |
| xattr `com.apple.fileprovider.ignore#P` marks an item non-syncing | `listxattr` | REPORTED ([icloud-nosync](https://github.com/edtadros/icloud-nosync)). Undocumented. |
| High-churn trees (git repos, `node_modules`, deep nesting) → endless "waiting to upload" | file count, `.git` present | [forum 651829](https://developer.apple.com/forums/thread/651829) (user reports) |
| macOS 26.4.1 HTTP/3 deadlock (all larger uploads hang) | log grep in §4 | [822534](https://developer.apple.com/forums/thread/822534) |
| FileProvider DB corruption (fileproviderd at 70–95% CPU, "Possible slow statement on SELECT", "scheduler not stable") | `ps` CPU + log strings | [837682](https://developer.apple.com/forums/thread/837682), [flohgro](https://flohgro.com/blog/fixing-fileproviderd-on-macos-tahoe/) |
| Custom-icon `Icon\r` files → "Ineligible" | name | [Oakley](https://eclecticlight.co/2023/07/25/why-dont-custom-icons-work-properly-in-icloud-drive/) |
| Symlinks | Reports that only the link state at creation time syncs (Apple Community). FileProvider behavior: **UNVERIFIED**. Flag them as "may not sync as expected". | weak |
| Illegal or problematic **file-name characters** / length | **UNVERIFIED.** No primary source found. Only anecdotal forum speculation. | — |
| Files open or locked by an app | **UNVERIFIED** as a documented cause. `pauseSync` returning `EBUSY` shows the provider serializes item changes. | — |
| Metadata loss (not a stall, but it affects "recovery") | Only Finder tags, `com.apple.lastuseddate#PS`, `com.apple.quarantine`, `com.apple.TextEncoding` and `#S`-flagged xattrs sync. Finder comments and most `com.apple.metadata:kMDItem*` are lost (macOS 26.4.1). `com.apple.ResourceFork` is always stripped. | [Oakley 2026-05-11](https://eclecticlight.co/2026/05/11/does-icloud-drive-now-lose-almost-all-metadata/), [2020](https://eclecticlight.co/2020/03/18/which-extended-attributes-does-icloud-preserve-and-which-get-stripped/) |

---

## 7. Safe recovery algorithm

Expert baseline (Howard Oakley):
- Make local copies of important documents outside iCloud Drive before any fix ([2021](https://eclecticlight.co/2021/12/03/what-to-do-when-icloud-gets-stuck/)).
- Moving stuck files out "can let the rest of the sync complete". Then move them back "one at a time … giving each time to sync completely before moving the next" ([2023](https://eclecticlight.co/2023/07/24/how-to-fix-problems-with-icloud-and-icloud-drive/)).
- Test sync with a 1 MB probe file (Cirrus "Test Upload", `co.eclecticlight.Cirrus.data`) ([2026-08-26](https://eclecticlight.co/2026/08/26/test-icloud-drive-using-cirrus/)).
- Be patient; avoid toggling settings ([2026-04-06](https://eclecticlight.co/2026/04/06/understanding-and-testing-icloud/)).
- Community workarounds such as rename-in-place and zip/unzip are REPORTED only ([651829](https://developer.apple.com/forums/thread/651829)).

**Algorithm (the app never deletes anything the user can't get back):**

1. **Triage (read-only).** Run the scan (§1.3) and classifier (§1.4). Run a global health probe: write a 1 MB visible file (e.g. `"<App> Sync Test.dat"`) into CloudDocs and poll `ubiquitousItemIsUploaded` every 2 s, calling `removeAllCachedResourceValues()` each time.
   - If the probe doesn't upload within about 60 s, **sync is globally stalled**. Don't touch individual files. Show the daemon/network diagnosis instead (HTTP/3 signature, fileproviderd CPU, `brctl status`).
   - Clean up the probe with `trashItem`.
2. **Preflight per item.** The item must be **local**: not `SF_DATALESS`, `totalFileAllocatedSize > 0`. A never-uploaded file only exists locally, which makes it the critical case. Free space must be at least 2× the item size. The item must not be `isUploading`. Record `st_flags`, the xattr list, Finder tags, dates and POSIX mode.
3. **Rescue copy.** Do a coordinated read (`NSFileCoordinator().coordinate(readingItemAt:options:[.withoutChanges])`). Copy with `FileManager.copyItem` into `~/Library/Application Support/<App>/Rescue/<ISO-date>/`. That location is outside iCloud and outside Desktop/Documents, which may themselves be in iCloud. For packages, copy the whole bundle.
4. **Export local versions.** `NSFileVersion.otherVersionsOfItem(at:)`, copying each `version.url`. Versions are per-Mac and don't survive every move (UNVERIFIED for same-volume moves), so this is conservative.
5. **Verify.** Stream SHA-256 (CryptoKit) of the original and the copy. For packages, build a manifest `{relativePath: sha256}` and compare it. **Abort on any mismatch.**
6. **Remediation ladder** (least invasive first; re-run the classifier after each step and stop when `isUploaded == true`):
   - **a. Fix the root cause** if one was detected: clear `uappnd`/`uchg` with `chflags` (user flags only); rename `.tmp`/`.nosync` names only if the user wants them synced; split or zip over-50 GB items; ask the user to free iCloud quota.
   - **b. Nudge:** a coordinated rename in place (`name` → `name (resync)` → `name`). REPORTED workaround only.
   - **c. macOS 26+ only**, if `ubiquitousItemSupportedSyncControls` contains `.pauseSync` (packages only; not plain folders): pause, then `uploadLocalVersionOfUbiquitousItem(... .conflictPolicyFailOnConflict)`, then `resumeSync(.preserveLocalChanges)`. Journal the pause first. UNVERIFIED for iCloud Drive and a non-entitled caller.
   - **d. Oakley method:** coordinated `moveItem` of the item *out* to the local rescue folder, and wait for the rest of the sync to settle (probe succeeds). Then move items back **one at a time**. After each one, wait for `isUploaded == true` and re-hash in place.
   - **e. Guided daemon restart** (user clicks, the app runs `killall bird`, or the user-level cloudd/nsurlsessiond kill only when the 26.4.1 HTTP/3 signature is present).
   - **f. Instructions only**, never automated: sign out of iCloud or toggle iCloud Drive.
7. **Retention.** Keep rescue copies for at least 30 days. Delete only with `trashItem` and only after the user confirms. Keep a JSON audit log of every action with paths and hashes.

```swift
import CryptoKit
func sha256(_ url: URL) throws -> String {
    let h = try FileHandle(forReadingFrom: url); defer { try? h.close() }
    var hasher = SHA256()
    while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

func coordinatedCopy(_ src: URL, into dir: URL) throws -> URL {
    var coordError: NSError?
    var result: Result<URL, Error> = .failure(CocoaError(.fileReadUnknown))
    NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: src, options: [.withoutChanges], error: &coordError) { readURL in
        let dst = dir.appendingPathComponent(src.lastPathComponent)
        result = Result { try FileManager.default.copyItem(at: readURL, to: dst); return dst }
    }
    if let coordError { throw coordError }
    return try result.get()
}
// Rule: never call removeItem under CloudDocs. Use trashItem(at:resultingItemURL:) after hashes match.
```

---

## 8. Build and test implications (Windows dev + GitHub Actions)

- All APIs above are in Foundation/Darwin/OSLog/CryptoKit. No extra frameworks are needed. Use `if #available(macOS 26, *)` for the sync-control APIs.
- Hardened runtime + notarization: none of these calls needs a special entitlement. Do **not** add `com.apple.logging.local-store` (it causes "Unsatisfied entitlements").
- CI can only run unit tests of `classify()` against `URLResourceValues`-like fixtures (wrap them in your own struct so they can be constructed) and of name-exclusion rules and hashing. Real sync behavior needs a physical Mac signed into iCloud on macOS 14, 15, 26 and 27. Recruit beta testers or rent a remote Mac.

## 9. Open items to verify on real hardware
1. On macOS 26/27, is `ubiquitousItemDownloadingStatus` / `IsUploaded` nil for a Developer ID app bundle, and not just a CLI/launchd agent? And do `IsUploaded` / `UploadingError` populate for stuck files?
2. Does reading `CloudDocs/Desktop` and `CloudDocs/Documents` trigger the Desktop/Documents TCC prompt?
3. Do the macOS 26 `pauseSync` / `uploadLocalVersion` calls work on iCloud Drive items from a non-entitled app?
4. Which `brctl` subcommands exist on 27, and which need sudo? Capture `brctl --help` on each OS in the beta.
5. Is `~/Library/Application Support/CloudDocs` or `FileProvider` on macOS 27's protected list?
