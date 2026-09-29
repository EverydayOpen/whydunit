import SwiftUI

/// One step of a sheet as one card, so the step swap turns it as a whole (MOTION.md §3.5). Pass the sheet's
/// `accessibilityReduceMotion`: the swap is a fade then.
@MainActor func sheetStep<C: View>(_ reduceMotion: Bool, @ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: Space.m, content: content)
        .transition(.cardSwap(reduceMotion))
}

/// Where a sheet is in its steps, in its top-right corner: the current step a short tinted bar, the others dots.
/// Visual only; each step's header already says where you are.
struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: i == current ? 18 : 6, height: 6)
            }
        }
        .padding(.top, 28)   // on SheetHeader's title line (title2 is 17pt on macOS). VERIFY by eye.
        .padding(.trailing, Space.l)
        .accessibilityHidden(true)
    }
}

/// A sheet's preflight: its safety checks as mono facts, recessed into the sheet rather than raised (DESIGN.md §5.2).
struct SafetyChecks<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: Space.xs) { content }
            .font(.system(.callout, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s)
            .background(Color.primary.opacity(0.04), in: shape)
            // A 4% fill vanishes under Increase Contrast; the stroke keeps the group (DESIGN.md §3.3).
            .overlay { if contrast == .increased { shape.strokeBorder(Color.primary.opacity(0.5), lineWidth: 1) } }
    }
}

/// One condition: a green check when it holds, otherwise the given gray symbol (our own limits are gray, never red:
/// UI_SPEC §2.5). The words say which, so VoiceOver skips the symbol.
struct SafetyCheck: View {
    let text: String
    var unmet: String? = nil

    var body: some View {
        Label {
            Text(text).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: unmet ?? "checkmark.circle.fill")
                .foregroundStyle(unmet == nil ? Color.green : Color.secondary)
                .accessibilityHidden(true)
        }
    }
}
