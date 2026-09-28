import SwiftUI
import WhydunitCore

/// The only view that draws a severity. VoiceOver always hears the word; with Differentiate Without Color
/// the word is shown too, except where `showsWord` is off (sidebar and list rows: the symbols differ in shape).
struct SeverityIcon: View {
    let severity: Severity
    /// nil inherits the font.
    var size: CGFloat? = 16
    var showsWord = true
    /// A System Settings tile (white symbol on the severity's colour, gray for info and unknown). Needs a size, and
    /// keeps its colour on a selected row, as in System Settings.
    var tile = false
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    /// Increased on a selected row with an accent fill, where every other icon turns white.
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: Space.xxs) {
            if tile, let size {
                Image(systemName: severity.symbol)
                    .tile(severity == .info || severity == .unknown ? .gray : severity.color, size: size)
            } else {
                Image(systemName: severity.symbol)
                    .font(size.map { Font.system(size: $0, weight: .semibold) })
                    .fontWeight(.semibold)
                    .foregroundStyle(prominence == .increased ? AnyShapeStyle(.foreground) : AnyShapeStyle(severity.color))
            }
            if differentiate && showsWord {
                Text(severity.word).font(.caption.weight(.semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(severity.word)
    }
}

/// Bordered list of item names and folders with a trailing detail, used inside the action sheets. Whole rows only,
/// at most four tall; the folder reads as in the finding's table ("iCloud Drive › Finance").
struct ItemList<Trailing: View>: View {
    let paths: [String]
    @ViewBuilder let trailing: (String) -> Trailing
    @Environment(AppStore.self) private var store

    var body: some View {
        List(paths, id: \.self) { path in
            HStack(spacing: Space.xs) {
                // The folder too, so two items with the same name can be told apart.
                VStack(alignment: .leading, spacing: 2) {
                    Text((path as NSString).lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(store.itemsByPath[path]?.displayFolder
                         ?? ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .help(path)
                Spacer(minLength: Space.xs)
                trailing(path)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(height: CGFloat(min(paths.count, 4)) * 40 + 2)   // VERIFY the 40pt row height on a Mac
    }
}

#Preview {
    HStack(spacing: Space.m) {
        ForEach(Severity.allCases, id: \.self) { SeverityIcon(severity: $0) }
        ForEach(Severity.allCases, id: \.self) { SeverityIcon(severity: $0, size: 24, tile: true) }
    }
    .padding(Space.l)
}
