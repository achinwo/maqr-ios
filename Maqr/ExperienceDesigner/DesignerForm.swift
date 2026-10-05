//
//  DesignerForm.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import SwiftUI

/// One section of a step's form — a card in the web designer, a `Section`
/// here — exactly as ``DocumentForm`` or the schema described it.
struct DesignerSection: View {
    let spec: SectionSpec

    var body: some View {
        Section {
            ForEach(Array(spec.fields.enumerated()), id: \.offset) { _, field in
                FieldRow(spec: field)
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.title)
                    if let subtitle = spec.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption2).textCase(nil)
                    }
                }
                Spacer()
                ForEach(Array(spec.actions.enumerated()), id: \.offset) { _, action in
                    Button(role: action.isDestructive ? .destructive : nil, action: action.run) {
                        Text(action.label)
                    }
                    .accessibilityLabel(action.title)
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

/// One field, drawn by kind. The native counterpart of the web designer's
/// `FieldView`: a single `switch`, so adding a kind to ``FieldSpec`` is one
/// case here and nothing else.
struct FieldRow: View {
    let spec: FieldSpec

    var body: some View {
        switch spec.kind {
        case .text(let type):
            labelled {
                TextField(spec.placeholder, text: text)
                    .keyboardType(type.keyboard)
                    .textInputAutocapitalization(type == .text ? .sentences : .never)
                    .autocorrectionDisabled(type != .text)
                    .disabled(spec.isReadOnly)
            }

        case .textArea:
            labelled {
                TextField(spec.placeholder, text: text, axis: .vertical)
                    .lineLimit(3...8)
            }

        case .richText, .richTextArea:
            labelled {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(spec.toolbar.enumerated()), id: \.offset) { _, row in
                        ToolbarRow(buttons: row)
                    }
                    TextField(spec.placeholder, text: text, axis: spec.isMultiline ? .vertical : .horizontal)
                        .lineLimit(spec.isMultiline ? 3...8 : 1...1)
                        .designerTextStyle(spec.inputStyle)
                }
            }

        case .color:
            Button(action: spec.onEdit) {
                HStack {
                    Text(spec.label).foregroundStyle(.primary)
                    Spacer()
                    Text(spec.value.wrappedValue.isEmpty ? "Default" : spec.value.wrappedValue)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(Color(designerHex: spec.value.wrappedValue) ?? .clear)
                        .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                        .frame(width: 24, height: 24)
                }
            }

        case .image:
            Button(action: spec.onEdit) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(spec.label).foregroundStyle(.primary)
                        if let hint = spec.hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    DesignerImage(url: spec.value.wrappedValue)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

        case .choice(let options):
            labelled {
                let picker = Picker(spec.label, selection: text) {
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                // Segments while they fit across a phone; a menu after that.
                if options.count <= 3 {
                    picker.pickerStyle(.segmented)
                } else {
                    picker.pickerStyle(.menu)
                }
            }

        case .fontPicker:
            Button(action: spec.onEdit) {
                HStack {
                    Text(spec.label).foregroundStyle(.primary)
                    Spacer()
                    Text(spec.value.wrappedValue)
                        .foregroundStyle(.secondary)
                        .designerTextStyle(spec.inputStyle)
                }
            }

        case .action(let style):
            Button(role: style == .danger ? .destructive : nil, action: spec.onEdit) {
                Text(spec.label)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(style == .primary ? .accentColor : (style == .danger ? .red : .secondary))
            if let hint = spec.hint {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }

        case .note:
            VStack(alignment: .leading, spacing: 4) {
                Text(spec.label).font(.subheadline)
                if let detail = spec.hint { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    /// The field's text, rewritten as it is typed when the spec asks — so a
    /// character the value cannot hold never appears.
    private var text: SwiftUI.Binding<String> {
        let value = SwiftUI.Binding(spec.value)
        guard let transform = spec.transform else { return value }
        return SwiftUI.Binding(get: { value.wrappedValue }, set: { value.wrappedValue = transform($0) })
    }

    private func labelled(@ViewBuilder _ control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spec.label).font(.subheadline).foregroundStyle(.secondary)
            control()
            if let error = spec.error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if let hint = spec.hint {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// A rich-text field's formatting buttons. Their actions hand a new format to
/// the document; the colour and font buttons push the designer's own panes.
private struct ToolbarRow: View {
    let buttons: [ToolbarButton]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    Button(action: button.run) {
                        Text(button.label)
                            .designerTextStyle(button.style)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                button.isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12),
                                in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(button.title)
                    .accessibilityAddTraits(button.isOn ? .isSelected : [])
                }
            }
        }
    }
}

/// A photo from a URL the document holds, or a placeholder.
struct DesignerImage: View {
    let url: String

    var body: some View {
        if let url = URL(string: url), !self.url.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
        } else {
            Color.secondary.opacity(0.15)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}

extension FieldInputType {
    var keyboard: UIKeyboardType {
        switch self {
        case .text: return .default
        case .number: return .numberPad
        case .email: return .emailAddress
        case .url: return .URL
        case .tel: return .phonePad
        }
    }
}
