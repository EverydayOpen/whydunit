import Sparkle
import SwiftUI

/// Sparkle 2 wrapper. The feed URL and EdDSA public key come from Info.plist (SUFeedURL, SUPublicEDKey).
@MainActor final class Updater: ObservableObject {
    static let shared = Updater()

    /// Sparkle starts only with a real EdDSA public key (32 bytes, base64). Dev builds carry the placeholder, so they
    /// never start it and never show its "updater failed to start" alert (BUILD_PLAN §9.5).
    nonisolated static let isConfigured = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
        .flatMap { Data(base64Encoded: $0) }?.count == 32

    @Published var canCheckForUpdates = false
    private let controller = SPUStandardUpdaterController(startingUpdater: Updater.isConfigured, updaterDelegate: nil, userDriverDelegate: nil)

    private init() {
        // Stays false while the updater isn't started, which keeps the menu item disabled.
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() { controller.updater.checkForUpdates() }
}

/// "Check for Updates…" menu item, disabled while Sparkle can't check (during a check, or in a dev build).
struct CheckForUpdatesView: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
            // VERIFY: SwiftUI shows `.help` as the menu item's tooltip on macOS 15 and 26.
            .help(Updater.isConfigured ? "Look for a newer version of Whydunit" : "Updates turn on in release builds")
    }
}
