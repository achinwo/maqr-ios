//
//  DesignerFields.swift
//  Maqr
//
//  The designer's form, drawn from data: a section's fields are its
//  manifest's `form` (Blocks/<kind>.json in maqr-core), its lists are the
//  manifest's `collections`, and the Welcome and Style steps are the same
//  ``BlockField``s written out for the identity and the theme. One row view
//  per field type, so a new manifest needs no code here.
//

import DesignerFoundation
import ExperienceModel
import GuestExperience
import PhotosUI
import SwiftUI

/// One field, read and written through closures so it can sit on the
/// document, a section or one item of a section's list alike.
struct FieldRow: View {
    let field: BlockField
    let value: JSONValue
    let set: (JSONValue) -> Void
    let host: ExperienceDesignerHost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            control
            if !field.hint.isEmpty {
                Text(field.hint).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var control: some View {
        switch field.type {
        case "toggle":
            // `hidden` is shown as the section being on.
            let inverted = field.path == "hidden"
            Toggle(field.label, isOn: SwiftUI.Binding(
                get: { (value.bool ?? false) != inverted },
                set: { on in set(on != inverted ? .bool(true) : (inverted ? .null : .bool(false))) }))
        case "textarea":
            labelled { TextField(field.placeholder, text: text, axis: .vertical).lineLimit(3...10) }
        case "number":
            labelled {
                TextField(field.placeholder, text: SwiftUI.Binding(
                    get: { value.text },
                    set: { set(Double($0.trimmingCharacters(in: .whitespaces)).map(JSONValue.number) ?? .null) }))
                .keyboardType(.decimalPad)
            }
        case "choice":
            Picker(field.label, selection: SwiftUI.Binding(get: { value.text }, set: { set($0.isEmpty ? .null : .string($0)) })) {
                if !field.options.contains(where: { $0.value.isEmpty }) { Text("None").tag("") }
                ForEach(field.options, id: \.value) { option in
                    Text(option.label.isEmpty ? option.value : option.label).tag(option.value)
                }
            }
        case "image":
            ImageField(label: field.label, url: value.text, set: { set($0.isEmpty ? .null : .string($0)) }, host: host)
        case "color":
            ColorPicker(field.label, selection: SwiftUI.Binding(
                get: { Color(guestHex: value.text, fallback: .clear) },
                set: { set(.string($0.hexString)) }), supportsOpacity: false)
        case "font":
            NavigationLink {
                FontList(selected: value.text) { set($0.isEmpty ? .null : .string($0)) }
            } label: {
                LabeledContent(field.label, value: value.text.isEmpty ? String(localized: "The surface's own") : value.text)
            }
        case "date":
            DateField(label: field.label, value: value.text, set: set)
        default:
            labelled {
                TextField(field.placeholder, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(field.type == "text" ? .sentences : .never)
                    .autocorrectionDisabled(field.type != "text")
            }
        }
    }

    private func labelled(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.label).font(.subheadline.weight(.medium))
            content()
        }
    }

    /// Text, with one exception: a list of amounts is typed as "25, 50, 100"
    /// and kept as numbers, as the manifest's schema has them.
    private var text: SwiftUI.Binding<String> {
        if case .array(let items) = value {
            return SwiftUI.Binding(
                get: { items.map(\.text).joined(separator: ", ") },
                set: { typed in
                    let numbers = typed.split(whereSeparator: { !$0.isNumber && $0 != "." }).compactMap { Double($0) }.filter { $0 > 0 }
                    set(.array(numbers.prefix(6).map(JSONValue.number)))
                })
        }
        return SwiftUI.Binding(get: { value.text }, set: { set($0.isEmpty ? .null : .string($0)) })
    }

    private var keyboard: UIKeyboardType {
        switch field.type {
        case "url": .URL
        case "tel": .phonePad
        case "email": .emailAddress
        default: .default
        }
    }
}

// MARK: - Groups and lists

/// One titled group of a section's form, or its list.
struct BlockGroupSection: View {
    let group: BlockFormGroup
    let blockId: String
    let manifest: BlockManifest
    let draft: CompositionDraft
    let host: ExperienceDesignerHost

    var body: some View {
        if !group.collection.isEmpty, let collection = manifest.collections.first(where: { $0.path == group.collection }) {
            CollectionEditor(title: group.title, collection: collection, blockId: blockId, draft: draft, host: host)
        } else {
            Section {
                ForEach(group.fields, id: \.path) { field in
                    FieldRow(field: field, value: draft.blockValue(blockId, field.path),
                             set: { draft.setBlock(blockId, field.path, $0) }, host: host)
                }
            } header: {
                Text(group.title)
            } footer: {
                if !group.subtitle.isEmpty { Text(group.subtitle) }
            }
        }
    }
}

/// A section's repeating list — chapters, moments, dishes — one form section
/// per item, with its own move and delete.
struct CollectionEditor: View {
    let title: String
    let collection: BlockCollection
    let blockId: String
    let draft: CompositionDraft
    let host: ExperienceDesignerHost

    var body: some View {
        let items = draft.items(blockId, collection: collection.path)
        Section {
            if items.isEmpty, !collection.emptyNote.isEmpty {
                Text(collection.emptyNote).font(.subheadline).foregroundStyle(.secondary)
            }
            Button {
                withAnimation(.snappy) { draft.addItem(blockId, collection: collection.path) }
            } label: {
                Label(collection.addLabel.isEmpty ? String(localized: "Add") : collection.addLabel, systemImage: "plus.circle.fill")
            }
        } header: {
            Text(title)
        }
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            Section {
                ForEach(collection.fields, id: \.path) { field in
                    FieldRow(field: field, value: item.value(at: field.path),
                             set: { draft.setItemField(blockId, collection: collection.path, at: index, field.path, $0) }, host: host)
                }
            } header: {
                HStack {
                    Text("\(collection.itemNoun) \(index + 1)")
                    Spacer()
                    Button { withAnimation(.snappy) { draft.moveItem(blockId, collection: collection.path, from: index, by: -1) } } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(index == 0)
                    Button { withAnimation(.snappy) { draft.moveItem(blockId, collection: collection.path, from: index, by: 1) } } label: {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(index == items.count - 1)
                    Button(role: .destructive) {
                        withAnimation(.snappy) { draft.removeItem(blockId, collection: collection.path, at: index) }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
                .imageScale(.medium)
            }
        }
    }
}

// MARK: - Pictures

/// A picture: chosen from the library, uploaded, and kept as its address —
/// or an address pasted in.
struct ImageField: View {
    let label: String
    let url: String
    let set: (String) -> Void
    let host: ExperienceDesignerHost
    @State private var pick: PhotosPickerItem?
    @State private var isUploading = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                Group {
                    if let address = URL(string: url), !url.isEmpty {
                        AsyncImage(url: address) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                    } else {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Label(url.isEmpty ? String(localized: "Choose a photo") : String(localized: "Replace"), systemImage: "photo.on.rectangle")
                    }
                    if !url.isEmpty {
                        Button(role: .destructive) { set("") } label: { Label("Remove", systemImage: "xmark.circle") }
                    }
                }
                .buttonStyle(.borderless)
                if isUploading { ProgressView() }
            }
            if let failure { Text(failure).font(.caption).foregroundStyle(.red) }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            pick = nil
            Task { await upload(item) }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        isUploading = true
        failure = nil
        defer { isUploading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                failure = String(localized: "That photo couldn't be read.")
                return
            }
            set(try await host.uploadImage(image).absoluteString)
        } catch {
            failure = error.localizedDescription
        }
    }
}

// MARK: - Dates and fonts

/// `identity.when` — what makes an event an event — as an ISO-8601 instant.
private struct DateField: View {
    let label: String
    let value: String
    let set: (JSONValue) -> Void

    var body: some View {
        let date = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
            ?? (try? Date.ISO8601FormatStyle().parse(value))
        if let date {
            HStack {
                DatePicker(label, selection: SwiftUI.Binding(get: { date }, set: { set(.string($0.ISO8601Format())) }))
                Button { set(.null) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Clear the date"))
            }
        } else {
            Button { set(.string(Date().ISO8601Format())) } label: { Label("\(label): add a date", systemImage: "calendar.badge.plus") }
        }
    }
}

/// The catalogue's families, each set in itself as it arrives.
struct FontList: View {
    let selected: String
    let choose: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let fonts = FontCatalog.state.fonts.filter { needle.isEmpty || $0.family.lowercased().contains(needle) }
        List {
            Button { choose(""); dismiss() } label: {
                HStack { Text("The surface's own"); Spacer(); if selected.isEmpty { Image(systemName: "checkmark") } }
            }
            if !FontCatalog.state.hasArrived { ProgressView() }
            ForEach(fonts, id: \.family) { font in
                Button { choose(font.family); dismiss() } label: {
                    HStack {
                        Text(font.family).font(GuestFonts.shared.isAvailable(font.family) ? .custom(font.family, size: 20) : .body)
                        Spacer()
                        if font.family == selected { Image(systemName: "checkmark") }
                    }
                }
                .task { FontCatalog.load(font.family) }
            }
        }
        .searchable(text: $query)
        .navigationTitle("Typeface")
        .onAppear { FontCatalog.loadAll() }
    }
}

// MARK: - Rich text

/// A rich-text field, as the web designer draws one: the words, set in the
/// style the author chose, over a formatting bar — font and size, then weight,
/// slant, lines, alignment, colour and clear, then the shadow.
///
/// The controls are ``RichTextToolbar``'s, the same ones the web designer
/// draws, recognised by what they are and given the look of an iOS
/// formatting bar: grouped toggles, a size stepper, a colour well. The text
/// and its format are kept apart in the document (`identity.title` and
/// `theme.typography.styles.title`), as they are on the web.
struct RichTextEditorField: View {
    let label: String
    var placeholder = ""
    var isMultiline = false
    /// `brandName` or `landingPageText` — which size range the field steps through.
    let field: String
    let text: SwiftUI.Binding<String>
    let format: SwiftUI.Binding<TextFormat>

    @FocusState private var isFocused: Bool
    @State private var taps = 0
    @State private var choosingFont = false

    var body: some View {
        let range = TextFormat.SizeRange.forField(field)
        let buttons = RichTextToolbar.rows(
            format.wrappedValue, range: range, fontFallback: "serif",
            pickers: .inlineColor(font: { choosingFont = true }),
            onChange: { format.wrappedValue = $0.validated(in: range) }
        ).flatMap { $0 }

        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)

            TextField(placeholder, text: text, axis: isMultiline ? .vertical : .horizontal)
                .lineLimit(isMultiline ? 3...8 : 1...1)
                .richTextFormat(format.wrappedValue)
                .focused($isFocused)
                .padding(12)
                .frame(minHeight: isMultiline ? 96 : nil, alignment: .topLeading)
                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 1.5)
                }
                .animation(.easeOut(duration: 0.15), value: isFocused)

            HStack(spacing: 8) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    if RichTextPart(button) == .font { fontChip(button) }
                }
                Spacer(minLength: 0)
                group(buttons.filter { [.smaller, .size, .larger].contains(RichTextPart($0)) })
            }
            HStack(spacing: 8) {
                group(buttons.filter { [.bold, .italic, .underline, .strikethrough].contains(RichTextPart($0)) })
                group(buttons.filter { RichTextPart($0) == .align })
                Spacer(minLength: 0)
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    if RichTextPart(button) == .color { colorWell(button) }
                }
                group(buttons.filter { RichTextPart($0) == .clear })
            }
            HStack(spacing: 8) {
                Image(systemName: "shadow")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                group(buttons.filter { RichTextPart($0) == .shadow })
                Spacer(minLength: 0)
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    if RichTextPart(button) == .shadowColor { colorWell(button) }
                }
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .navigationDestination(isPresented: $choosingFont) {
            FontList(selected: format.wrappedValue.font) { family in
                var next = format.wrappedValue
                next.font = family
                format.wrappedValue = next.validated(in: range)
            }
        }
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
                Text(button.label).lineLimit(1).richTextFamily(format.wrappedValue.font)
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
        let part = RichTextPart(button)
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
                    get: { Color(guestHex: hex, fallback: .primary) },
                    set: { set($0.hexString) }),
                supportsOpacity: false)
                .labelsHidden()
                .contextMenu {
                    if !hex.isEmpty, RichTextPart(button) == .color {
                        Button("Use the page's colour", systemImage: "arrow.uturn.backward") { set("") }
                    }
                }
                .accessibilityLabel(button.title)
        }
    }
}

/// What a toolbar button is, recognised from the classes and glyphs
/// ``RichTextToolbar`` gives it.
private enum RichTextPart: Equatable {
    case font, smaller, size, larger, bold, italic, underline, strikethrough, align, color, clear
    case shadow, shadowColor, other

    init(_ button: ToolbarButton) {
        let classes = button.className.split(separator: " ")
        if classes.contains("rte-shadow-color") { self = .shadowColor }
        else if classes.contains("rte-shadow") { self = .shadow }
        else if classes.contains("rte-font") { self = .font }
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
        case .font, .size, .color, .shadow, .shadowColor, .other: return nil
        }
    }
}

extension View {
    /// The parts of an author's text style the field's own input honours —
    /// weight, slant, lines, alignment, face and shadow. Size and colour are left to
    /// the field, as ``TextFormat/declarations(fontFallback:)`` leaves them to
    /// the web designer's: a colour chosen for the page's background can be
    /// unreadable on the editor's.
    func richTextFormat(_ format: TextFormat) -> some View {
        let alignment: TextAlignment = switch format.align {
        case "center": .center
        case "right": .trailing
        default: .leading
        }
        return self
            .bold(format.bold)
            .italic(format.italic)
            .underline(format.underline)
            .strikethrough(format.strikethrough)
            .multilineTextAlignment(alignment)
            .richTextFamily(format.font)
            .textShadow(format.shadow)
    }

    /// The author's face, once it has been registered.
    func richTextFamily(_ family: String) -> some View {
        modifier(RichTextFamily(family: family))
    }
}

private struct RichTextFamily: ViewModifier {
    let family: String

    func body(content: Content) -> some View {
        Group {
            if !family.isEmpty, GuestFonts.shared.isAvailable(family) {
                content.font(.custom(family, size: 17, relativeTo: .body))
            } else {
                content
            }
        }
        // Asks for the face — again once the catalogue has arrived, since a
        // family cannot be looked up before then.
        .task(id: "\(family)|\(FontCatalog.state.hasArrived)") {
            if !family.isEmpty { FontCatalog.load(family) }
        }
    }
}

extension Color {
    /// `#rrggbb`, for writing back into the document.
    var hexString: String {
        let resolved = resolve(in: EnvironmentValues())
        func channel(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return RGBColor(red: channel(resolved.red), green: channel(resolved.green), blue: channel(resolved.blue)).hexString
    }
}

#Preview("Rich text") {
    @Previewable @State var name = "Esther & Jide"
    @Previewable @State var nameFormat = TextFormat(bold: true, align: "center", size: 40, color: "#c9b375")
    @Previewable @State var welcome = "Saturday 12 June · Lagos"
    @Previewable @State var welcomeFormat = TextFormat(italic: true)
    NavigationStack {
        Form {
            Section("Welcome") {
                RichTextEditorField(label: "Name", field: "brandName", text: $name, format: $nameFormat)
                RichTextEditorField(label: "Welcome message", isMultiline: true, field: "landingPageText", text: $welcome, format: $welcomeFormat)
            }
        }
    }
}
