//
//  ExperienceDesignerView.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import GuestExperience
import MaqrDashboard
import SwiftUI

/// The experience designer, composing sections (Phase 3 of
/// docs/architecture/composable-experiences.md in maqr-server).
///
/// The steps are derived from the document: Welcome (identity), Style
/// (theme and layout), one step per section in document order, Sections
/// (add, reorder, hide, remove), then Review. Each section's form is its
/// manifest's; the preview is the guest engine itself, drawing the document
/// as it is typed. Saves are whole documents through `POST` / `PUT
/// /api/experiences`.
struct ExperienceDesignerView: View {
    /// What the designer opens on.
    enum Seed: Hashable {
        /// A template, chosen first.
        case new
        /// A copy of someone's experience: everything but its id and its
        /// accounts, so saving makes a new experience.
        case remix(uuid: String)
        /// One of your own, which saving updates.
        case edit(uuid: String)
    }

    let host: ExperienceDesignerHost
    var seed: Seed = .new
    /// Called with the uuid each time the experience is saved.
    var onSaved: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CompositionDraft?
    @State private var loadFailure: String?
    @State private var isLoading = false

    init(host: ExperienceDesignerHost, seed: Seed = .new, onSaved: @escaping (String) -> Void = { _ in }) {
        self.host = host
        self.seed = seed
        self.onSaved = onSaved
        // Before the first render: the Style step and the preview ask for the
        // font catalogue while drawing, and that request must reach the host.
        host.install()
    }

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    DesignerEditor(draft: draft, host: host, onSaved: onSaved)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadFailure {
                    ContentUnavailableView {
                        Label("Couldn't open this", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadFailure)
                    } actions: {
                        Button("Try again") { Task { await open() } }.buttonStyle(.borderedProminent)
                    }
                } else {
                    TemplatePicker(host: host) { template in Task { await start(template) } }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(.maqrAccent)
        .task { await open() }
    }

    private func open() async {
        guard draft == nil else { return }
        let uuid: String
        switch seed {
        case .new: return
        case .remix(let id), .edit(let id): uuid = id
        }
        isLoading = true
        loadFailure = nil
        defer { isLoading = false }
        do {
            let envelope = try await host.open(uuid)
            if case .edit = seed {
                guard envelope.canEdit else {
                    loadFailure = String(localized: "You can't edit this experience.")
                    return
                }
                let document = JSONValue.parse(envelope.documentJSON) ?? .null
                withAnimation(.smooth) {
                    draft = CompositionDraft(document: document, templateCode: envelope.templateCode, category: envelope.category, uuid: envelope.uuid)
                }
            } else {
                withAnimation(.smooth) {
                    draft = .starting(json: envelope.documentJSON, templateCode: envelope.templateCode, category: envelope.category)
                }
            }
        } catch {
            loadFailure = error.localizedDescription
        }
    }

    private func start(_ template: TemplateSummary) async {
        isLoading = true
        loadFailure = nil
        defer { isLoading = false }
        do {
            let json = try await host.templateDocument(template.code)
            withAnimation(.smooth(duration: 0.4)) {
                draft = .starting(json: json, templateCode: template.code, category: template.category)
            }
        } catch {
            loadFailure = error.localizedDescription
        }
    }
}

// MARK: - The editor

/// A step of the designer.
private enum DesignerStep: Hashable {
    case welcome
    case style
    case block(String)
    case sections
    case review
}

private struct DesignerEditor: View {
    @Bindable var draft: CompositionDraft
    let host: ExperienceDesignerHost
    let onSaved: (String) -> Void

    @State private var step: DesignerStep = .welcome
    @State private var isForward = true
    @State private var message = ""
    @State private var messageIsSuccess = false
    @State private var isSaving = false
    @State private var isPreviewing = false
    @State private var isAdding = false
    @State private var address = ""
    @State private var saves = 0
    @State private var refusals = 0
    @Namespace private var rail

    private var registry: BlockRegistry { GuestEngine.registry }

    private var steps: [DesignerStep] {
        [.welcome, .style] + draft.blocks.compactMap { $0["id"].string.map(DesignerStep.block) } + [.sections, .review]
    }

    private var stepIndex: Int { steps.firstIndex(of: step) ?? 0 }

    var body: some View {
        Form { content }
            .scrollDismissesKeyboard(.interactively)
            // A fresh form per step, sliding the way the author is going.
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)))
            .clipped()
            .safeAreaInset(edge: .top, spacing: 0) { stepRail }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if !message.isEmpty { messageBanner.transition(.move(edge: .bottom).combined(with: .opacity)) }
                    stepButtons
                }
            }
            .navigationTitle(draft.value("identity.title").text.isEmpty ? String(localized: "New experience") : draft.value("identity.title").text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Preview", systemImage: "iphone") { isPreviewing = true }
                }
            }
            .sheet(isPresented: $isPreviewing) { preview }
            .sheet(isPresented: $isAdding) { library }
            .disabled(isSaving)
            .overlay { if isSaving { savingBadge } }
            .animation(.snappy, value: isSaving)
            .animation(.snappy, value: message)
            .sensoryFeedback(.selection, trigger: step)
            .sensoryFeedback(.success, trigger: saves)
            .sensoryFeedback(.warning, trigger: refusals)
            .onChange(of: steps) { _, steps in
                if !steps.contains(step) { step = .sections }
            }
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .style: styleStep
        case .block(let id): blockStep(id)
        case .sections: sectionsStep
        case .review: reviewStep
        }
    }

    private func heading(_ title: String, _ summary: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tint).textCase(.uppercase)
                Text(title).font(.title2.bold())
                if !summary.isEmpty { Text(summary).font(.subheadline).foregroundStyle(.secondary) }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
        }
    }

    private func fields(_ title: String, footer: String = "", _ fields: [BlockField]) -> some View {
        Section {
            ForEach(fields, id: \.path) { field in
                FieldRow(field: field, value: draft.value(field.path), set: { draft.set(field.path, $0) }, host: host)
            }
        } header: {
            Text(title)
        } footer: {
            if !footer.isEmpty { Text(footer) }
        }
    }

    @ViewBuilder private var welcomeStep: some View {
        heading(String(localized: "Welcome"), String(localized: "The name, the line under it and the pictures guests see first."))
        fields(String(localized: "Welcome"), [
            BlockField(path: "identity.title", label: String(localized: "Name"), type: "text", placeholder: String(localized: "Esther & Jide")),
            BlockField(path: "identity.subtitle", label: String(localized: "Welcome message"), type: "textarea",
                       placeholder: String(localized: "Saturday 12 June · Lagos")),
            BlockField(path: "identity.when", label: String(localized: "Date"), type: "date",
                       hint: String(localized: "Optional. What makes it an event: the dashboard counts down to it.")),
        ])
        fields(String(localized: "Pictures"), [
            BlockField(path: "identity.banner", label: String(localized: "Banner"), type: "image"),
            BlockField(path: "identity.logo", label: String(localized: "Portrait or logo"), type: "image"),
            BlockField(path: "identity.bannerVideo", label: String(localized: "Banner video"), type: "url",
                       hint: String(localized: "Optional. A YouTube link played from the banner."), placeholder: "https://youtu.be/…"),
        ])
        fields(String(localized: "Contact & links"), [
            BlockField(path: "identity.contact.email", label: String(localized: "Email"), type: "email"),
            BlockField(path: "identity.contact.phone", label: String(localized: "Phone"), type: "tel"),
            BlockField(path: "identity.links.instagram", label: "Instagram", type: "text", placeholder: "@handle"),
            BlockField(path: "identity.links.x", label: "X", type: "text", placeholder: "@handle"),
            BlockField(path: "identity.links.tiktok", label: "TikTok", type: "text", placeholder: "@handle"),
            BlockField(path: "identity.links.facebook", label: "Facebook", type: "text"),
            BlockField(path: "identity.links.website", label: String(localized: "Website"), type: "url"),
            BlockField(path: "identity.links.websiteLabel", label: String(localized: "Website label"), type: "text"),
        ])
        fields(String(localized: "App Clip card"), footer: String(localized: "What a phone shows before the page opens. Empty uses the name and banner."), [
            BlockField(path: "identity.card.title", label: String(localized: "Card title"), type: "text"),
            BlockField(path: "identity.card.subtitle", label: String(localized: "Card subtitle"), type: "text"),
            BlockField(path: "identity.card.image", label: String(localized: "Card image"), type: "image"),
        ])
    }

    @ViewBuilder private var styleStep: some View {
        heading(String(localized: "Style"), String(localized: "How the page is laid out, and its colours and type."))
        fields(String(localized: "Layout"), [
            BlockField(path: "layout.kind", label: String(localized: "Layout"), type: "choice", options: [
                BlockOption(value: "hub", label: String(localized: "Home screen with tiles")),
                BlockOption(value: "scroll", label: String(localized: "One long page")),
            ]),
            BlockField(path: "theme.surface", label: String(localized: "Surface"), type: "choice", options: [
                BlockOption(value: "glass-dark", label: String(localized: "Dark glass")),
                BlockOption(value: "card-light", label: String(localized: "Light cards")),
            ]),
        ])
        fields(String(localized: "Colours"), [
            BlockField(path: "theme.palette.primary", label: String(localized: "Main colour"), type: "color"),
            BlockField(path: "theme.palette.secondary", label: String(localized: "Second colour"), type: "color"),
            BlockField(path: "theme.palette.accent", label: String(localized: "Accent"), type: "color"),
        ])
        fields(String(localized: "Background"), [
            BlockField(path: "theme.background.mode", label: String(localized: "Background"), type: "choice", options: [
                BlockOption(value: "none", label: String(localized: "The surface's own")),
                BlockOption(value: "solid", label: String(localized: "Colour")),
                BlockOption(value: "gradient", label: String(localized: "Gradient")),
                BlockOption(value: "image", label: String(localized: "Picture")),
            ]),
            BlockField(path: "theme.background.color1", label: String(localized: "First colour"), type: "color"),
            BlockField(path: "theme.background.color2", label: String(localized: "Second colour"), type: "color"),
            BlockField(path: "theme.background.image", label: String(localized: "Picture"), type: "image"),
        ])
        fields(String(localized: "Type"), [
            BlockField(path: "theme.typography.display", label: String(localized: "Typeface"), type: "font"),
        ])
        textStyle(String(localized: "Name style"), path: "theme.typography.styles.title")
        textStyle(String(localized: "Welcome style"), path: "theme.typography.styles.subtitle")
    }

    /// A text style — `TextStyle` in shared/text_style.ts — field by field.
    private func textStyle(_ title: String, path: String) -> some View {
        fields(title, [
            BlockField(path: "\(path).bold", label: String(localized: "Bold"), type: "toggle"),
            BlockField(path: "\(path).italic", label: String(localized: "Italic"), type: "toggle"),
            BlockField(path: "\(path).textAlign", label: String(localized: "Alignment"), type: "choice", options: [
                BlockOption(value: "left", label: String(localized: "Left")),
                BlockOption(value: "center", label: String(localized: "Centre")),
                BlockOption(value: "right", label: String(localized: "Right")),
            ]),
            BlockField(path: "\(path).fontSize", label: String(localized: "Size"), type: "number", placeholder: String(localized: "Automatic")),
            BlockField(path: "\(path).color", label: String(localized: "Colour"), type: "color"),
        ])
    }

    @ViewBuilder private func blockStep(_ id: String) -> some View {
        let kind = draft.blockValue(id, "kind").text
        if let manifest = registry.manifest(kind) {
            heading(sectionTitle(id), manifest.summary)
            ForEach(Array(manifest.form.enumerated()), id: \.offset) { _, group in
                BlockGroupSection(group: group, blockId: id, manifest: manifest, draft: draft, host: host)
            }
            if kind == "gift" { bankAccounts(id) }
        } else {
            heading(sectionTitle(id), String(localized: "This kind of section is edited on the web."))
        }
    }

    /// The gift's accounts — `ownerOnly`, so no manifest form shows them and
    /// no guest's copy of the document holds them.
    @ViewBuilder private func bankAccounts(_ id: String) -> some View {
        ForEach(GiftBank.currencies, id: \.self) { currency in
            Section {
                ForEach(["accountName", "bankName", "accountNumber", "sortCode"], id: \.self) { key in
                    FieldRow(
                        field: BlockField(path: key, label: Self.bankLabel(key), type: key == "accountNumber" || key == "sortCode" ? "tel" : "text"),
                        value: draft.blockValue(id, "props.banks.\(currency).\(key)"),
                        set: { draft.setBlock(id, "props.banks.\(currency).\(key)", $0) }, host: host)
                }
            } header: {
                Text("Bank account · \(currency)")
            } footer: {
                if currency == GiftBank.currencies.last {
                    Text("Shown to guests for a transfer. Only the accounts you fill in appear.")
                }
            }
        }
    }

    private static func bankLabel(_ key: String) -> String {
        switch key {
        case "accountName": String(localized: "Account name")
        case "bankName": String(localized: "Bank")
        case "accountNumber": String(localized: "Account number")
        default: String(localized: "Sort code / routing")
        }
    }

    @ViewBuilder private var sectionsStep: some View {
        heading(String(localized: "Sections"), String(localized: "Add, reorder, hide or remove what the page offers."))
        Section {
            ForEach(draft.blocks.compactMap { $0["id"].string }, id: \.self) { id in
                HStack(spacing: 12) {
                    Image(systemName: symbol(id)).foregroundStyle(.tint).frame(width: 24)
                    Text(sectionTitle(id))
                    Spacer()
                    Toggle("Shown", isOn: SwiftUI.Binding(get: { !draft.isHidden(id) }, set: { draft.setHidden(id, !$0) }))
                        .labelsHidden()
                }
                .swipeActions {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        withAnimation { draft.removeBlock(id) }
                    }
                }
            }
            .onMove { draft.moveBlocks(from: $0, to: $1) }
            Button { isAdding = true } label: { Label("Add a section", systemImage: "plus.circle.fill") }
        } footer: {
            Text("Drag to reorder. A hidden section keeps everything you wrote.")
        }
        .environment(\.editMode, .constant(.active))
    }

    @ViewBuilder private var reviewStep: some View {
        heading(String(localized: "Review"), draft.uuid == nil
            ? String(localized: "Save to create the experience. You can keep editing afterwards.")
            : String(localized: "Save your changes. Guests see them as soon as they're saved."))
        if draft.uuid == nil {
            Section {
                TextField("Optional, e.g. estherandjide", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Address")
            } footer: {
                Text("The end of the link its code opens. Leave empty to get one made for you.")
            }
        }
        Section {
            LabeledContent("Sections", value: "\(draft.composition.sectionTitles(registry: registry).count)")
            ForEach(draft.composition.sectionTitles(registry: registry), id: \.self) { Text($0).foregroundStyle(.secondary) }
        }
        Section {
            Button { save() } label: {
                Label(draft.uuid == nil ? String(localized: "Create experience") : String(localized: "Save changes"), systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Pieces

    private func sectionTitle(_ id: String) -> String {
        guard let block = draft.composition.block(id: id) else { return "" }
        return draft.composition.title(of: block, registry: registry)
    }

    private func symbol(_ id: String) -> String { draft.composition.block(id: id)?.symbol ?? "square" }

    private func shortTitle(_ step: DesignerStep) -> String {
        switch step {
        case .welcome: String(localized: "Welcome")
        case .style: String(localized: "Style")
        case .block(let id): sectionTitle(id)
        case .sections: String(localized: "Sections")
        case .review: String(localized: "Review")
        }
    }

    private func go(to target: DesignerStep) {
        guard target != step else { return }
        isForward = (steps.firstIndex(of: target) ?? 0) >= stepIndex
        withAnimation(.smooth(duration: 0.35)) { step = target }
    }

    /// Every step as a chip, the current one lit and kept in view, over a
    /// thin bar of how far along the author is.
    private var stepRail: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.element) { index, item in
                            let isCurrent = item == step
                            Button { go(to: item) } label: {
                                HStack(spacing: 6) {
                                    Text("\(index + 1)")
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .frame(width: 18, height: 18)
                                        .background(isCurrent ? AnyShapeStyle(.white.opacity(0.25)) : AnyShapeStyle(.fill.secondary), in: Circle())
                                    Text(shortTitle(item)).font(.subheadline.weight(isCurrent ? .semibold : .regular)).lineLimit(1)
                                }
                                .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
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
                            .id(item)
                            .accessibilityAddTraits(isCurrent ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .onChange(of: step) { _, step in withAnimation(.smooth) { proxy.scrollTo(step, anchor: .center) } }
            }
            ProgressView(value: Double(stepIndex + 1), total: Double(max(steps.count, 1)))
                .progressViewStyle(.linear)
                .animation(.smooth, value: stepIndex)
        }
        .background(.bar)
    }

    private var stepButtons: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button { go(to: steps[stepIndex - 1]) } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Back"))
            }
            Spacer()
            if stepIndex + 1 < steps.count {
                Button { go(to: steps[stepIndex + 1]) } label: {
                    HStack(spacing: 6) {
                        Text(shortTitle(steps[stepIndex + 1])).lineLimit(1)
                        Image(systemName: "chevron.right")
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            } else {
                Button { save() } label: {
                    Text(draft.uuid == nil ? "Create" : "Save").font(.body.weight(.semibold)).padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.snappy, value: step)
    }

    private var messageBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: messageIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(messageIsSuccess ? .green : .orange)
                .symbolEffect(.bounce, value: message)
            Text(message).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
            Button { message = "" } label: {
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

    private var savingBadge: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Saving…").font(.subheadline.weight(.medium))
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// The guest page itself, from the document being edited, opened on the
    /// section this step is about.
    private var preview: some View {
        let focus: String = if case .block(let id) = step { draft.composition.block(id: id)?.anchor ?? "" } else { "" }
        return GuestExperienceView(
            experience: GuestExperience(composition: draft.composition, uuid: draft.uuid ?? "", canEdit: true),
            focus: focus)
            .overlay(alignment: .topTrailing) {
                Button("Done") { isPreviewing = false }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.trailing, 16).padding(.top, 10)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
    }

    /// "Add a section": the kinds that fit this layout, less the single ones
    /// already here.
    private var library: some View {
        let existing = draft.blocks.compactMap { $0["kind"].string }
        let offered = registry.library(layout: draft.isHub ? "hub" : "scroll", existingKinds: existing)
        return NavigationStack {
            List(offered, id: \.kind) { manifest in
                Button {
                    let id = draft.addBlock(manifest)
                    isAdding = false
                    go(to: .block(id))
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: Self.symbol(forKind: manifest.kind)).font(.title3).foregroundStyle(.tint).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manifest.name).font(.headline).foregroundStyle(.primary)
                            Text(manifest.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add a section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isAdding = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private static func symbol(forKind kind: String) -> String {
        var object = JSONObject()
        object["id"] = .string("x")
        object["kind"] = .string(kind)
        return ComposedBlock(.object(object))?.symbol ?? "square"
    }

    // MARK: Saving

    private func save() {
        isSaving = true
        message = ""
        let json = draft.json
        let uuid = draft.uuid
        let chosen = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        Task {
            defer { isSaving = false }
            do {
                let envelope = if let uuid {
                    try await host.save(uuid, json)
                } else {
                    try await host.create(json, draft.templateCode, draft.category, chosen.isEmpty ? nil : chosen)
                }
                draft.adopt(savedUuid: envelope.uuid)
                messageIsSuccess = true
                message = uuid == nil ? String(localized: "Created.") : String(localized: "Saved.")
                saves += 1
                onSaved(envelope.uuid)
            } catch {
                messageIsSuccess = false
                message = String(localized: "Couldn't save: \(error.localizedDescription)")
                refusals += 1
            }
        }
    }
}

#Preview("Choose a template") {
    ExperienceDesignerView(host: .offline)
}
