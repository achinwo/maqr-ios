//
//  DashboardRoot.swift
//  Maqr
//
//  The app's front door: four tabs — Home, Explore, Create, Me — each its
//  own navigation stack, with sign-in, the designer and the web checkout
//  presented over them.
//

import MaqrDashboard
import SwiftUI

struct DashboardRoot: View {
    @State var model: AppModel
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoom

    var body: some View {
        @Bindable var model = model
        let dashboard = model.dashboard

        TabView(selection: Binding(get: { model.tab }, set: { model.selectTab($0) })) {
            NavigationStack(path: $model.homePath) {
                Group {
                    if model.isSignedIn {
                        HomeScreen(dashboard: dashboard)
                    } else {
                        SignedOutPrompt(
                            title: "Your experiences live here",
                            message: "Sign in to see what you've made, what's coming up and how it's going.",
                            symbol: "house")
                    }
                }
                .withRoutes()
            }
            .id(dashboard.accountRevision)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $model.explorePath) {
                ExploreScreen(dashboard: dashboard).withRoutes()
            }
            .id(dashboard.accountRevision)
            .tabItem { Label("Explore", systemImage: "safari") }
            .tag(AppTab.explore)

            Color.clear
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }
                .tag(AppTab.create)

            NavigationStack(path: $model.mePath) {
                Group {
                    if model.isSignedIn {
                        MeScreen(dashboard: dashboard)
                    } else {
                        SignedOutPrompt(
                            title: "Your account",
                            message: "Sign in to manage your plan, your designs and who you share them with.",
                            symbol: "person.crop.circle")
                    }
                }
                .withRoutes()
            }
            .id(dashboard.accountRevision)
            .tabItem { Label("Me", systemImage: "person.crop.circle") }
            .tag(AppTab.me)
        }
        .tint(.maqrAccent)
        .preferredColorScheme(appearance.colorScheme)
        .sensoryFeedback(.selection, trigger: model.tab)
        .sheet(item: $model.signIn) { request in
            SignInSheet(dashboard: dashboard, request: request)
        }
        .fullScreenCover(item: $model.designer) { request in
            DesignerCover(request: request)
        }
        .sheet(item: $model.webHandoff) { handoff in
            WebHandoffSheet(handoff: handoff)
        }
        .fullScreenCover(item: $model.launching) { handoff in
            WebHandoffSheet(handoff: handoff, sharesLink: true)
        }
        .onOpenURL { model.open($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { model.open(url) }
        }
        .onChange(of: dashboard.accountRevision) { model.accountChanged() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                _ = await dashboard.session.validate()
                await dashboard.flushOutbox()
            }
        }
        .overlay(alignment: .top) { OfflinePill(isOnline: dashboard.connectivity.isOnline) }
        // Last, so the sheets and covers above see them too: a presented
        // view only inherits what is set outside its modifier.
        .environment(model)
        .environment(\.zoomNamespace, zoom)
    }
}

/// The designer, over everything, opened on whatever was asked for.
private struct DesignerCover: View {
    @Environment(AppModel.self) private var model
    let request: DesignerRequest

    var body: some View {
        let host = ExperienceDesignerHost.live(client: model.dashboard.client)
        Group {
            switch request {
            case .new:
                ExperienceDesignerView(host: host, onSaved: saved)
            case .remix(_, let row):
                ExperienceDesignerView(host: host, seed: .remix(row: row), onSaved: saved)
            case .edit(let uuid, let row):
                ExperienceDesignerView(host: host, seed: .edit(uuid: uuid, row: row), onSaved: saved)
            }
        }
    }

    private func saved(_ uuid: String) {
        // The experience is new or changed; the hub re-reads it next time.
        Task { await model.experienceStore(uuid).refresh() }
    }
}

/// What a signed-in tab shows to somebody who is not.
struct SignedOutPrompt: View {
    @Environment(AppModel.self) private var model
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            Button("Sign in") { model.requireAccount {} }
                .buttonStyle(.borderedProminent)
            Button("Look around first") { model.tab = .explore }
        }
    }
}

/// A small pill at the top while offline.
private struct OfflinePill: View {
    let isOnline: Bool

    var body: some View {
        if !isOnline {
            Label("Offline", systemImage: "wifi.slash")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 2)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

// MARK: - Routes

extension View {
    /// Every screen a route can push, available on any stack.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteScreen(route: route)
        }
    }
}

private struct RouteScreen: View {
    @Environment(AppModel.self) private var model
    let route: Route

    var body: some View {
        let dashboard = model.dashboard
        switch route {
        case .design(let id):
            DesignDetailScreen(dashboard: dashboard, id: id)
        case .events:
            EventsScreen(dashboard: dashboard)
        case .billing:
            BillingScreen(dashboard: dashboard)
        case .invitation(let token):
            InvitationScreen(dashboard: dashboard, token: token)
        case .experience(let id):
            ExperienceHubScreen(experience: model.experienceStore(id))
        case .code(let id):
            CodeDesignScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .codeDownload(let id):
            CodeDownloadScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .printTemplates(let id):
            PrintTemplatesScreen(experience: model.experienceStore(id))
        case .printTemplate(let id, let template):
            if let template = PrintTemplate.template(id: template), template.available {
                PrintTemplateScreen(dashboard: dashboard, experience: model.experienceStore(id), template: template)
            } else {
                PrintTemplatesScreen(experience: model.experienceStore(id))
            }
        case .stats(let id):
            AnalyticsScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .notify(let id):
            NotifyScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .people(let id):
            PeopleScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .review(let id):
            ReviewScreen(experience: model.experienceStore(id))
        case .publish(let id):
            PublishScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .plans(let id):
            PlansScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .published(let id):
            PublishedScreen(dashboard: dashboard, experience: model.experienceStore(id))
        case .appClip(let id):
            AppClipScreen(store: appClip(id))
        case .appClipCard(let id):
            AppClipDetailsScreen(store: appClip(id))
        case .appClipBanner(let id):
            AppClipBannerScreen(store: appClip(id))
        case .appClipStatus(let id):
            AppClipStatusScreen(store: appClip(id))
        }
    }

    private func appClip(_ id: String) -> AppClipStore {
        AppClipStore(dashboard: model.dashboard, experience: model.experienceStore(id))
    }
}
