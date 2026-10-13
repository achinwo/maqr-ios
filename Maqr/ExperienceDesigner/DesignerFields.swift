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
private struct FontList: View {
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

extension Color {
    /// `#rrggbb`, for writing back into the document.
    var hexString: String {
        let resolved = resolve(in: EnvironmentValues())
        func channel(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return RGBColor(red: channel(resolved.red), green: channel(resolved.green), blue: channel(resolved.blue)).hexString
    }
}
