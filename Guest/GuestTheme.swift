//
//  GuestTheme.swift
//  Maqr
//
//  The guest pages' look, shared by the App Clip and the app: the wedding's
//  gold on dark glass (the constants at the top of ewed.tsx), the
//  author's typeface once it has arrived, and the few pieces every page is
//  made of.
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

/// The colours a wedding page draws with — the web's gold, ink and white.
struct GuestPaint {
    let gold = Color(guestHex: GuestPalette.gold)
    let ink = Color(guestHex: GuestPalette.ink)
    let text = Color.white

    var soft: Color { text.opacity(0.74) }
    var faint: Color { text.opacity(0.56) }
    var hairline: Color { gold.opacity(0.3) }
    var rule: Color { text.opacity(0.1) }
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

// MARK: - Type

/// Palatino, as the web's `BODY_FONT`.
enum GuestType {
    static func body(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Palatino", size: size, relativeTo: style)
    }
}

/// The heading face: the author's family once it has been registered, a
/// serif until then — so a page never waits on a font to be read.
struct DisplayFont: ViewModifier {
    let size: CGFloat
    var relativeTo: Font.TextStyle = .title
    @Environment(\.guestFamily) private var family

    func body(content: Content) -> some View {
        let fonts = GuestFonts.shared
        if !family.isEmpty, fonts.isAvailable(family) {
            content.font(.custom(family, size: size, relativeTo: relativeTo))
        } else {
            content.font(.system(size: size * 0.92, weight: .regular, design: .serif).italic())
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
    /// spreads them last on the web.
    func guestFormat(_ format: TextFormat, size: CGFloat, face: GuestFace, relativeTo style: Font.TextStyle = .title) -> some View {
        modifier(GuestFormat(format: format, size: size, face: face, relativeTo: style))
    }
}

/// The face a field is set in when its author has not chosen one.
enum GuestFace {
    /// The experience's heading face — its typeface, or Lobster Two.
    case display
    /// Palatino, the wedding's body face.
    case body
    /// The system's.
    case system
}

struct GuestFormat: ViewModifier {
    let format: TextFormat
    let size: CGFloat
    let face: GuestFace
    let relativeTo: Font.TextStyle
    @Environment(\.guestFamily) private var family

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
            return .system(size: size * 0.92, design: .serif).italic()
        case .body:
            return .custom("Palatino", size: size, relativeTo: relativeTo)
        case .system:
            return .system(size: size)
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

/// The gold rule with a diamond at its centre — the one flourish, under
/// every heading and between the chapters of the story.
struct Ornament: View {
    @Environment(\.guestPaint) private var paint

    var body: some View {
        HStack(spacing: 10) {
            LinearGradient(colors: [.clear, paint.gold], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40, height: 1)
            Rectangle().fill(paint.gold).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            LinearGradient(colors: [paint.gold, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40, height: 1)
        }
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }
}

/// How every page after home introduces itself.
struct PageHeading: View {
    let title: String
    var subtitle: String?
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .displayFont(34)
                .foregroundStyle(paint.gold)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 2)
                .reveal()
            Ornament().reveal(delay: 0.08)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(GuestType.body(17))
                    .italic()
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

/// The host's portrait in a gold ring.
struct Portrait: View {
    let url: URL?
    var size: CGFloat = 128
    @Environment(\.guestPaint) private var paint

    var body: some View {
        GuestImage(url: url, placeholder: "heart.fill")
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(paint.gold, lineWidth: 2))
            .padding(4)
            .background(Circle().fill(Color.black.opacity(0.55)))
            .shadow(color: .black.opacity(0.6), radius: 20, y: 12)
    }
}

/// A picture from the experience: fades in when it arrives.
struct GuestImage: View {
    let url: URL?
    var placeholder = "photo"
    var contentMode: ContentMode = .fill

    var body: some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.5))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: contentMode).transition(.opacity)
                case .failure:
                    fallback
                default:
                    Rectangle().fill(.white.opacity(0.06)).overlay(ProgressView().tint(.white.opacity(0.6)))
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Rectangle().fill(.white.opacity(0.06))
            .overlay(Image(systemName: placeholder).font(.title2).foregroundStyle(.white.opacity(0.35)))
    }
}

extension View {
    /// Dark glass edged in gold — the tiles, the notice, the cards.
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.guestPaint) private var paint

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(paint.hairline))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
    }
}

/// The one filled button on these pages.
struct GoldButtonStyle: ButtonStyle {
    @Environment(\.guestPaint) private var paint
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(paint.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(paint.gold.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35), in: Capsule())
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
/// gradient, or for a wedding the dark the gold is drawn for.
struct GuestBackdrop: View {
    let look: GuestLook
    var isWedding = true
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ZStack {
            switch look.background {
            case .image(let url):
                GuestImage(url: url).overlay(Color.black.opacity(0.35))
            case .solid(let hex):
                Color(guestHex: hex)
            case .gradient(let first, let second):
                LinearGradient(colors: [Color(guestHex: first), Color(guestHex: second)], startPoint: .top, endPoint: .bottom)
            case .none:
                if isWedding {
                    LinearGradient(colors: [paint.ink, Color(red: 0.12, green: 0.1, blue: 0.08)], startPoint: .top, endPoint: .bottom)
                } else {
                    Color(.systemGroupedBackground)
                }
            }
        }
        .ignoresSafeArea()
    }
}
