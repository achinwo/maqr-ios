//
//  GuestScreens.swift
//  Maqr
//
//  F1 how it's going, F2 messaging guests, and who an experience is shared with.
//

import Charts
import MaqrDashboard
import SwiftUI

// MARK: - F1 · How it's going

struct AnalyticsScreen: View {
    @State private var store: AnalyticsStore

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: AnalyticsStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: $store.range) {
                    ForEach(AnalyticsRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                RemoteContent(remote: store.summary, failureTitle: "Those figures couldn't be loaded", retry: store.refresh) { summary in
                    VStack(alignment: .leading, spacing: 16) {
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                StatTile(value: "\(summary.scans)", label: "Scans", symbol: "qrcode.viewfinder")
                                StatTile(value: "\(summary.people)", label: "People", symbol: "person.2")
                            }
                            GridRow {
                                StatTile(value: "\(summary.activeNow)", label: "Active now", symbol: "dot.radiowaves.left.and.right")
                                StatTile(value: store.averageVisit, label: "Avg. time", symbol: "clock")
                            }
                        }
                        if let note = store.averageNote {
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                        chart(summary)
                        Text("Most opened").font(.title3.weight(.semibold))
                        if store.topPages.isEmpty {
                            Text("Nobody has opened a section yet. This fills in as guests move around the experience.")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(store.topPages, id: \.label) { page in
                                    LabeledContent(page.label) { Text("\(page.views)").monospacedDigit() }
                                        .padding(.vertical, 11)
                                    Divider()
                                }
                            }
                        }
                        if summary.truncated {
                            Text("This range holds more activity than one summary reads, so these figures are a floor rather than a total.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding()
            .animation(.smooth, value: store.summary.value)
        }
        .safeAreaInset(edge: .bottom) {
            if let summary = store.summary.value {
                NavigationLink(value: Route.notify(store.experience.id)) {
                    Text(store.notifyLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(summary.notifiable == 0)
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle("How it's going")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .savedCopyBanner(store.summary)
        .sensoryFeedback(.selection, trigger: store.range)
        .task { await store.experience.ensureLoaded() }
        .task(id: store.range) { await store.load() }
    }

    private func chart(_ summary: AnalyticsSummary) -> some View {
        let peak = summary.chart.values.max() ?? 0
        let labels = store.axisLabels
        return VStack(alignment: .leading, spacing: 10) {
            Text(store.range.chartTitle).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Chart(Array(summary.chart.values.enumerated()), id: \.offset) { index, value in
                BarMark(x: .value("Period", index), y: .value("Scans", value))
                    .foregroundStyle(value > 0 && value == peak ? Color.maqrAccent : Color.secondary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9]) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), let position = [0, 3, 6, 9].firstIndex(of: index), position < labels.count {
                            Text(labels[position])
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatTile: View {
    let value: String
    let label: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.tint).symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - F2 · Message guests

struct NotifyScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: NotifyStore
    @FocusState private var editing: Bool

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: NotifyStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                audience
            }
            if let outcome = store.outcome {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(outcome.title, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(store.result?.sent ?? 0 > 0 ? Color.maqrLive : .secondary)
                            .symbolEffect(.bounce, value: store.result?.sent)
                        Text(outcome.detail).font(.footnote).foregroundStyle(.secondary)
                        Button("Back to the experience") { model.popToRoot(); model.push(.experience(store.experience.id)) }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    TextField(Insights.placeholder, text: $store.message, axis: .vertical)
                        .lineLimit(3...5)
                        .focused($editing)
                } header: {
                    Text("Message")
                } footer: {
                    HStack {
                        Spacer()
                        Text(store.counter).monospacedDigit().contentTransition(.numericText())
                    }
                }
                Section("Or start from one of these") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Insights.presets, id: \.self) { preset in
                                Chip(title: preset, isSelected: store.message == preset) { store.message = preset }
                            }
                        }
                    }
                }
                Section("Guests will see") {
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.maqrAccent).frame(width: 34, height: 34)
                            .overlay(Image(systemName: "qrcode").foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(store.previewTitle).font(.footnote.weight(.semibold)).lineLimit(1)
                                Spacer()
                                Text("now").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(store.body.isEmpty ? Insights.placeholder : store.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if let failure = store.failure {
                    Section { Text(failure).foregroundStyle(.red) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.outcome == nil {
                VStack(spacing: 6) {
                    Button { Task { editing = false; await store.send() } } label: {
                        Text(store.sendLabel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.canSend)
                    Text(store.resendNote).font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle("Send a message")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: store.result?.sent)
        .task {
            await store.experience.ensureLoaded()
            await store.load()
        }
    }

    @ViewBuilder private var audience: some View {
        if store.audience.isFirstLoad {
            HStack(spacing: 10) {
                ProgressView()
                Text("Counting who's here…").font(.subheadline.weight(.medium))
            }
        } else if let failure = store.audience.failure {
            VStack(alignment: .leading, spacing: 4) {
                Text("Couldn't check who's here").font(.subheadline.weight(.medium))
                Text(failure.message).font(.footnote).foregroundStyle(.secondary)
                Button("Try again") { Task { await store.load() } }.font(.footnote.weight(.medium))
            }
        } else if let audience = store.audience.value {
            let note = Insights.audienceNote(audience)
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(audience.count == 0 ? Color.secondary : Color.maqrLive)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title).font(.subheadline.weight(.semibold))
                    Text(note.detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - People

struct PeopleScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: PeopleStore
    @State private var removing: SharingPerson?
    @State private var confirmingLeave = false

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: PeopleStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        @Bindable var store = store
        List {
            if store.sharing.isFirstLoad {
                ProgressView().frame(maxWidth: .infinity)
            } else if let failure = store.sharing.failure {
                NoticeCard(title: String(localized: "Couldn’t load who has access"), message: failure.message, kind: .alert)
            } else if let state = store.state {
                if store.canManage { inviteForm }
                Section("Who has access") {
                    if let owner = state.owner { personRow(owner, manage: false) }
                    ForEach(state.members) { person in personRow(person, manage: store.canManage) }
                    if state.members.isEmpty && state.invitations.isEmpty {
                        Text(store.canManage ? "Only you, so far." : "Nobody else.").foregroundStyle(.secondary)
                    }
                }
                if store.canManage && !state.invitations.isEmpty {
                    Section("Invited") {
                        ForEach(state.invitations) { invitation in invitationRow(invitation) }
                    }
                }
                if let failure = store.memberFailure {
                    Section { Text(failure).foregroundStyle(.red) }
                }
                if !store.canManage {
                    Section {
                        Button("Leave this experience", role: .destructive) { confirmingLeave = true }
                    }
                }
            } else {
                NoticeCard(title: String(localized: "This isn’t shared with you"),
                           message: String(localized: "Only the people it has been shared with can see who has it."))
            }
        }
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .confirmationDialog(Text("Remove \(removing?.name ?? "")?"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let person = removing { Task { await store.remove(person) } }
            }
        } message: {
            Text("They stop being able to open it straight away. You can invite them again later.")
        }
        .confirmationDialog(Text("Leave \(store.experience.detail.value?.design.title ?? "")?"), isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { Task { await store.leave() } }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("It disappears from your account. You’d need to be invited again to get it back.")
        }
        .onChange(of: store.hasLeft) { _, left in if left { model.popToRoot() } }
        .task {
            await store.experience.ensureLoaded()
            await store.load()
        }
    }

    private var inviteForm: some View {
        @Bindable var store = store
        return Section {
            TextField("name@example.com, another@example.com", text: $store.emails, axis: .vertical)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(2...4)
            Picker("Role", selection: $store.inviteRole) {
                ForEach(MemberRole.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(store.inviteRole.summary).font(.footnote).foregroundStyle(.secondary)
            Button { Task { await store.invite() } } label: {
                Text(store.inviteButtonLabel).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canInvite)
            if let failure = store.inviteFailure {
                NoticeCard(title: String(localized: "Nothing was sent"), message: failure, kind: .alert)
            }
            ForEach(store.inviteLines, id: \.email) { line in
                (Text(line.email).fontWeight(.medium) + Text(verbatim: " — \(line.text)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Share this experience")
        } footer: {
            Text("They don’t need an account yet — we’ll email a link, and they can make one when they open it.")
        }
    }

    private func personRow(_ person: SharingPerson, manage: Bool) -> some View {
        let you = person.userId == store.currentUserId
        return HStack {
            InitialAvatar(name: person.name, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(you ? String(localized: "\(person.name) (you)") : person.name).lineLimit(1)
                if let email = person.email { Text(email).font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            if store.busy.contains("member-\(person.userId)") {
                ProgressView()
            } else {
                Text(person.role.label).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .swipeActions {
            if manage && person.role != .owner {
                Button("Remove", role: .destructive) { removing = person }
                if let role = MemberRole(rawValue: person.role.rawValue) {
                    Button(String(localized: "Make \(role.other.label.lowercased())")) { Task { await store.toggleRole(of: person) } }
                        .tint(.maqrAccent)
                }
            }
        }
        .contextMenu {
            if manage && person.role != .owner, let role = MemberRole(rawValue: person.role.rawValue) {
                Button(String(localized: "Make \(role.other.label.lowercased())"), systemImage: "arrow.left.arrow.right") {
                    Task { await store.toggleRole(of: person) }
                }
                Button("Remove", systemImage: "person.badge.minus", role: .destructive) { removing = person }
            }
        }
    }

    private func invitationRow(_ invitation: SharingInvitation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(invitation.email).lineLimit(1)
                Spacer()
                Text("\(invitation.role.label) · invited").font(.footnote).foregroundStyle(.secondary)
            }
            if let note = store.note(for: invitation) {
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .swipeActions {
            Button("Withdraw", role: .destructive) { Task { await store.withdraw(invitation) } }
            Button("Resend") { Task { await store.resend(invitation) } }.tint(.maqrAccent)
        }
        .contextMenu {
            Button("Resend", systemImage: "paperplane") { Task { await store.resend(invitation) } }
            Button("Withdraw", systemImage: "xmark.circle", role: .destructive) { Task { await store.withdraw(invitation) } }
        }
    }
}

// MARK: - Following an invitation

struct InvitationScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: InvitationStore

    init(dashboard: Dashboard, token: String) {
        _store = State(initialValue: InvitationStore(dashboard: dashboard, token: token))
    }

    var body: some View {
        RemoteContent(remote: store.preview, failureTitle: "This invitation didn't work", retry: store.load) { invitation in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if invitation.status != .pending {
                        NoticeCard(title: Sharing.closedTitle(invitation.status),
                                   message: Sharing.closedMessage(invitation.status, inviter: store.inviter))
                        if invitation.status == .accepted && model.isSignedIn {
                            Button(String(localized: "Open \(store.title)")) { model.push(.experience(invitation.experience.uuid)) }
                                .buttonStyle(.borderedProminent)
                        }
                    } else if store.declined {
                        NoticeCard(title: String(localized: "Invitation declined"),
                                   message: String(localized: "Nothing has been shared with you. If you change your mind, ask \(store.inviter) to invite you again."))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(store.inviter) shared").font(.footnote).foregroundStyle(.secondary)
                            Text(store.title).font(.title2.weight(.semibold))
                            Text("with you as \(store.role.role.withArticle). \(store.role.summary)")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        if let failure = store.failure {
                            NoticeCard(title: String(localized: "That didn’t work"), message: failure, kind: .alert)
                        }
                        Button {
                            model.requireAccount(stage: .create) { Task { await store.accept() } }
                        } label: {
                            Text(store.acceptLabel).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(store.isBusy)
                        Button("No thanks") { Task { await store.decline() } }
                            .frame(maxWidth: .infinity)
                            .disabled(store.isBusy)
                        if !model.isSignedIn {
                            Text("New to maQR? You can make a free account in the next step.")
                                .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.acceptedExperience) { _, uuid in
            if let uuid {
                model.tab = .home
                model.homePath = [.experience(uuid)]
            }
        }
        .task { await store.load() }
    }
}
