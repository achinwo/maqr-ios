//
//  ExperienceScreens.swift
//  Maqr
//
//  D1 the hub, D2 code design, D3 download, E1 print templates, E2 one template.
//

import MaqrDashboard
import SwiftUI

// MARK: - D1 · The hub

struct ExperienceHubScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNamespace) private var zoom
    @Environment(\.dismiss) private var dismiss
    let experience: ExperienceStore
    @State private var confirmingDelete = false
    @State private var deleteFailure: String?
    @State private var isDeleting = false

    var body: some View {
        RemoteContent(remote: experience.detail, failureTitle: "That experience couldn't be loaded", retry: experience.load) { detail in
            List {
                Section {
                    statusStrip(detail)
                    if detail.design.liveURL != nil {
                        Button { model.launch(detail.design) } label: {
                            Label("Launch experience", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    }
                    if let notice = experience.sharedNotice {
                        NoticeCard(title: notice.title, message: notice.detail)
                    }
                    QuickActions(id: detail.id, role: detail.role)
                    codeCard(detail)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                Section("Manage") {
                    if detail.may(.edit) {
                        Button { openDesigner(detail) } label: {
                            row("Pages & content", detail.pagesLabel, "doc.richtext")
                        }
                        .foregroundStyle(.primary)
                    }
                    if detail.may(.view) {
                        NavigationLink(value: Route.people(detail.id)) {
                            row("People", detail.may(.manageSharing) ? String(localized: "Share & manage") : String(localized: "Who has access"), "person.2")
                        }
                    }
                    NavigationLink(value: Route.printTemplates(detail.id)) {
                        row("Print templates", String(localized: "\(PrintTemplate.availableCount) available"), "printer")
                    }
                    if detail.may(.notify) {
                        NavigationLink(value: Route.notify(detail.id)) { row("Guest notifications", String(localized: "Message guests"), "bell.badge") }
                    }
                    if detail.may(.analytics) {
                        NavigationLink(value: Route.stats(detail.id)) { row("How it's going", String(localized: "Scans & guests"), "chart.bar") }
                    }
                }

                Section("Publishing") {
                    if detail.may(.publish) {
                        NavigationLink(value: Route.publish(detail.id)) {
                            row("Publishing", experience.publishingValue, "globe")
                        }
                    }
                    if detail.may(.edit) {
                        NavigationLink(value: Route.appClip(detail.id)) {
                            row("App Clip card", experience.appClipValue, "appclip")
                        }
                    }
                    NavigationLink(value: Route.review(detail.id)) {
                        row("Review the details", detail.pagesLabel, "checklist")
                    }
                    if detail.may(.publish) {
                        NavigationLink(value: Route.design(detail.id)) {
                            row("Share & publish", detail.accessLabel, "square.and.arrow.up")
                        }
                    }
                }

                if detail.may(.delete) {
                    Section {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            HStack {
                                Spacer()
                                if isDeleting { ProgressView() } else { Text("Delete this experience") }
                                Spacer()
                            }
                        }
                        .disabled(isDeleting)
                    } footer: {
                        if let deleteFailure {
                            Text(deleteFailure).foregroundStyle(.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(detail.design.title)
            .toolbar {
                if detail.may(.edit) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { openDesigner(detail) }
                    }
                }
                if let live = detail.design.liveURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: live, subject: Text(detail.design.title))
                    }
                }
            }
            .confirmationDialog(
                Text("Delete \(detail.design.title)?"),
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { Task { await delete() } }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text(experience.deleteWarning)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await experience.refresh() }
        .savedCopyBanner(experience.detail)
        .zoomDestination(id: "experience-\(experience.id)", namespace: zoom)
        .sensoryFeedback(.success, trigger: experience.isDeleted)
        .task { await experience.load() }
    }

    private func statusStrip(_ detail: ExperienceDetail) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(detail.experience.status == .upcoming ? Color.maqrLive : Color.secondary)
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse)
            Text(detail.experience.statusLine)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func codeCard(_ detail: ExperienceDetail) -> some View {
        NavigationLink(value: Route.code(detail.id)) {
            HStack(spacing: 14) {
                SavedCodeView(detail: detail)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Your QR code").font(.subheadline.weight(.semibold))
                        if experience.hasPendingCode {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                .foregroundStyle(.orange)
                                .accessibilityLabel(Text("Waiting to sync"))
                        }
                    }
                    Text(detail.style.format == .appclip
                         ? "App Clip Code · iPhone. Tap to restyle, or swap to a QR any phone can read."
                         : "Standard QR · any phone. Tap to restyle, or swap to an App Clip Code.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String?, _ symbol: String) -> some View {
        LabeledContent {
            if let value { Text(value).foregroundStyle(.secondary) }
        } label: {
            Label(label, systemImage: symbol)
        }
    }

    private func openDesigner(_ detail: ExperienceDetail) {
        guard let row = experience.rowJSON else { return }
        model.designer = .edit(uuid: detail.id, row: row)
    }

    private func delete() async {
        isDeleting = true
        deleteFailure = nil
        do {
            try await experience.delete()
            model.popToRoot()
        } catch {
            deleteFailure = DashboardError.from(error).message
        }
        isDeleting = false
    }
}

// MARK: - D2 · Code design

struct CodeDesignScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: CodeDesignStore
    @State private var savedToggle = false
    @State private var queuedNote = false

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: CodeDesignStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("Format", selection: $store.style.format) {
                    ForEach(CodeFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("QR works on every phone. App Clip Codes are iPhone-only — keep a QR as well.")
            }

            Section {
                ExperienceCodeView(url: store.url, style: store.style, appClipSVG: store.appClipSVG)
                    .frame(width: 200, height: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                if let warning = store.appClipWarning {
                    NoticeCard(title: String(localized: "Can't be an App Clip Code"), message: warning, kind: .stop)
                }
                if let note = store.printable.note {
                    NoticeCard(title: String(localized: "Shown the scannable way"), message: note, kind: .alert)
                }
            }

            if store.isAppClip {
                Section("Colour") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.appClipInfo.value?.templates ?? []) { template in
                                Button { store.choose(template: template) } label: {
                                    Circle()
                                        .fill(Color(maqrHex: template.background))
                                        .overlay(Circle().strokeBorder(Color(maqrHex: template.foreground), lineWidth: 8))
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().strokeBorder(Color.maqrAccent, lineWidth: store.style.template == template.index ? 3 : 0).padding(-4))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Palette \(template.index)"))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                Section {
                    Picker("How it is read", selection: $store.style.interaction) {
                        ForEach(InteractionType.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text("The glyph in the middle tells people what to do with it. Choose the NFC mark only if you are pairing the card with a tag — it is a promise the card makes.")
                }
            } else {
                Section("Colour") {
                    HStack(spacing: 12) {
                        ForEach(CodeStyle.colours, id: \.value) { swatch in
                            Button { store.style.foreground = swatch.value } label: {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(maqrHex: swatch.value))
                                    .frame(width: 44, height: 44)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
                                    .overlay {
                                        if store.style.foreground == swatch.value {
                                            Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(swatch.label))
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Picker("Module shape", selection: $store.style.shape) {
                        ForEach(ModuleShape.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Logo in the centre", isOn: $store.style.logo)
                } footer: {
                    Text("Codes are always encoded at the highest error correction, so the badge never costs you a scan.")
                }
            }

            if let error = store.saveError {
                Section { Text("That didn't save — \(error)").foregroundStyle(.red) }
            }
        }
        .animation(.smooth, value: store.style.format)
        .navigationTitle("Code design")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if store.isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(store.isSaving)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    if await save() { model.push(.codeDownload(store.experience.id)) }
                }
            } label: {
                Text(store.isSaving ? "Saving…" : "Download & share").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .alert("Saved on this phone", isPresented: $queuedNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're offline, so the new style will be sent as soon as you're connected again.")
        }
        .sensoryFeedback(.success, trigger: savedToggle)
        .task { await store.load() }
        .task(id: store.style) {
            guard store.isAppClip else { return }
            try? await Task.sleep(for: .milliseconds(250))
            await store.refreshAppClipPreview()
        }
    }

    @discardableResult
    private func save() async -> Bool {
        switch await store.save() {
        case .saved:
            savedToggle.toggle()
            return true
        case .queued:
            queuedNote = true
            return false
        case nil:
            return false
        }
    }
}

// MARK: - D3 · Download

struct CodeDownloadScreen: View {
    @State private var store: CodeDownloadStore
    @State private var shared: SharedFile?

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: CodeDownloadStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        @Bindable var store = store
        RemoteContent(remote: store.experience.detail, retry: store.experience.load) { detail in
            Form {
                Section {
                    SavedCodeView(detail: detail)
                        .frame(width: 180, height: 180)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Section {
                    Picker("File format", selection: $store.format) {
                        ForEach(CodeFileFormat.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("File format")
                } footer: {
                    Text(store.format.note)
                }
                Section {
                    LabeledContent("Print size", value: store.printSize)
                    LabeledContent(store.detailRow.label, value: store.detailRow.value)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Links to").foregroundStyle(.secondary)
                        Text(detail.url).font(.footnote).textSelection(.enabled)
                    }
                }
                Section {
                    NoticeCard(title: String(localized: "Need it on something?"),
                               message: String(localized: "The print templates already include this code."), kind: .alert)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let error = store.error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { if let file = await store.prepare() { shared = SharedFile(url: file) } }
                } label: {
                    Label(store.isPreparing ? String(localized: "Preparing…") : String(localized: "Share \(store.format.label)"),
                          systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isPreparing)
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle("Download")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.experience.ensureLoaded() }
        .sheet(item: $shared) { file in
            ShareSheet(items: [file.url]).presentationDetents([.medium, .large])
        }
    }
}

// MARK: - E1 · Print templates

struct PrintTemplatesScreen: View {
    let experience: ExperienceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ready to print").font(.title2.weight(.bold))
                Text("Already filled in with your details, sections and QR code. Pick one and download a print-ready PDF — no design needed.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(PrintTemplate.all) { template in
                        if template.available {
                            NavigationLink(value: Route.printTemplate(experience.id, template.id)) {
                                TemplateCard(template: template)
                            }
                            .buttonStyle(.plain)
                        } else {
                            TemplateCard(template: template)
                        }
                    }
                }
                if let note = PrintTemplate.comingSoonNote {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Print templates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TemplateCard: View {
    let template: PrintTemplate

    var body: some View {
        let landscape = template.shape == .landscape
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(.fill.quaternary)
                VStack(spacing: 5) {
                    Capsule().fill(.tertiary).frame(width: landscape ? 54 : 40, height: 4)
                    Image(systemName: "qrcode").font(.title3)
                    Capsule().fill(.quaternary).frame(width: landscape ? 40 : 30, height: 3)
                }
                .frame(width: landscape ? 92 : 66, height: landscape ? 62 : 92)
                .background(.background, in: Rectangle())
                .overlay(Rectangle().strokeBorder(.separator))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
            .frame(height: 120)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.subheadline.weight(.semibold))
                Text(template.available ? template.sizeLabel : String(localized: "Coming soon"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(template.available ? Color.maqrAccent : Color.clear, lineWidth: 1.5))
        .opacity(template.available ? 1 : 0.55)
    }
}

// MARK: - E2 · One template

struct PrintTemplateScreen: View {
    @State private var store: PrintStore
    @State private var shared: SharedFile?

    init(dashboard: Dashboard, experience: ExperienceStore, template: PrintTemplate) {
        _store = State(initialValue: PrintStore(dashboard: dashboard, experience: experience, template: template))
    }

    var body: some View {
        RemoteContent(remote: store.experience.detail, retry: store.experience.load) { detail in
            Form {
                Section {
                    TableCardArt(detail: detail)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                }
                Section {
                    Label("Layout is fixed. Your details and code are filled in automatically — nothing to design.", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Size", value: store.template.sizeLabel)
                    LabeledContent("Bleed & crop marks", value: String(localized: "Included"))
                    LabeledContent("Quantity per sheet", value: store.template.perSheet)
                    LabeledContent("Photos", value: store.photosValue)
                } footer: {
                    if store.fields?.photos.isEmpty == true {
                        Text("This experience has no usable photographs, so the card prints as type and code alone. Add artwork in the designer and it appears here.")
                    }
                }
                if let error = store.error {
                    Section { Text("That didn't download — \(error)").foregroundStyle(.red) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { if let file = await store.prepare() { shared = SharedFile(url: file) } }
                } label: {
                    Label(store.isPreparing ? String(localized: "Preparing…") : String(localized: "Get the PDF"), systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isPreparing)
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle(store.template.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.experience.ensureLoaded() }
        .sheet(item: $shared) { file in
            ShareSheet(items: [file.url]).presentationDetents([.medium, .large])
        }
    }
}

/// The table card as it prints, drawn from the same layout the PDF uses.
struct TableCardArt: View {
    let detail: ExperienceDetail

    var body: some View {
        let layout = TableCardLayout.tableCard
        let fields = TableCardFields(detail: detail)
        GeometryReader { proxy in
            let mm = proxy.size.width / layout.page.w
            ZStack(alignment: .topLeading) {
                Color.white
                ForEach(Array(layout.frames.enumerated()), id: \.offset) { index, frame in
                    if index < fields.photos.count {
                        AsyncImage(url: fields.photos[index]) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.15)
                        }
                        .frame(width: frame.box.w * mm, height: frame.box.h * mm)
                        .clipped()
                        .rotationEffect(.degrees(frame.rotate))
                        .position(x: (frame.box.x + frame.box.w / 2) * mm, y: (frame.box.y + frame.box.h / 2) * mm)
                    }
                }
                SavedCodeView(detail: detail)
                    .frame(width: layout.codeArea.w * mm, height: layout.codeArea.h * mm)
                    .position(x: (layout.codeArea.x + layout.codeArea.w / 2) * mm, y: (layout.codeArea.y + layout.codeArea.h / 2) * mm)
                if !fields.sections.isEmpty {
                    ForEach(Array(layout.rules.enumerated()), id: \.offset) { _, rule in
                        Rectangle().fill(Color(maqrHex: "#c9c9cf"))
                            .frame(width: rule.w * mm, height: max(rule.h * mm, 0.5))
                            .position(x: (rule.x + rule.w / 2) * mm, y: (rule.y + rule.h / 2) * mm)
                    }
                }
                block(layout.scanMe, String(localized: "Scan me"), mm)
                block(layout.sections, fields.sections, mm)
                block(layout.thanks, String(localized: "Thank You"), mm)
                if let subtitle = fields.subtitle { block(layout.subtitle, subtitle, mm) }
                block(layout.credit, fields.credit, mm)
                block(layout.footer, String(localized: "Powered by maQR"), mm)
            }
        }
        .aspectRatio(layout.page.w / layout.page.h, contentMode: .fit)
        .overlay(Rectangle().strokeBorder(.separator))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        .environment(\.colorScheme, .light)
    }

    private func block(_ block: TextBlock, _ text: String, _ mm: Double) -> some View {
        let size = block.size * TableCardLayout.mmPerPoint * mm
        let script = block.face == .script || block.face == .scriptBold
        let bold = block.face == .sansBold || block.face == .scriptBold
        return Text(block.upper ? text.uppercased() : text)
            .font(.system(size: size, weight: bold ? .bold : .regular, design: script ? .serif : .default))
            .italic(script)
            .tracking(block.tracking * TableCardLayout.mmPerPoint * mm)
            .foregroundStyle(Color(maqrHex: block.colour))
            .multilineTextAlignment(.center)
            .frame(width: block.w * mm)
            .offset(x: block.x * mm, y: block.y * mm - size * 0.1)
    }
}
