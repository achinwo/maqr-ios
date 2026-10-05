//
//  DesignerPanes.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import PhotosUI
import SwiftUI

/// Edits one colour field — ``ColorSlot`` says which.
struct ColorPane: View {
    let document: ExperienceDocument
    let slot: ColorSlot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let value = SwiftUI.Binding(DocumentBinding.field(document, slot.key))
        Form {
            ColorPicker(
                slot.title,
                selection: SwiftUI.Binding(
                    get: { Color(designerHex: value.wrappedValue) ?? .gray },
                    set: { value.wrappedValue = $0.designerHex }),
                supportsOpacity: false)

            TextField("#rrggbb", text: value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if slot.isOptional {
                Button("Use the page's own", role: .destructive) {
                    value.wrappedValue = ""
                    dismiss()
                }
            }
        }
        .navigationTitle(slot.title)
    }
}

/// Picks a photo for one image field: from the library, uploaded and cropped
/// to the shape ``ImageSlot`` asks for, or as a link.
struct ImagePane: View {
    let document: ExperienceDocument
    let slot: ImageSlot
    let host: ExperienceDesignerHost
    @Environment(\.dismiss) private var dismiss

    @State private var pick: PhotosPickerItem?
    @State private var isUploading = false
    @State private var failure: String?

    var body: some View {
        let value = SwiftUI.Binding(DocumentBinding.image(document, slot))
        Form {
            Section {
                DesignerImage(url: value.wrappedValue)
                    .aspectRatio(slot.aspectRatio.map { CGFloat($0) } ?? 1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets())
            }

            Section {
                PhotosPicker(selection: $pick, matching: .images) {
                    Label(isUploading ? "Uploading…" : "Choose a photo", systemImage: "photo.on.rectangle")
                }
                .disabled(isUploading)

                TextField("Or paste a link", text: value)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !value.wrappedValue.isEmpty {
                    Button("Remove photo", role: .destructive) { value.wrappedValue = "" }
                }
            } footer: {
                if let failure { Text(failure).foregroundStyle(.red) }
            }
        }
        .navigationTitle(slot.title)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await upload(item, into: value) }
        }
    }

    private func upload(_ item: PhotosPickerItem, into value: SwiftUI.Binding<String>) async {
        isUploading = true
        failure = nil
        defer {
            isUploading = false
            pick = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else { return }
            let url = try await host.uploadImage(cropped(image))
            value.wrappedValue = url.absoluteString
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }

    /// The middle of `image` at the slot's aspect ratio, its longest edge at
    /// the slot's output size — the crop the web designer's picker makes,
    /// without the dragging.
    private func cropped(_ image: UIImage) -> UIImage {
        let size = image.size
        var crop = CGRect(origin: .zero, size: size)
        if let ratio = slot.aspectRatio, ratio > 0 {
            if size.width / size.height > ratio {
                crop.size.width = size.height * ratio
                crop.origin.x = (size.width - crop.width) / 2
            } else {
                crop.size.height = size.width / ratio
                crop.origin.y = (size.height - crop.height) / 2
            }
        }
        let scale = min(1, slot.outputSize / max(crop.width, crop.height))
        let output = CGSize(width: crop.width * scale, height: crop.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: output, format: format).image { _ in
            image.draw(
                in: CGRect(
                    x: -crop.minX * scale, y: -crop.minY * scale,
                    width: size.width * scale, height: size.height * scale))
        }
    }
}

/// Copies an entry from one of the author's back catalogues.
struct CopyPane: View {
    let kind: CopyKind
    let onCopy: (CopyEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [CopyEntry] = []
    @State private var hasLoaded = false
    @State private var query = ""

    var body: some View {
        List {
            if !hasLoaded {
                ProgressView()
            } else if filtered.isEmpty {
                Text(entries.isEmpty ? "Nothing saved yet." : "No matches.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, entry in
                Button {
                    onCopy(entry)
                    dismiss()
                } label: {
                    HStack {
                        DesignerImage(url: entry.imageName)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) {
                            Text(entry.title).foregroundStyle(.primary)
                            Text(entry.experienceName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle(kind == .dishes ? "Your dishes" : "Your vendors")
        .onAppear {
            CopyLibrary.load(kind) { loaded in
                entries = loaded
                hasLoaded = true
            }
        }
    }

    private var filtered: [CopyEntry] {
        let needle = DocumentText.lowercasedASCII(DocumentText.trimmed(query))
        guard !needle.isEmpty else { return entries }
        return entries.filter { $0.searchText.contains(needle) }
    }
}

/// Chooses a catalogue font for a text style or the page — ``FontSlot`` says
/// which, and where the choice is kept.
struct FontPane: View {
    let document: ExperienceDocument
    let slot: FontSlot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            row(nil, title: "Default", detail: slot.defaultDetail)
            if !FontCatalog.state.hasArrived {
                ProgressView()
            }
            ForEach(FontCatalog.state.fonts, id: \.family) { font in
                row(font, title: font.family, detail: font.category)
            }
        }
        .navigationTitle(slot.title)
        .onAppear { FontCatalog.loadAll() }
    }

    private func row(_ font: FontEntry?, title: String, detail: String) -> some View {
        Button {
            slot.choose(font, in: document)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if slot.chosenFamily(in: document) == (font?.family ?? "") {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
    }
}
