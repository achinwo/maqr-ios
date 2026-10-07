//
//  PublishingScreens.swift
//  Maqr
//
//  C3 review, G1–G6 publishing, H1/H6 plan and billing. Paying happens in
//  the App Store (StoreKit), through MaqrDashboard's Purchasing.swift — the
//  app never sends anyone to a web checkout.
//

import MaqrDashboard
import StoreKit
import SwiftUI

// MARK: - C3 · Review

struct ReviewScreen: View {
    @Environment(AppModel.self) private var model
    let experience: ExperienceStore

    var body: some View {
        RemoteContent(remote: experience.detail, retry: experience.load) { detail in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Everything look right?").font(.title2.weight(.bold))
                        Text("This is what guests will find when they scan the code. Anything here can be changed later — nothing is set in stone by publishing it.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
                Section("What you've made") {
                    LabeledContent("Name", value: detail.design.title)
                    LabeledContent("Type", value: detail.design.category)
                    LabeledContent("Date", value: detail.day == nil ? String(localized: "No date set") : detail.experience.when)
                    LabeledContent("Pages", value: detail.pagesLabel)
                    LabeledContent("Content", value: detail.design.meta)
                    LabeledContent("Photos", value: detail.photos.isEmpty ? String(localized: "None yet") : String(localized: "\(detail.photos.count) to use"))
                    LabeledContent("Code", value: detail.code == nil ? String(localized: "Default style") : String(localized: "Designed"))
                    LabeledContent("Print templates", value: String(localized: "\(PrintTemplate.availableCount) ready"))
                }
                Section {
                    if experience.isLive {
                        NoticeCard(title: String(localized: "Already published"),
                                   message: String(localized: "This experience is live, so there is nothing to pay for here. The hub is where you manage it."))
                    } else if let view = experience.publication.value {
                        NoticeCard(title: view.nextStep.noticeTitle, message: view.nextStep.notice)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if experience.isLive { model.popToRoot(); model.push(.experience(detail.id)) } else { model.push(.publish(detail.id)) }
                } label: {
                    Text(experience.isLive ? String(localized: "Go to the experience") : (experience.publication.value?.nextStep.label ?? String(localized: "Publish")))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        if let row = experience.rowJSON { model.designer = .edit(uuid: detail.id, row: row) }
                    }
                }
            }
        }
        .navigationTitle("Review & create")
        .navigationBarTitleDisplayMode(.inline)
        .task { await experience.load() }
    }
}

// MARK: - G1–G2 · Publish, and the running term

struct PublishScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: PublishStore
    @State private var managingSubscription = false

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: PublishStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        RemoteContent(remote: store.experience.publication, failureTitle: "Publishing couldn't be loaded", retry: store.refresh) { view in
            Group {
                if view.state.isLive { running(view) } else { offer(view) }
            }
            .animation(.smooth, value: view.state)
        }
        .navigationTitle("Publish")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $managingSubscription)
        .onChange(of: managingSubscription) { _, open in
            // Back from Apple's sheet: a change there reaches us as a server
            // notification, so read the state again.
            if !open { Task { await store.refresh() } }
        }
        .refreshable { await store.refresh() }
        .sensoryFeedback(.success, trigger: store.view?.state.isLive)
        .task { await store.load() }
    }

    // Not published, or lapsed: what it would take.
    private func offer(_ view: PublicationView) -> some View {
        List {
            if let lapsed = store.lapsedNotice {
                Section {
                    NoticeCard(title: lapsed.title, message: lapsed.detail, kind: .stop)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What a guest sees when they scan").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This experience isn't published").font(.subheadline.weight(.semibold))
                            Text("Ask whoever shared the code — it can be back in seconds.").font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.offerTitle).font(.title2.weight(.bold))
                    Text(store.offerDetail).font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            if store.covering == nil && view.trialAvailable, let trial = store.region.trialPlan {
                Section {
                    PlanCardView(plan: trial, isSelected: true)
                    NoticeCard(title: String(localized: "When the \(Plans.trialDays) days are up"),
                               message: String(localized: "The experience is unpublished and the code stops opening it. Your design, pages and scan history are kept — choose a plan and it is back instantly."))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if let failure = store.failure {
                Section { NoticeCard(title: String(localized: "That didn't work"), message: failure, kind: .alert) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let plan = store.coveringPlan {
                    primary(store.isBusy ? String(localized: "Publishing…") : String(localized: "Publish on \(plan.name) · no charge")) {
                        Task { await store.publishOnPlan() }
                    }
                } else if view.trialAvailable {
                    primary(store.isBusy ? String(localized: "Starting…") : String(localized: "Start the free trial")) {
                        Task { await store.startTrial() }
                    }
                } else {
                    primary(view.state == .lapsed ? view.restoreLabel : String(localized: "See plans")) {
                        model.push(.plans(view.experience.uuid))
                    }
                }
                if store.coveringPlan != nil || view.trialAvailable {
                    Button(store.seePlansLabel) { model.push(.plans(view.experience.uuid)) }
                }
            }
            .padding()
            .background(.bar)
        }
    }

    // Live or on trial: how long is left, and the term's switches.
    private func running(_ view: PublicationView) -> some View {
        List {
            if let ending = store.endingNotice {
                Section { NoticeCard(title: ending.title, message: ending.detail, kind: .alert) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                if let term = store.term {
                    MeterView(label: store.meterLabel, value: store.meterValue, progress: term.remainingFraction)
                        .padding(.vertical, 6)
                }
                if let notice = store.termNotice {
                    NoticeCard(title: notice.title, message: notice.detail)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                QuickActions(id: view.experience.uuid, role: store.experience.role)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                if let term = store.term {
                    NavigationLink(value: Route.plans(view.experience.uuid)) {
                        LabeledContent("Plan", value: term.planName)
                    }
                }
                NavigationLink(value: Route.plans(view.experience.uuid)) {
                    LabeledContent(store.isTrial ? "Choose a plan" : "Change plan") {
                        Text(store.isTrial ? (store.region.fromPrice.map { String(localized: "From \($0)") } ?? "") : String(localized: "Compare"))
                    }
                }
                if store.managedByAppStore {
                    Button("Manage subscription") { managingSubscription = true }
                }
                if store.showsAutoRenew {
                    Toggle(isOn: Binding(get: { store.autoRenew ?? store.term?.autoRenew ?? false },
                                         set: { on in Task { await store.setAutoRenew(on) } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-renew")
                            Text(store.autoRenewValue).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(store.isSavingAutoRenew)
                }
                if let payment = view.payments.first {
                    NavigationLink(value: Route.published(view.experience.uuid)) {
                        LabeledContent("Receipt", value: Money.format(payment.amount, currency: payment.currency))
                    }
                }
            }
            if let failure = store.failure {
                Section { NoticeCard(title: String(localized: "That couldn't be changed"), message: failure, kind: .alert) }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let renew = store.renewNowLabel {
                VStack(spacing: 6) {
                    primary(renew) { model.push(.plans(view.experience.uuid)) }
                    if let term = store.term {
                        Text("Or let it end on \(Formatting.date(term.expiresAt))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.bar)
            } else if store.isTrial {
                Button { model.push(.plans(view.experience.uuid)) } label: {
                    Text("Choose a plan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isBusy)
    }
}

/// A plan, as a selectable card.
struct PlanCardView: View {
    let plan: Plan
    let isSelected: Bool
    /// The App Store's price when the plan is sold in the app; the catalogue's
    /// label otherwise (the free trial).
    var price: String? = nil
    var priceLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.maqrAccent : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name).font(.subheadline.weight(.semibold))
                    Text(plan.meta).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    if priceLoading && price == nil {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(price ?? plan.priceLabel).font(.headline)
                    }
                    Text(plan.period).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(plan.features, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isSelected ? Color.maqrAccent : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.8 : 1))
        .animation(.snappy, value: isSelected)
    }
}

// MARK: - G3 · Plans

struct PlansScreen: View {
    @Environment(AppModel.self) private var model
    let experience: ExperienceStore
    @State private var store: PlansStore

    init(dashboard: Dashboard, experience: ExperienceStore, initialKind: PlanKind = .oneOff) {
        self.experience = experience
        let store = PlansStore(dashboard: dashboard, uuid: experience.id,
                               currentPlan: experience.publication.value?.term?.planCode)
        if initialKind != .oneOff { store.kind = initialKind }
        _store = State(initialValue: store)
    }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.title).font(.title2.weight(.bold)).contentTransition(.opacity)
                Text(store.detail).font(.footnote).foregroundStyle(.secondary)
                Picker("Kind", selection: $store.kind) {
                    Text("One-off").tag(PlanKind.oneOff)
                    Text("Subscription").tag(PlanKind.subscription)
                }
                .pickerStyle(.segmented)
                ForEach(store.plans) { plan in
                    Button { store.chosen = plan.code } label: {
                        PlanCardView(plan: plan, isSelected: plan.code == store.selected?.code,
                                     price: store.price(for: plan), priceLoading: !store.pricesLoaded)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                if store.renewing {
                    NoticeCard(title: String(localized: "Another year on Single"),
                               message: String(localized: "This adds twelve months from the end of the current term, at the renewal price."))
                }
                if experience.publication.value?.state == .lapsed {
                    NoticeCard(title: String(localized: "Nothing needs reprinting"),
                               message: String(localized: "The code never changes. Whichever of these you choose, the experience is republished at the same address the printed codes already point at."))
                }
                if store.pricesLoaded && store.prices.isEmpty {
                    NoticeCard(title: String(localized: "Plans couldn't be loaded"),
                               message: String(localized: "The App Store didn't answer. Check your connection and try again."), kind: .alert)
                }
                if let failure = store.failure {
                    NoticeCard(title: String(localized: "That didn't work"), message: failure, kind: .alert)
                }
                if let restored = store.restoreMessage {
                    NoticeCard(title: String(localized: "Restore purchases"), message: restored)
                }
                legal
            }
            .padding()
            .animation(.smooth, value: store.kind)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    Task {
                        if let view = await store.buy() {
                            experience.adopt(view)
                            model.push(.published(view.experience.uuid))
                        }
                    }
                } label: {
                    Text(store.continueLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.canBuy)
                Button(store.isRestoring ? String(localized: "Restoring…") : String(localized: "Restore Purchases")) {
                    Task {
                        await store.restore()
                        await experience.refresh()
                    }
                }
                .font(.footnote)
                .disabled(store.isRestoring || store.isBuying)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Choose a plan")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: store.chosen)
        .task { await store.load() }
    }

    /// What the App Store requires beside a purchase — what it is, how it
    /// renews, and the terms and privacy policy.
    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.disclosure).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: model.dashboard.webURL("/joli_end_user_license_agreement.html"))
                Link("Privacy Policy", destination: model.dashboard.webURL("/joli_privacy_policy.html"))
            }
            .font(.caption)
        }
        .padding(.top, 4)
    }
}

// MARK: - G6 · Receipt

struct PublishedScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: PublishStore

    init(dashboard: Dashboard, experience: ExperienceStore) {
        _store = State(initialValue: PublishStore(dashboard: dashboard, experience: experience))
    }

    var body: some View {
        RemoteContent(remote: store.experience.publication, retry: store.refresh) { view in
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: view.state.isLive ? "checkmark.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(view.state.isLive ? Color.maqrLive : .secondary)
                        .symbolEffect(.bounce, value: view.state)
                    VStack(spacing: 6) {
                        Text(store.receiptTitle).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                        Text(store.receiptDetail).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if let detail = store.experience.detail.value {
                        SavedCodeView(detail: detail).frame(width: 200, height: 200)
                    }
                    if let term = view.term {
                        HStack(spacing: 12) {
                            tile(Formatting.date(term.expiresAt), "Live until")
                            tile(term.renewalAmount.map { Money.format($0, currency: term.currency) } ?? "—",
                                 term.renewalAmount == nil ? "Does not renew" : "Renews at")
                        }
                        if !term.autoRenew {
                            NoticeCard(title: String(localized: "What happens at the end"),
                                       message: String(localized: "On \(Formatting.date(term.expiresAt)) the experience is unpublished: the printed code still scans and tells guests it isn't available, and paying again puts it straight back."))
                        }
                    }
                    VStack(spacing: 10) {
                        Button { model.popToRoot(); model.push(.experience(view.experience.uuid)) } label: {
                            Text("Go to the experience").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        NavigationLink(value: Route.codeDownload(view.experience.uuid)) { Text("Share the code") }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: store.view?.state.isLive)
        .task { await store.load() }
    }

    private func tile(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.headline)
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - H1, H6 · Plan & billing

struct BillingScreen: View {
    @Environment(AppModel.self) private var model
    @State private var store: BillingStore
    @State private var managingSubscriptions = false

    init(dashboard: Dashboard) {
        _store = State(initialValue: BillingStore(dashboard: dashboard))
    }

    var body: some View {
        RemoteContent(remote: store.billing, failureTitle: "Billing couldn't be loaded", retry: store.refresh) { view in
            List {
                if let subscription = store.subscription {
                    if store.subscriptionEnded {
                        Section {
                            NoticeCard(title: String(localized: "\(subscription.planName) subscription ended"),
                                       message: String(localized: "It ran to \(Formatting.date(subscription.expiresAt)), and every experience it published is now unpublished — none of them are deleted."),
                                       kind: .stop)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } else {
                        currentPlan(subscription)
                    }
                }
                if store.isEmpty {
                    ContentUnavailableView("Nothing on this account yet", systemImage: "creditcard", description: Text(store.emptyDetail))
                }
                if store.showsPayment {
                    Section("Payment") {
                        LabeledContent("Receipts", value: "\(view.payments.count)")
                    }
                }
                Section {
                    Button(store.isRestoring ? String(localized: "Restoring…") : String(localized: "Restore Purchases")) {
                        Task { await store.restore() }
                    }
                    .disabled(store.isRestoring)
                    Button("Manage subscriptions") { managingSubscriptions = true }
                } header: {
                    Text("App Store")
                } footer: {
                    if let message = store.restoreMessage { Text(message) }
                }
                if !store.unpublished.isEmpty {
                    Section("Unpublished") { rows(store.unpublished) }
                }
                if !store.live.isEmpty {
                    Section("What you're paying for") { rows(store.live) }
                }
                if let restart = store.restartLabel {
                    Section {
                        if let subscription = store.subscription, let plan = Plans.all[subscription.planCode] {
                            PlanCardView(plan: plan, isSelected: true)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        Button(restart) {
                            if let uuid = store.restartExperience { model.push(.plans(uuid)) }
                        }
                        .disabled(store.restartExperience == nil)
                    } header: {
                        Text("Put them back")
                    } footer: {
                        Text("Nothing needs reprinting. Every experience comes back on the code it already has, with its pages and its scan history untouched.")
                    }
                }
            }
        }
        .navigationTitle("Plan & billing")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .savedCopyBanner(store.billing)
        .manageSubscriptionsSheet(isPresented: $managingSubscriptions)
        .onChange(of: managingSubscriptions) { _, open in
            if !open { Task { await store.refresh() } }
        }
        .task { await store.load() }
    }

    private func currentPlan(_ subscription: BillingSubscription) -> some View {
        Section {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.planName).font(.headline)
                    Text(subscription.coversLine).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: subscription.autoRenew ? String(localized: "Active") : String(localized: "Ending"),
                            tone: subscription.autoRenew ? .accent : .muted)
            }
            LabeledContent("Live until", value: Formatting.date(subscription.expiresAt))
            LabeledContent("Renews", value: subscription.autoRenew && subscription.renewalAmount != nil
                           ? String(localized: "\(Money.format(subscription.renewalAmount ?? 0, currency: subscription.currency)) · yearly")
                           : String(localized: "Does not renew"))
            LabeledContent("Auto-renew", value: subscription.autoRenew ? String(localized: "On") : String(localized: "Off"))
            if subscription.daysLeft <= 30 {
                MeterView(label: Formatting.daysLeft(subscription.daysLeft),
                          value: String(localized: "Ends \(Formatting.date(subscription.expiresAt))"),
                          progress: Double(max(subscription.daysLeft, 0)) / 30)
            }
        }
    }

    private func rows(_ rows: [BillingExperience]) -> some View {
        ForEach(rows) { row in
            NavigationLink(value: Route.publish(row.experience.uuid)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.experience.title)
                    Text(row.billingValue).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#if DEBUG
// MARK: - Previews

/// The App Store, as a preview needs it: the prices in Maqr/StoreKit/Maqr.storekit
/// and no purchases. Used for the plans screen's previews, which are also the
/// App Review screenshots for the in-app purchases.
private final class PreviewPurchasing: StorePurchasing, @unchecked Sendable {
    let prices = [
        "com.smartstickr.Smartz.publish.weekend": "£11.99",
        "com.smartstickr.Smartz.publish.single": "£28.99",
        "com.smartstickr.Smartz.publish.single.renew": "£18.99",
        "com.smartstickr.Smartz.plan.creator.yearly": "£76.99",
        "com.smartstickr.Smartz.plan.studio.yearly": "£229.99",
    ]
    func displayPrices(for productIds: [String]) async -> [String: String] { prices }
    func purchase(productId: String, appAccountToken: UUID) async throws -> PurchaseOutcome { .cancelled }
    func restorableTransactions() async throws -> [String] { [] }
}

private func previewPlans(_ kind: PlanKind) -> some View {
    let client = MaqrClient(site: URL(string: "https://maqr.co")!,
                            device: DeviceIdentity(uuid: "preview", name: "Preview", model: "iPhone"))
    let dashboard = Dashboard(client: client, container: try! DashboardSchema.container(inMemory: true))
    dashboard.purchasing = PreviewPurchasing()
    let model = AppModel(dashboard: dashboard)
    return NavigationStack {
        PlansScreen(dashboard: dashboard, experience: ExperienceStore(dashboard: dashboard, id: "demo-harbour-chilli"),
                    initialKind: kind)
    }
    .environment(model)
}

#Preview("Plans · one-off") { previewPlans(.oneOff) }
#Preview("Plans · subscription") { previewPlans(.subscription) }
#endif
