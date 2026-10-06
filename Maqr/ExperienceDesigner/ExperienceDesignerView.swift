//
//  ExperienceDesignerView.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import MaqrDashboard
import SwiftUI

/// The experience designer, drawn natively.
///
/// A thin layer: which steps there are, what is on each one, what the preview
/// shows and whether the experience can be created all come from
/// `ExperienceModel` — the same code the web designer runs as wasm. This view
/// only lays the answers out, pushes the pickers the form asks for, and hands
/// the finished row to ``ExperienceDesignerHost`` to save.
struct ExperienceDesignerView: View {
    /// What the designer opens on, besides a blank page.
    enum Seed {
        /// A copy of someone's row: everything but its id, so saving makes a
        /// new experience rather than overwriting theirs.
        case remix(row: Data)
        /// One of your own, which saving updates.
        case edit(uuid: String, row: Data)
    }

    let host: ExperienceDesignerHost
    /// Called with the uuid each time the experience is saved.
    var onSaved: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var document: ExperienceDocument
    @State private var stepId = ""
    @State private var message = ""
    @State private var messageIsSuccess = false
    @State private var isSaving = false
    @State private var isPreviewing = false
    /// Whether the last step change went forward, so the form slides the
    /// way the author is travelling.
    @State private var isForward = true
    @State private var saves = 0
    @State private var refusals = 0
    @Namespace private var rail

    @State private var path: [Pane] = []

    /// - Parameters:
    ///   - type: the experience type to start on — a class name from
    ///     experiences.json — or `nil` to ask.
    ///   - step: the step to open on, when not the type's first.
    init(
        host: ExperienceDesignerHost, type: String? = nil, step: String? = nil, seed: Seed? = nil,
        onSaved: @escaping (String) -> Void = { _ in }
    ) {
        self.host = host
        self.onSaved = onSaved
        // Before the first render: the Style step and the preview ask for the
        // font catalogue while drawing, and that request must reach the host.
        host.install()
        let document = ExperienceDocument()
        if let type, ExperienceSchema.isKnown(type) { document.type = type }
        switch seed {
        case .remix(let row):
            ExperienceCodec.apply(json: String(decoding: row, as: UTF8.self), to: document, defaultType: type ?? "")
        case .edit(let uuid, let row):
            ExperienceCodec.apply(json: String(decoding: row, as: UTF8.self), to: document, defaultType: type ?? "")
            document.adopt(savedUuid: uuid)
        case nil:
            break
        }
        _document = State(initialValue: document)
        let schema = ExperienceSchema.forType(document.type)
        _stepId = State(initialValue: DocumentText.trimmed(document.type).isEmpty ? "" : (step ?? schema.steps.startingStep.id))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                if DocumentText.trimmed(document.type).isEmpty {
                    DesignerTypePicker { schema in
                        withAnimation(.smooth(duration: 0.4)) {
                            document.type = schema.type
                            stepId = schema.steps.startingStep.id
                        }
                    }
                    .transition(.asymmetric(insertion: .identity, removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    editor
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .navigationDestination(for: Pane.self, destination: pane)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(DocumentText.trimmed(document.type).isEmpty ? Color.maqrAccent : schema.tint)
        .sensoryFeedback(.selection, trigger: stepId)
        .sensoryFeedback(.success, trigger: saves)
        .sensoryFeedback(.warning, trigger: refusals)
    }

    // MARK: - Editing

    private var schema: ExperienceSchema { ExperienceSchema.forType(document.type) }
    private var step: DesignerStep { schema.steps.step(id: stepId) }
    private var stepIndex: Int { schema.steps.firstIndex { $0.id == step.id } ?? 0 }

    private var editor: some View {
        let schema = self.schema
        let step = self.step
        let sections = DocumentForm.sections(
            for: step,
            schema: schema,
            document: document,
            pushColor: { _ in },
            pushImage: { path.append(Pane(kind: .image($0))) },
            pushCopy: { kind, onCopy in path.append(Pane(kind: .copy(kind, onCopy))) },
            pushFont: { path.append(Pane(kind: .font($0))) },
            exportMessage: message,
            inlineColors: true,
            onCreate: create)

        return ZStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Step \(stepIndex + 1) of \(schema.steps.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                            .textCase(.uppercase)
                        Text(step.title).font(.title2.bold())
                        Text(step.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    DesignerSection(spec: section)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            // A fresh form per step, sliding the way the author is going.
            .id(step.id)
            .transition(.asymmetric(
                insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)))
        }
        .clipped()
        .safeAreaInset(edge: .top, spacing: 0) { stepRail(schema.steps) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if !message.isEmpty { messageBanner.transition(.move(edge: .bottom).combined(with: .opacity)) }
                stepButtons(schema.steps)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: Catalog.symbol(forType: schema.type)).foregroundStyle(.tint)
                    Text(schema.displayName).font(.headline)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Preview", systemImage: "iphone") { isPreviewing = true }
            }
        }
        .sheet(isPresented: $isPreviewing) {
            NavigationStack {
                ScrollView {
                    DesignerPreview(document: document, schema: schema, step: step)
                        .frame(minHeight: 560, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.85), lineWidth: 8)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                        .padding(.horizontal, 28)
                        .padding(.vertical)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(step.previewTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { isPreviewing = false } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Saving…").font(.subheadline.weight(.medium))
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isSaving)
        .animation(.snappy, value: message)
    }

    private func go(to id: String) {
        guard id != stepId else { return }
        let steps = schema.steps
        let from = steps.firstIndex { $0.id == stepId } ?? 0
        let to = steps.firstIndex { $0.id == id } ?? 0
        isForward = to >= from
        withAnimation(.smooth(duration: 0.35)) { stepId = id }
    }

    /// Every step as a chip, the current one lit and kept in view, over a
    /// thin bar of how far along the author is.
    private func stepRail(_ steps: [DesignerStep]) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                            let isCurrent = item.id == step.id
                            Button { go(to: item.id) } label: {
                                HStack(spacing: 6) {
                                    Text("\(index + 1)")
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .frame(width: 18, height: 18)
                                        .background(
                                            isCurrent ? AnyShapeStyle(.white.opacity(0.25)) : AnyShapeStyle(.fill.secondary),
                                            in: Circle())
                                    Text(item.shortTitle).font(.subheadline.weight(isCurrent ? .semibold : .regular))
                                }
                                .padding(.leading, 6)
                                .padding(.trailing, 12)
                                .padding(.vertical, 6)
                                .foregroundStyle(isCurrent ? Color.white : .primary)
                                .background {
                                    if isCurrent {
                                        Capsule().fill(.tint).matchedGeometryEffect(id: "current", in: rail)
                                    } else {
                                        Capsule().fill(.fill.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                            .accessibilityAddTraits(isCurrent ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .onChange(of: stepId) { _, id in
                    withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(stepId, anchor: .center) }
            }
            ProgressView(value: Double(stepIndex + 1), total: Double(max(steps.count, 1)))
                .progressViewStyle(.linear)
                .animation(.smooth, value: stepIndex)
        }
        .background(.bar)
    }

    private var messageBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: messageIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(messageIsSuccess ? .green : .orange)
                .symbolEffect(.bounce, value: message)
            Text(message).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
            Button {
                message = ""
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func stepButtons(_ steps: [DesignerStep]) -> some View {
        HStack(spacing: 12) {
            if let previous = steps.previous(of: step.id) {
                Button { go(to: previous.id) } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Back to \(previous.shortTitle)"))
                .transition(.scale.combined(with: .opacity))
            }
            Spacer()
            if let next = steps.next(of: step.id) {
                Button { go(to: next.id) } label: {
                    HStack(spacing: 6) {
                        Text(next.shortTitle).contentTransition(.opacity)
                        Image(systemName: "chevron.right")
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.snappy, value: step.id)
    }

    // MARK: - Pushed panes

    /// A pushed pane, carrying what it edits. The payload travels in the
    /// path rather than in `@State` beside it: the destination closure reads
    /// a copy of this view, which does not see state set just before the push.
    struct Pane: Hashable {
        enum Kind {
            case image(ImageSlot)
            case font(FontSlot)
            /// The copy picker's list and what a copied entry becomes — the
            /// schema's decision, carried to the pane.
            case copy(CopyKind, (CopyEntry) -> Void)
        }

        let id = UUID()
        let kind: Kind

        static func == (lhs: Pane, rhs: Pane) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    @ViewBuilder private func pane(_ pane: Pane) -> some View {
        switch pane.kind {
        case .image(let slot):
            ImagePane(document: document, slot: slot, host: host)
        case .copy(let kind, let onCopy):
            CopyPane(kind: kind, onCopy: onCopy)
        case .font(let slot):
            FontPane(document: document, slot: slot)
        }
    }

    // MARK: - Creating

    private func create() {
        switch ExperienceCreation.prepare(document, schema: schema) {
        case .refused(let refusal, let stepId):
            messageIsSuccess = false
            message = refusal
            refusals += 1
            if let stepId { go(to: stepId) }
        case .ready(let json):
            isSaving = true
            message = ""
            Task {
                defer { isSaving = false }
                do {
                    let uuid = try await host.save(json)
                    document.adopt(savedUuid: uuid)
                    messageIsSuccess = true
                    message = String(localized: "Saved.")
                    saves += 1
                    onSaved(uuid)
                } catch {
                    messageIsSuccess = false
                    message = String(localized: "Couldn't save: \(error.localizedDescription)")
                    refusals += 1
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

#Preview("Wedding · Style") {
    ExperienceDesignerView(host: .offline, type: ExperienceType.wedding, step: ExperienceSchema.forType(ExperienceType.wedding).steps[2].id)
}
