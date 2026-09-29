import AppKit
import SwiftUI

/// The never-scanned state is the whole onboarding: icon, one sentence, what we touch, one button (DESIGN.md §5.2).
struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: Space.m) {
            // The one lifted object: the icon standing on the dawn horizon, its reflection tilting with it. It arrives
            // in 3D once (MOTION.md §3.2); the floor line and its pool of light stay still and only fade in.
            OnFloor(height: 128) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128)
            }
            .modifier(HoverTilt(max: 8, glare: true))     // glare masked to the icon and its reflection
            .rotation3DEffect(.degrees(shown || reduceMotion ? 0 : 35), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .opacity(shown ? 1 : 0)
            .background(alignment: .top) {
                // Horizon's line runs through its middle (360 × 0.32 = 115pt tall): here, on the icon's base at 128pt.
                Horizon(tint: .accentColor, width: 360)
                    .offset(y: 128 - 58)
                    .opacity(shown ? 1 : 0)
            }
            .accessibilityHidden(true)
            Text("Find out which iCloud Drive files are stuck, and why.")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)   // wraps to two lines at the 1000pt minimum
            Text("Nothing about your files leaves this Mac. Whydunit reads file status, never file contents, and checks sync by uploading one small test file, which it then moves to the Trash.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440)
            Button("Scan iCloud Drive") { store.scan() }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)
                .padding(.top, Space.xs)
            ViewThatFits {
                HStack(spacing: Space.l) { facts }
                VStack(spacing: Space.xs) { facts }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, Space.xs)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 480)
        .padding(Space.xxl)
        // Centred a little above the middle (~45% of the default window's height), where the eye lands.
        .padding(.bottom, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Sky() }
        .onAppear { withAnimation(reduceMotion ? Motion.standard(true) : Motion.hero) { shown = true } }
    }

    /// The site's safety cards, in one quiet row.
    @ViewBuilder private var facts: some View {
        Label("Reads status, not contents", systemImage: "doc.text.magnifyingglass")
        Label("Backs up first", systemImage: "externaldrive.badge.checkmark")
        Label("Trash, never delete", systemImage: "trash")
    }
}
