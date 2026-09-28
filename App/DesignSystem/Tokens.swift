import AppKit
import SwiftUI
import WhydunitCore

/// Spacing in points (UI_SPEC §2.1). `l` is the window and sheet padding.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

/// docs/MOTION.md §1.2 and §3.1.
enum Motion {
    /// Opacity-only and shorter when Reduce Motion is on.
    static func standard(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .smooth(duration: 0.28)
    }
    /// Surfaces: flips, card swaps, a tilt settling back.
    static func spring(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .spring(duration: 0.45, bounce: 0.22)
    }
    /// One-time entrances.
    static let hero = Animation.spring(duration: 0.9, bounce: 0.2)
    /// Small things landing: symbols, chevrons.
    static let pop = Animation.spring(duration: 0.32, bounce: 0.38)
    /// Following the pointer: quick, no overshoot.
    static let follow = Animation.interactiveSpring(response: 0.25, dampingFraction: 0.86)
    /// Between rows that arrive together.
    static let stagger = 0.045
}

extension View {
    /// Rows that arrive together turn down into place from their top edge, one `Motion.stagger` apart (index capped
    /// at 8). Opacity only under Reduce Motion.
    func flipIn(_ shown: Bool, index: Int, reduceMotion: Bool) -> some View {
        // VERIFY sign on a Mac: the bottom edge should start toward the viewer.
        rotation3DEffect(.degrees(shown || reduceMotion ? 0 : 70), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
            .opacity(shown ? 1 : 0)
            .animation(Motion.spring(reduceMotion).delay(Double(min(index, 8)) * Motion.stagger), value: shown)
    }

    /// A symbol in a recessed, tinted squircle: the site's icon well. Pure fills, so ImageRenderer-safe.
    func well(_ tint: Color, size: CGFloat = 44) -> some View {
        modifier(Well(tint: tint, size: size))
    }

    /// A raised object (app icon, report card; never a row): a tight contact shadow plus a wide soft one.
    /// compositingGroup so glyphs don't cast their own shadows (MOTION.md §1.4).
    func lifted() -> some View {
        compositingGroup()
            .shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
            .shadow(color: .black.opacity(0.20), radius: 24, y: 14)
    }

    /// System Settings tile: a white symbol on a rounded square of one colour. Sidebar rows and SeverityIcon(tile:).
    func tile(_ color: Color, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        return font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: shape)
            .overlay { shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.5) }
    }
}

private struct Well: ViewModifier {
    let tint: Color
    let size: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        let strong = contrast == .increased
        content
            .frame(width: size, height: size)
            .background(tint.opacity(0.16).gradient, in: shape)
            .overlay { shape.strokeBorder(strong ? Color.primary : tint.opacity(0.24), lineWidth: strong ? 1 : 0.5) }
    }
}

extension AnyTransition {
    /// A sheet's steps: the old step turns away to the left, the new one turns in from the right.
    static func cardSwap(_ reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: Turn(angle: -28, anchor: .trailing, x: 40, opacity: 0), identity: Turn(anchor: .trailing)),
            removal: .modifier(active: Turn(angle: 28, anchor: .leading, x: -40, opacity: 0), identity: Turn(anchor: .leading)))
    }
}

private struct Turn: ViewModifier {
    var angle = 0.0
    var anchor: UnitPoint
    var x: CGFloat = 0
    var opacity = 1.0

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: anchor, perspective: 0.5)
            .offset(x: x)
            .opacity(opacity)
    }
}

/// Turns a surface to face the pointer (the edge under it recedes), at most `max` degrees, with an optional glare
/// masked to the content's own shape. Flat under Reduce Motion. The pointer is read in the layout frame, so the
/// tilt never moves hit areas. At most 8 on screen (MOTION.md §1.6).
struct HoverTilt: ViewModifier {
    var max = 7.0
    var glare = false
    @State private var size = CGSize.zero
    @State private var p = CGPoint.zero          // -1...1 from the center
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let q = reduceMotion ? .zero : p          // Reduce Motion switched on mid-hover: flat at once
        content
            .overlay {
                if glare && hovering && !reduceMotion {
                    RadialGradient(colors: [.white.opacity(0.28), .clear], center: .center,
                                   startRadius: 0, endRadius: size.width * 0.6)
                        .offset(x: q.x * size.width / 2, y: q.y * size.height / 2)
                        .mask { content }            // VERIFY: content drawn twice; fine for an icon and one card
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            // VERIFY on a Mac: the edge under the pointer should recede; negate both angles if it rises instead.
            .rotation3DEffect(.degrees(-Double(q.y) * max), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(q.x) * max), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onContinuousHover { phase in
                guard !reduceMotion, size.width > 0, size.height > 0 else { return }
                switch phase {
                case .active(let at):
                    withAnimation(Motion.follow) {
                        hovering = true
                        p = CGPoint(x: at.x / size.width * 2 - 1, y: at.y / size.height * 2 - 1)
                    }
                case .ended:
                    withAnimation(Motion.spring(false)) {
                        hovering = false
                        p = .zero
                    }
                }
            }
    }
}

/// A count or a word in a tinted capsule. Colour sits in the dot and the fill; the text stays primary, so it always
/// has full contrast. Increase Contrast adds a stroke.
struct Tag: View {
    let text: String
    var tint: Color = .secondary
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let strong = contrast == .increased
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(text).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay { Capsule().strokeBorder(strong ? Color.primary.opacity(0.4) : tint.opacity(0.3), lineWidth: strong ? 1 : 0.5) }
    }
}

extension Tag {
    /// `Tag("Verified", tint: .green)` as well as `Tag(text:tint:)`.
    init(_ text: String, tint: Color = .secondary) { self.init(text: text, tint: tint) }
}

/// Daylight on the top of a stage screen: the accent at 9% (16% in dark) fading out over 240pt. Static, never
/// animated, never keyed to a verdict. Increase Contrast gets the plain window.
struct Sky: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
            if contrast != .increased {
                LinearGradient(colors: [Color.accentColor.opacity(scheme == .dark ? 0.16 : 0.09), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A sheet's first lines: the action's symbol in a well, the title, one sentence. The same in all three sheets.
struct SheetHeader: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(.tint)
                .well(.accentColor, size: 48).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(title).font(.title2.weight(.bold))
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension Severity {
    /// `.info` is gray, not blue: blue already means "clickable" (accent).
    var color: Color {
        switch self {
        case .ok: .green
        case .unknown, .info: .secondary
        case .warning: .orange
        case .critical: .red
        }
    }

    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }
}

extension FixAction {
    /// Title case, verb first. Back Up, Retry Upload and Restart iCloud Sync open a sheet, so their buttons add "…".
    var actionTitle: String {
        switch self {
        case .backUp: "Back Up"
        case .retryUpload: "Retry Upload"
        case .restartSync: "Restart iCloud Sync"
        case .openICloudSettings: "Open iCloud Settings"
        case .openPrivacySettings: "Open Privacy Settings"
        case .showInFinder: "Show in Finder"
        case .copyCommand: "Copy Command"
        }
    }
}

/// "1 item", "4,213 items".
func itemCount(_ n: Int) -> String { n == 1 ? "1 item" : "\(n.formatted()) items" }
