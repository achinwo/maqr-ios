//
//  ExperienceDesignerView.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import SwiftUI

/// The experience designer, drawn natively.
///
/// A thin layer: which steps there are, what is on each one, what the preview
/// shows and whether the experience can be created all come from
/// `ExperienceModel` — the same code the web designer runs as wasm. This view
/// only lays the answers out, pushes the pickers the form asks for, and hands
/// the finished row to ``ExperienceDesignerHost`` to save.
struct ExperienceDesignerView: View {
    let host: ExperienceDesignerHost

    @State private var document: ExperienceDocument
    @State private var stepId = ""
    @State private var message = ""
    @State private var isSaving = false
    @State private var isPreviewing = false

    @State private var path: [Pane] = []
    @State private var colorSlot: ColorSlot?
    @State private var imageSlot: ImageSlot?
    @State private var fontSlot: FontSlot?
    @State private var copyRequest: CopyRequest?

    /// - Parameters:
    ///   - type: the experience type to start on — a class name from
    ///     experiences.json — or `nil` to ask.
    init(host: ExperienceDesignerHost, type: String? = nil) {
        self.host = host
        let document = ExperienceDocument()
        if let type, ExperienceSchema.isKnown(type) { document.type = type }
        _document = State(initialValue: document)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if DocumentText.trimmed(document.type).isEmpty {
                    typePicker
                } else {
                    editor
                }
            }
            .navigationDestination(for: Pane.self, destination: pane)
        }
        .onAppear { host.install() }
    }

    // MARK: - Choosing a type

    private var typePicker: some View {
        List(ExperienceSchema.all, id: \.type) { schema in
            Button {
                document.type = schema.type
                stepId = schema.steps.startingStep.id
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schema.badge).font(.caption.weight(.bold)).foregroundStyle(.tint)
                    Text(schema.tagline).foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("New experience")
    }

    // MARK: - Editing

    private var schema: ExperienceSchema { ExperienceSchema.forType(document.type) }
    private var step: DesignerStep { schema.steps.step(id: stepId) }

    private var editor: some View {
        let schema = self.schema
        let step = self.step
        let sections = DocumentForm.sections(
            for: step,
            schema: schema,
            document: document,
            pushColor: { colorSlot = $0; path.append(.color) },
            pushImage: { imageSlot = $0; path.append(.image) },
            pushCopy: { kind, onCopy in
                copyRequest = CopyRequest(kind: kind, onCopy: onCopy)
                path.append(.copy)
            },
            pushFont: { fontSlot = $0; path.append(.font) },
            exportMessage: message,
            onCreate: create)

        return Form {
            Section {
                Text(step.summary).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                DesignerSection(spec: section)
            }
            if !message.isEmpty {
                Section { Text(message).font(.footnote) }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { stepBar(schema.steps) }
        .safeAreaInset(edge: .bottom, spacing: 0) { stepButtons(schema.steps) }
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(schema.badge).font(.caption2.weight(.bold)).foregroundStyle(.tint)
                    Text(step.title).font(.headline)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Preview", systemImage: "iphone") { isPreviewing = true }
            }
        }
        .sheet(isPresented: $isPreviewing) {
            NavigationStack {
                DesignerPreview(document: document, schema: schema, step: step)
                    .navigationTitle("Preview")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { isPreviewing = false } }
            }
            .presentationDetents([.medium, .large])
        }
        .disabled(isSaving)
        .overlay { if isSaving { ProgressView() } }
    }

    private func stepBar(_ steps: [DesignerStep]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(steps, id: \.id) { item in
                    Button(item.shortTitle) { stepId = item.id }
                        .buttonStyle(.bordered)
                        .tint(item.id == step.id ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func stepButtons(_ steps: [DesignerStep]) -> some View {
        HStack {
            if let previous = steps.previous(of: step.id) {
                Button("Back", systemImage: "chevron.left") { stepId = previous.id }
            }
            Spacer()
            if let next = steps.next(of: step.id) {
                Button {
                    stepId = next.id
                } label: {
                    Label(next.shortTitle, systemImage: "chevron.right").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Pushed panes

    enum Pane: Hashable {
        case color, image, copy, font
    }

    /// The copy picker's list and what a copied entry becomes — the schema's
    /// decision, carried to the pane.
    private struct CopyRequest {
        let kind: CopyKind
        let onCopy: (CopyEntry) -> Void
    }

    @ViewBuilder private func pane(_ pane: Pane) -> some View {
        switch pane {
        case .color:
            if let colorSlot { ColorPane(document: document, slot: colorSlot) }
        case .image:
            if let imageSlot { ImagePane(document: document, slot: imageSlot, host: host) }
        case .copy:
            if let copyRequest { CopyPane(kind: copyRequest.kind, onCopy: copyRequest.onCopy) }
        case .font:
            if let fontSlot { FontPane(document: document, slot: fontSlot) }
        }
    }

    // MARK: - Creating

    private func create() {
        switch ExperienceCreation.prepare(document, schema: schema) {
        case .refused(let refusal, let stepId):
            message = refusal
            if let stepId { self.stepId = stepId }
        case .ready(let json):
            isSaving = true
            message = ""
            Task {
                defer { isSaving = false }
                do {
                    let uuid = try await host.save(json)
                    document.adopt(savedUuid: uuid)
                    message = "Saved."
                } catch {
                    message = "Couldn't save: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview("Choose a type") {
    ExperienceDesignerView(host: .offline)
}

#Preview("Wedding") {
    ExperienceDesignerView(host: .offline, type: ExperienceType.wedding)
}
