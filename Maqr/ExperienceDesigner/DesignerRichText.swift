//
//  DesignerRichText.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import SwiftUI

/// A rich-text field: the text, drawn in its chosen style, over a formatting
/// bar of system symbols.
///
/// The buttons are ``RichTextToolbar``'s — the same ones the web designer
/// draws — recognised by what they are and given the look of an iOS
/// formatting bar: grouped toggles, a size stepper, a colour well.
struct RichTextEditorField: View {
    let spec: FieldSpec
    let text: SwiftUI.Binding<String>

    @FocusState private var isFocused: Bool
    @State private var taps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(spec.label).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)

            TextField(spec.placeholder, text: text, axis: spec.isMultiline ? .vertical : .horizontal)
                .lineLimit(spec.isMultiline ? 3...8 : 1...1)
                .designerTextStyle(spec.inputStyle)
                .focused($isFocused)
                .padding(12)
                .frame(minHeight: spec.isMultiline ? 96 : nil, alignment: .topLeading)
                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 1.5)
                }
                .animation(.easeOut(duration: 0.15), value: isFocused)

            let buttons = spec.toolbar.flatMap { $0 }
            HStack(spacing: 8) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    if Part(button) == .font { fontChip(button) }
                }
                Spacer(minLength: 0)
                group(buttons.filter { [.smaller, .size, .larger].contains(Part($0)) })
            }
            HStack(spacing: 8) {
                group(buttons.filter { [.bold, .italic, .underline, .strikethrough].contains(Part($0)) })
                group(buttons.filter { Part($0) == .align })
                Spacer(minLength: 0)
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    if Part(button) == .color { colorWell(button) }
                }
                group(buttons.filter { Part($0) == .clear })
            }

            if let error = spec.error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if let hint = spec.hint {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }

    // MARK: Pieces

    private func run(_ button: ToolbarButton) {
        taps += 1
        withAnimation(.snappy(duration: 0.2)) { button.run() }
    }

    private func fontChip(_ button: ToolbarButton) -> some View {
        Button { run(button) } label: {
            HStack(spacing: 6) {
                Image(systemName: "textformat")
                Text(button.label).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .foregroundStyle(button.isOn ? Color.accentColor : .primary)
            .background(.fill.tertiary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(button.title)
    }

    /// Buttons that belong together, in one capsule.
    @ViewBuilder private func group(_ buttons: [ToolbarButton]) -> some View {
        if !buttons.isEmpty {
            HStack(spacing: 2) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    toolButton(button)
                }
            }
            .padding(2)
            .background(.fill.tertiary, in: Capsule())
        }
    }

    private func toolButton(_ button: ToolbarButton) -> some View {
        let part = Part(button)
        return Button { run(button) } label: {
            Group {
                if let symbol = part.symbol(for: button) {
                    Image(systemName: symbol)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Text(button.label).monospacedDigit()
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 32, minHeight: 30)
            .padding(.horizontal, part == .size ? 4 : 0)
            .foregroundStyle(button.isOn ? Color.white : .primary)
            .background {
                if button.isOn { Capsule().fill(Color.accentColor) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(button.title)
        .accessibilityAddTraits(button.isOn ? .isSelected : [])
    }

    @ViewBuilder private func colorWell(_ button: ToolbarButton) -> some View {
        if case .color(let hex, let set) = button.control {
            ColorPicker(
                button.title,
                selection: SwiftUI.Binding(
                    get: { Color(designerHex: hex) ?? .primary },
                    set: { set($0.designerHex) }),
                supportsOpacity: false)
                .labelsHidden()
                .contextMenu {
                    if !hex.isEmpty {
                        Button("Use the page's colour", systemImage: "arrow.uturn.backward") { set("") }
                    }
                }
                .accessibilityLabel(button.title)
        } else {
            // A host that pushes its colour pane: a swatch that opens it.
            let swatch = button.style.first { $0.key == "--rte-swatch" }?.value ?? ""
            Button { run(button) } label: {
                Circle()
                    .fill(Color(designerHex: swatch) ?? .clear)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(button.title)
        }
    }
}

/// What a toolbar button is, recognised from the classes and glyphs
/// ``RichTextToolbar`` gives it.
private enum Part: Equatable {
    case font, smaller, size, larger, bold, italic, underline, strikethrough, align, color, clear, other

    init(_ button: ToolbarButton) {
        let classes = button.className.split(separator: " ")
        if classes.contains("rte-font") { self = .font }
        else if classes.contains("rte-size-step") { self = button.label == "A+" ? .larger : .smaller }
        else if classes.contains("rte-size") { self = .size }
        else if classes.contains("rte-align") { self = .align }
        else if classes.contains("rte-color") { self = .color }
        else if classes.contains("rte-clear") { self = .clear }
        else {
            switch button.label {
            case "B": self = .bold
            case "I": self = .italic
            case "U": self = .underline
            case "S": self = .strikethrough
            default: self = .other
            }
        }
    }

    func symbol(for button: ToolbarButton) -> String? {
        switch self {
        case .smaller: return "minus"
        case .larger: return "plus"
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .clear: return "eraser"
        case .align:
            if button.className.contains("rte-align-center") { return "text.aligncenter" }
            if button.className.contains("rte-align-right") { return "text.alignright" }
            return "text.alignleft"
        case .font, .size, .color, .other: return nil
        }
    }
}
