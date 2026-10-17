//
//  GuestTheme.swift
//  Maqr
//
//  The guest pages' look, shared by the App Clip and the app: the theme
//  resolver of the engine (src/engine/theme.ts in maqr-server) as SwiftUI
//  environment values. Blocks never name a colour — they read ``GuestPaint``,
//  so the same section is gold on dark glass in a wedding and ink on white
//  cards on a brand page, in the author's own primary colour either way.
//

import DesignerFoundation
import GuestExperience
import SwiftUI

// MARK: - Colours

extension Color {
    /// A `#rrggbb` the experience holds, or `fallback`.
    init(guestHex hex: String, fallback: Color = .clear) {
        if let rgb = RGBColor.parse(hex) {
            self.init(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
        } else {
            self = fallback
        }
    }
}

/// The tokens a page draws with — `SURFACES` in src/engine/theme.ts, with the
/// author's primary colour over the surface's own.
struct GuestPaint {
    let surface: GuestLook.Surface
    /// The author's colour — gold on a wedding nobody has recoloured.
    let primary: Color
    /// What sits on ``primary``.
    let onPrimary: Color
    let text: Color
    /// The colour the page itself is, under any background the author set.
    let page: Color

    init(look: GuestLook? = nil) {
        surface = look?.surface ?? .glassDark
        primary = Color(guestHex: look?.primary ?? GuestPalette.gold)
        switch surface {
        case .glassDark:
            onPrimary = Color(guestHex: GuestPalette.ink)
            text = Color(guestHex: "#f5f0e6")
            page = Color(guestHex: GuestPalette.ink)
        case .cardLight:
            onPrimary = .white
            text = Color(guestHex: "#1c1c1c")
            page = Color(guestHex: "#f6f6f4")
        }
    }

    var isDark: Bool { surface == .glassDark }
    var soft: Color { text.opacity(isDark ? 0.74 : 0.66) }
    var faint: Color { text.opacity(isDark ? 0.56 : 0.48) }
    var hairline: Color { isDark ? primary.opacity(0.3) : Color.black.opacity(0.08) }
    var rule: Color { text.opacity(0.1) }
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    /// The body face: Palatino on dark glass, as the wedding page set it; the
    /// system's on cards.
    func body(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        isDark ? .custom("Palatino", size: size, relativeTo: style) : .system(size: size)
    }
}

private struct GuestPaintKey: EnvironmentKey {
    static let defaultValue = GuestPaint()
}

private struct GuestFamilyKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var guestPaint: GuestPaint {
        get { self[GuestPaintKey.self] }
        set { self[GuestPaintKey.self] = newValue }
    }

    /// The family headings are set in, or empty for the system's.
    var guestFamily: String {
        get { self[GuestFamilyKey.self] }
        set { self[GuestFamilyKey.self] = newValue }
    }
}

extension View {
    /// Everything a page needs to paint itself in an experience's look.
    func guestLook(_ look: GuestLook) -> some View {
        let paint = GuestPaint(look: look)
        return environment(\.guestPaint, paint)
            .environment(\.guestFamily, look.displayFamily)
            .environment(\.colorScheme, paint.colorScheme)
            .tint(paint.primary)
    }
}

// MARK: - Type

/// The heading face: the author's family once it has been registered, a
/// serif until then — so a page never waits on a font to be read.
struct DisplayFont: ViewModifier {
    let size: CGFloat
    var relativeTo: Font.TextStyle = .title
    @Environment(\.guestFamily) private var family
    @Environment(\.guestPaint) private var paint

    func body(content: Content) -> some View {
        let fonts = GuestFonts.shared
        if !family.isEmpty, fonts.isAvailable(family) {
            content.font(.custom(family, size: size, relativeTo: relativeTo))
        } else if paint.isDark {
            content.font(.system(size: size * 0.92, weight: .regular, design: .serif).italic())
        } else {
            content.font(.system(size: size * 0.85, weight: .bold))
        }
    }
}

extension View {
    func displayFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> some View {
        modifier(DisplayFont(size: size, relativeTo: style))
    }

    /// An author's text style over a field's own look — weight, slant,
    /// lines, alignment, colour, and the face and size, which replace the
    /// field's own only where the author set them, as `useTextStyles`
    /// spreads them last on the web. `pageShadow` is the field's own shadow,
    /// drawn unless the author turned it off or chose one of theirs.
    func guestFormat(
        _ format: TextFormat, size: CGFloat, face: GuestFace, relativeTo style: Font.TextStyle = .title,
        pageShadow: GuestShadow? = nil
    ) -> some View {
        modifier(GuestFormat(format: format, size: size, face: face, relativeTo: style))
            .textShadow(format.shadow, page: pageShadow)
    }

    /// A text style's shadow: the page's own (`page`, if any), none, or the
    /// author's — CSS's blur radius halved, which is how far SwiftUI's
    /// radius spreads the same shadow.
    func textShadow(_ setting: TextShadowSetting, page: GuestShadow? = nil) -> some View {
        let shadow: GuestShadow? = switch setting {
        case .page: page
        case .off: nil
        case .custom(let custom):
            GuestShadow(
                color: Color(guestHex: custom.color).opacity(Double(custom.opacity) / 100),
                radius: CGFloat(custom.blur) / 2, x: CGFloat(custom.x), y: CGFloat(custom.y))
        }
        let drawn = shadow ?? GuestShadow(color: .clear, radius: 0, x: 0, y: 0)
        return self.shadow(color: drawn.color, radius: drawn.radius, x: drawn.x, y: drawn.y)
    }
}

/// A shadow under text.
struct GuestShadow {
    var color: Color
    var radius: CGFloat
    var x: CGFloat = 0
    var y: CGFloat = 0
}

/// The face a field is set in when its author has not chosen one.
enum GuestFace {
    /// The experience's heading face.
    case display
    /// The surface's body face.
    case body
}

struct GuestFormat: ViewModifier {
    let format: TextFormat
    let size: CGFloat
    let face: GuestFace
    let relativeTo: Font.TextStyle
    @Environment(\.guestFamily) private var family
    @Environment(\.guestPaint) private var paint

    func body(content: Content) -> some View {
        let alignment: TextAlignment? = switch format.align {
        case "left": .leading
        case "right": .trailing
        case "center": .center
        default: nil
        }
        content
            .font(font)
            .bold(format.bold)
            .italic(format.italic)
            .underline(format.underline)
            .strikethrough(format.strikethrough)
            .modifier(OptionalAlignment(alignment: alignment))
            .modifier(OptionalColor(hex: format.color))
    }

    /// One font, decided here, so nothing set around the text overrides it.
    private var font: Font {
        let fonts = GuestFonts.shared
        let size = format.size.map { CGFloat($0) } ?? self.size
        if !format.font.isEmpty, fonts.isAvailable(format.font) {
            return .custom(format.font, size: size, relativeTo: relativeTo)
        }
        switch face {
        case .display:
            if !family.isEmpty, fonts.isAvailable(family) { return .custom(family, size: size, relativeTo: relativeTo) }
            return paint.isDark ? .system(size: size * 0.92, design: .serif).italic() : .system(size: size * 0.85, weight: .bold)
        case .body:
            return paint.body(size, relativeTo: relativeTo)
        }
    }
}

private struct OptionalAlignment: ViewModifier {
    let alignment: TextAlignment?
    func body(content: Content) -> some View {
        if let alignment {
            content.multilineTextAlignment(alignment).frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
        } else {
            content
        }
    }
}

private struct OptionalColor: ViewModifier {
    let hex: String
    func body(content: Content) -> some View {
        if RGBColor.parse(hex) != nil { content.foregroundStyle(Color(guestHex: hex)) } else { content }
    }
}

extension TextAlignment {
    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .trailing: .trailing
        case .center: .center
        }
    }
}

// MARK: - Pieces

/// The rule with a diamond at its centre — the one flourish, under every
/// heading and between the chapters of the story.
struct Ornament: View {
    @Environment(\.guestPaint) private var paint

    var body: some View {
        HStack(spacing: 10) {
            LinearGradient(colors: [.clear, paint.primary], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40, height: 1)
            Rectangle().fill(paint.primary).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            LinearGradient(colors: [paint.primary, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40, height: 1)
        }
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }
}

/// How a section introduces itself.
struct PageHeading: View {
    let title: String
    var subtitle: String?
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .displayFont(34)
                .foregroundStyle(paint.primary)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(paint.isDark ? 0.35 : 0), radius: 12, y: 2)
                .reveal()
            Ornament().reveal(delay: 0.08)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(paint.body(17))
                    .italic(paint.isDark)
                    .foregroundStyle(paint.soft)
                    .multilineTextAlignment(.center)
                    .reveal(delay: 0.14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

/// The host's portrait in a ring of their colour.
struct Portrait: View {
    let url: URL?
    var size: CGFloat = 128
    @Environment(\.guestPaint) private var paint

    var body: some View {
        GuestImage(url: url, placeholder: "heart.fill")
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(paint.primary, lineWidth: 2))
            .padding(4)
            .background(Circle().fill(paint.isDark ? Color.black.opacity(0.55) : Color.white))
            .shadow(color: .black.opacity(paint.isDark ? 0.6 : 0.15), radius: 20, y: 12)
    }
}

/// A picture from the experience: fades in when it arrives.
struct GuestImage: View {
    let url: URL?
    var placeholder = "photo"
    var contentMode: ContentMode = .fill
    @Environment(\.guestPaint) private var paint

    var body: some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.5))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: contentMode).transition(.opacity)
                case .failure:
                    fallback
                default:
                    Rectangle().fill(paint.text.opacity(0.06)).overlay(ProgressView().tint(paint.faint))
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Rectangle().fill(paint.text.opacity(0.06))
            .overlay(Image(systemName: placeholder).font(.title2).foregroundStyle(paint.text.opacity(0.35)))
    }
}

extension View {
    /// The surface every section is drawn on: dark glass edged in the
    /// author's colour, or a white card.
    func panel(cornerRadius: CGFloat = 20) -> some View {
        modifier(Panel(cornerRadius: cornerRadius))
    }
}

struct Panel: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.guestPaint) private var paint

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if paint.isDark {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.black.opacity(0.35), in: shape)
                .overlay(shape.strokeBorder(paint.hairline))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
        } else {
            content
                .background(Color.white, in: shape)
                .overlay(shape.strokeBorder(paint.hairline))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        }
    }
}

/// The one filled button on these pages.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.guestPaint) private var paint
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(paint.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(paint.primary.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Sinks a little under a finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// What a section says when its author has not filled it in yet.
struct EmptyPage: View {
    let symbol: String
    let message: String
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(paint.primary.opacity(0.6))
            Text(message).font(paint.body(16)).italic().foregroundStyle(paint.faint).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Motion

/// Arrives rather than being there: fades and rises into place once, as the
/// web's `Reveal` does, and not at all when motion is reduced.
struct Reveal: ViewModifier {
    var delay: Double = 0
    var distance: CGFloat = 14
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isShown || reduceMotion ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : distance)
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(delay)) { isShown = true }
            }
    }
}

extension View {
    func reveal(delay: Double = 0, distance: CGFloat = 14) -> some View {
        modifier(Reveal(delay: delay, distance: distance))
    }
}

// MARK: - Background

/// What the page paints behind itself — the author's image, colour or
/// gradient, or the surface's own.
struct GuestBackdrop: View {
    let look: GuestLook
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ZStack {
            switch look.background {
            case .image(let url):
                GuestImage(url: url).overlay(Color.black.opacity(paint.isDark ? 0.35 : 0.1))
            case .solid(let hex):
                Color(guestHex: hex)
            case .gradient(let first, let second):
                LinearGradient(colors: [Color(guestHex: first), Color(guestHex: second)], startPoint: .top, endPoint: .bottom)
            case .none:
                if paint.isDark {
                    LinearGradient(colors: [paint.page, Color(red: 0.12, green: 0.1, blue: 0.08)], startPoint: .top, endPoint: .bottom)
                } else {
                    paint.page
                }
            }
        }
        .ignoresSafeArea()
    }
}
