import AppKit
import SwiftUI

/// The never-scanned state is the whole onboarding: icon, one sentence, what we touch, one button.
struct WelcomeView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: Space.m) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Find out which iCloud Drive files are stuck, and why.")
                .font(.title2.weight(.semibold))
            Text("Nothing about your files leaves this Mac. Whydunit reads file status, never file contents, and checks sync by uploading one small test file, which it then moves to the Trash.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Scan iCloud Drive") { store.scan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, Space.xs)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
