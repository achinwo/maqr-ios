//
//  DesignerPanes.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import GuestExperience
import PhotosUI
import SwiftUI

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
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if isUploading {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay { ProgressView("Uploading…") }
                                .transition(.opacity)
                        }
                    }
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .animation(.snappy, value: isUploading)
                    .animation(.smooth, value: value.wrappedValue)
            }

            Section {
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(isUploading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                TextField("Or paste a link", text: value)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !value.wrappedValue.isEmpty {
                    Button("Remove photo", systemImage: "trash", role: .destructive) { value.wrappedValue = "" }
                }
            } footer: {
                if let failure {
                    Label(failure, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(slot.title)
        .navigationBarTitleDisplayMode(.inline)
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
                    .foregroundStyle(Color.secondary)
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
                            Text(entry.title).foregroundStyle(Color.primary)
                            Text(entry.experienceName).font(.caption).foregroundStyle(Color.secondary)
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
    @State private var query = ""

    var body: some View {
        List {
            if query.isEmpty {
                row(nil, title: String(localized: "Default"), detail: slot.defaultDetail)
            }
            if !FontCatalog.state.hasArrived {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            ForEach(fonts, id: \.family) { font in
                row(font, title: font.family, detail: font.category)
            }
        }
        .searchable(text: $query, prompt: Text("Search fonts"))
        .overlay {
            if FontCatalog.state.hasArrived, !query.isEmpty, fonts.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(slot.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { FontCatalog.loadAll() }
    }

    private var fonts: [FontEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return FontCatalog.state.fonts }
        return FontCatalog.state.fonts.filter {
            $0.family.localizedCaseInsensitiveContains(needle) || $0.category.localizedCaseInsensitiveContains(needle)
        }
    }

    private func row(_ font: FontEntry?, title: String, detail: String) -> some View {
        Button {
            slot.choose(font, in: document)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    // Each name in its own face, once it has arrived.
                    Text(title)
                        .font(font.flatMap { GuestFonts.shared.isAvailable($0.family) ? Font.custom($0.family, size: 20, relativeTo: .body) : nil } ?? .body)
                        .foregroundStyle(Color.primary)
                        .animation(.easeOut, value: font.map { GuestFonts.shared.isAvailable($0.family) })
                    Text(detail).font(.caption).foregroundStyle(Color.secondary)
                }
                Spacer()
                if slot.chosenFamily(in: document) == (font?.family ?? "") {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint)
                }
            }
        }
    }
}
