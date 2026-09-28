import AppKit
import SwiftUI

/// The never-scanned state is the whole onboarding: icon, one sentence, what we touch, one button (DESIGN.md §5.2).
struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: Space.m) {
            ZStack {
                // The still contact shadow the icon rests on: blurred once, never animated (only faded in).
                Ellipse()
                    .fill(.black.opacity(0.18))
                    .frame(width: 84, height: 10)
                    .blur(radius: 8)
                    .offset(y: 62)
                    .opacity(shown ? 1 : 0)
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .modifier(HoverTilt(max: 12, glare: true))     // glare masked to the icon's own shape
                    .rotation3DEffect(.degrees(shown || reduceMotion ? 0 : 35), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.85)
                    .offset(y: shown || reduceMotion ? 0 : 16)
                    .opacity(shown ? 1 : 0)
            }
            .padding(.bottom, Space.xs)
            .accessibilityHidden(true)
            Text("Find out which iCloud Drive files are stuck, and why.")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
            Text("Nothing about your files leaves this Mac. Whydunit reads file status, never file contents, and checks sync by uploading one small test file, which it then moves to the Trash.")
                .font(.callout)
                .foregroundStyle(.secondary)
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
