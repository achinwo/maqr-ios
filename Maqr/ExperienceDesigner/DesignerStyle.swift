//
//  DesignerStyle.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import GuestExperience
import SwiftUI

extension SwiftUI.Binding where Value == String {
    /// The model's binding into the document, as SwiftUI reads it.
    init(_ binding: ExperienceModel.Binding<String>) {
        self.init(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0 })
    }
}

extension Color {
    /// A colour the document holds — `#rrggbb`, `#rgb` or a CSS name — parsed
    /// by the same rules the web designer uses, or `nil` when it isn't one.
    init?(designerHex text: String) {
        guard let rgb = RGBColor.parse(text) else { return nil }
        self.init(
            .sRGB,
            red: Double(rgb.red) / 255,
            green: Double(rgb.green) / 255,
            blue: Double(rgb.blue) / 255)
    }

    /// `#rrggbb`, for writing back into the document.
    var designerHex: String {
        let resolved = resolve(in: EnvironmentValues())
        func channel(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return RGBColor(red: channel(resolved.red), green: channel(resolved.green), blue: channel(resolved.blue))
            .hexString
    }
}

extension View {
    /// Applies the parts of an author's text style a native view can honour —
    /// weight, slant, lines, alignment and size. Colours and faces are left to
    /// the caller, as the web designer leaves them to its stylesheet.
    func designerTextStyle(_ style: InlineStyle) -> some View {
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var alignment: TextAlignment?
        var size: CGFloat?
        var family: String?

        for (key, value) in style {
            switch key {
            case "font-weight": bold = value == "700" || value == "bold"
            case "font-style": italic = value == "italic"
            case "text-decoration-line":
                underline = value.contains("underline")
                strikethrough = value.contains("line-through")
            case "text-align":
                switch value {
                case "center": alignment = .center
                case "right": alignment = .trailing
                case "left": alignment = .leading
                default: break
                }
            case "font-family":
                family = value.split(separator: ",").first.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) }
            case "font-size":
                if let points = Double(value.replacingOccurrences(of: "px", with: "")) {
                    size = CGFloat(points)
                }
            default:
                break
            }
        }

        return self
            .bold(bold)
            .italic(italic)
            .underline(underline)
            .strikethrough(strikethrough)
            .multilineTextAlignment(alignment ?? .leading)
            .modifier(OptionalFontSize(size: size, family: family))
    }
}

/// The size, and the author's face once it has been registered.
private struct OptionalFontSize: ViewModifier {
    let size: CGFloat?
    let family: String?

    func body(content: Content) -> some View {
        Group {
            if let family, GuestFonts.shared.isAvailable(family) {
                content.font(.custom(family, size: size ?? 17, relativeTo: .body))
            } else if let size {
                content.font(.system(size: size))
            } else {
                content
            }
        }
        // Asks for the face — again once the catalogue has arrived, since a
        // family cannot be looked up before then.
        .task(id: "\(family ?? "")|\(FontCatalog.state.hasArrived)") {
            if let family, !family.isEmpty { FontCatalog.load(family) }
        }
    }
}
