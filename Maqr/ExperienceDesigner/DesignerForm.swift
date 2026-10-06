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
                if !spec.actions.isEmpty {
                    // Reorder and remove, for a repeating card, behind one menu.
                    Menu {
                        ForEach(Array(spec.actions.enumerated()), id: \.offset) { _, action in
                            Button(role: action.isDestructive ? .destructive : nil) {
                                withAnimation(.snappy) { action.run() }
                            } label: {
                                Label(action.title, systemImage: symbol(for: action))
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .imageScale(.large)
                    }
                    .accessibilityLabel(Text("Card actions"))
                }
            }
        }
    }

    private func symbol(for action: SectionAction) -> String {
        if action.isDestructive { return "trash" }
        switch action.label {
        case "\u{2191}": return "arrow.up"
        case "\u{2193}": return "arrow.down"
        default: return "circle"
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
                    .foregroundStyle(spec.isReadOnly ? .secondary : .primary)
            }

        case .textArea:
            labelled {
                TextField(spec.placeholder, text: text, axis: .vertical)
                    .lineLimit(3...8)
            }

        case .richText, .richTextArea:
            RichTextEditorField(spec: spec, text: text)

        case .color:
            // The compact system well opens the picker in place: no pane to push.
            ColorPicker(
                selection: SwiftUI.Binding(
                    get: { Color(designerHex: spec.value.wrappedValue) ?? .gray },
                    set: { spec.value.wrappedValue = $0.designerHex }),
                supportsOpacity: false
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.label)
                    Text(spec.value.wrappedValue.isEmpty ? String(localized: "Default") : spec.value.wrappedValue.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.secondary)
                        .contentTransition(.numericText())
                }
            }
            .animation(.snappy, value: spec.value.wrappedValue)

        case .image:
            Button(action: spec.onEdit) {
                HStack(spacing: 12) {
                    DesignerImage(url: spec.value.wrappedValue)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spec.label).foregroundStyle(Color.primary)
                        Text(spec.value.wrappedValue.isEmpty ? String(localized: "Add a photo") : (spec.hint ?? String(localized: "Tap to change")))
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .contextMenu {
                if !spec.value.wrappedValue.isEmpty {
                    Button("Remove photo", systemImage: "trash", role: .destructive) { spec.value.wrappedValue = "" }
                }
            }

        case .choice(let options):
            if options.count <= 3 {
                // Segments while they fit across a phone.
                labelled {
                    Picker(spec.label, selection: text) {
                        ForEach(options, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            } else {
                Picker(spec.label, selection: text) {
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }

        case .fontPicker:
            Button(action: spec.onEdit) {
                HStack {
                    Label {
                        Text(spec.label).foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "textformat").foregroundStyle(.tint)
                    }
                    Spacer()
                    Text(spec.value.wrappedValue)
                        .foregroundStyle(Color.secondary)
                        .designerTextStyle(spec.inputStyle)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }

        case .action(let style):
            VStack(spacing: 6) {
                switch style {
                case .primary:
                    Button(action: spec.onEdit) {
                        Text(spec.label).font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                case .secondary:
                    Button(action: spec.onEdit) {
                        Text(spec.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                case .danger:
                    Button(role: .destructive, action: spec.onEdit) {
                        Text(spec.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if let hint = spec.hint {
                    Text(hint).font(.caption).foregroundStyle(Color.secondary).multilineTextAlignment(.center)
                }
            }
            .buttonBorderShape(.capsule)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

        case .note:
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spec.label).font(.subheadline)
                    if let detail = spec.hint { Text(detail).font(.caption).foregroundStyle(Color.secondary) }
                }
            } icon: {
                Image(systemName: "info.circle.fill").foregroundStyle(.tint)
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
            Text(spec.label).font(.subheadline.weight(.medium)).foregroundStyle(Color.secondary)
            control()
            if let error = spec.error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let hint = spec.hint {
                Text(hint).font(.caption).foregroundStyle(Color.secondary)
            }
        }
        .animation(.snappy, value: spec.error)
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
                .overlay(Image(systemName: "photo").foregroundStyle(Color.secondary))
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
