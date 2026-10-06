//
//  BrowseScreens.swift
//  Maqr
//
//  A1 Explore, A2 a design, B1 Home and B2 your events.
//

import MaqrDashboard
import SwiftUI

// MARK: - A1 · Explore

struct ExploreScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNamespace) private var zoom
    @State private var store: ExploreStore

    init(dashboard: Dashboard) {
        _store = State(initialValue: ExploreStore(dashboard: dashboard))
    }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro.padding(.horizontal)
                RemoteContent(remote: store.designs, failureTitle: "Couldn't load designs", retry: store.refresh) { designs in
                    if designs.isEmpty {
                        ContentUnavailableView(
                            "Nothing published yet",
                            systemImage: "square.grid.2x2",
                            description: Text("Designs appear here once they're shared publicly."))
                    } else {
                        ChipRow(items: store.categories, selected: store.category, title: { $0 }) { store.category = $0 }
                        grid
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Explore")
        .searchable(text: $store.query, prompt: Text("Search designs"))
        .refreshable { await store.refresh() }
        .savedCopyBanner(store.designs)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
        .task { await store.load() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let user = model.dashboard.session.user {
                Text("Welcome back, \(user.displayName())").font(.headline)
                Text("Tap Remix on any design to open your own copy in the designer.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Browse what people have made").font(.headline)
                Text("Tap Remix on any design to make it yours. No account needed to look.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(store.shown) { design in
                NavigationLink(value: Route.design(design.id)) {
                    DesignCard(design: design) {
                        model.remix(design, row: model.dashboard.local.experience(design.id)?.json)
                    }
                }
                .buttonStyle(.plain)
                .zoomSource(id: "design-\(design.id)", namespace: zoom)
                .contextMenu {
                    DesignMenu(design: design)
                } preview: {
                    DesignPreview(design: design)
                }
                .scrollSettle()
            }
        }
        .padding(.horizontal)
        .animation(.snappy, value: store.shown.map(\.id))
        .overlay {
            if store.shown.isEmpty && !store.query.isEmpty {
                ContentUnavailableView.search(text: store.query)
            }
        }
    }
}

/// What a long press on a design offers.
private struct DesignMenu: View {
    @Environment(AppModel.self) private var model
    let design: Design

    var body: some View {
        Button("Remix this design", systemImage: "wand.and.stars") {
            model.remix(design, row: model.dashboard.local.experience(design.id)?.json)
        }
        if let live = design.liveURL {
            Link(destination: live) { Label("Open as a guest sees it", systemImage: "safari") }
            ShareLink(item: live, subject: Text(design.title)) { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }
}

private struct DesignPreview: View {
    let design: Design

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(url: design.image, symbol: design.symbol).frame(height: 180)
            VStack(alignment: .leading, spacing: 4) {
                Text(design.title).font(.headline)
                Text(design.byline).font(.footnote).foregroundStyle(.secondary)
            }
            .padding([.horizontal, .bottom], 12)
        }
        .frame(width: 300)
    }
}

/// The account in the corner: Sign in, or the initial that opens Me.
struct AccountButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let user = model.dashboard.session.user {
            Button { model.tab = .me } label: { InitialAvatar(name: user.displayName(), size: 30) }
                .accessibilityLabel(Text("Your account"))
        } else {
            Button("Sign in") { model.requireAccount {} }
        }
    }
}

// MARK: - A2 · One design

struct DesignDetailScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNamespace) private var zoom
    @State private var store: DesignStore

    init(dashboard: Dashboard, id: String) {
        _store = State(initialValue: DesignStore(dashboard: dashboard, id: id))
    }

    var body: some View {
        RemoteContent(remote: store.design, failureTitle: "That design couldn't be loaded", retry: store.load) { design in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ArtworkView(url: design.image, symbol: design.symbol)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(design.kind).font(.title3.weight(.semibold))
                        Text(design.byline).font(.footnote).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What's inside").font(.headline).padding(.bottom, 6)
                        ForEach(design.inside, id: \.self) { row in
                            Label {
                                Text(row).foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 9)
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) { actionBar(design) }
            .navigationTitle(design.title)
            .toolbar {
                if let live = design.liveURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: live, subject: Text(design.title))
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .zoomDestination(id: "design-\(store.id)", namespace: zoom)
        .task { await store.load() }
    }

    private func actionBar(_ design: Design) -> some View {
        let action = store.primaryAction
        return VStack(spacing: 8) {
            Button {
                if store.isMine, let row = store.rowJSON {
                    model.designer = .edit(uuid: design.id, row: row)
                } else {
                    model.remix(design, row: store.rowJSON)
                }
            } label: {
                Text(action.label).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text(action.note).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
        .background(.bar)
    }
}

// MARK: - B1 · Home

struct HomeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNamespace) private var zoom
    @State private var store: MyExperiencesStore

    init(dashboard: Dashboard) {
        _store = State(initialValue: MyExperiencesStore(dashboard: dashboard))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greeting
                if store.experiences.isFirstLoad {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if let failure = store.experiences.failure {
                    FailureView(title: "Couldn't load your experiences", error: failure, retry: store.refresh)
                }
                if let hero = store.hero {
                    VStack(spacing: 12) {
                        ZStack(alignment: .topTrailing) {
                            NavigationLink(value: Route.experience(hero.id)) { HeroCard(experience: hero) }
                                .buttonStyle(.plain)
                                .zoomSource(id: "experience-\(hero.id)", namespace: zoom)
                                .contextMenu { ExperienceMenu(experience: hero) }
                            // A sibling, not inside the link: the card manages,
                            // this opens the experience as guests see it.
                            if hero.design.liveURL != nil {
                                LaunchButton { model.launch(hero.design) }
                                    .padding(12)
                            }
                        }
                        QuickActions(id: hero.id, role: hero.design.role)
                    }
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                createCallout
                section("Your designs", link: store.all.isEmpty ? nil : ("See all", .events))
                if store.experiences.value != nil && store.all.isEmpty {
                    Text("Nothing here yet — anything you create shows up in this row.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    row(store.all.map { experience in
                        (experience.id, Route.experience(experience.id),
                         MiniCard(title: experience.design.title,
                                  meta: "\(experience.design.category) · \(experience.badge.lowercased())",
                                  image: experience.design.image, symbol: experience.design.symbol))
                    })
                }
                section("From the community", link: ("Explore", nil))
                row(store.communityRow.map { design in
                    (design.id, Route.design(design.id),
                     MiniCard(title: design.title, meta: design.category, image: design.image, symbol: design.symbol,
                              action: ("Remix this", { model.remix(design, row: model.dashboard.local.experience(design.id)?.json) })))
                })
            }
            .padding()
            .animation(.smooth, value: store.all.map(\.id))
        }
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refresh() }
        .savedCopyBanner(store.experiences)
        .task { await store.load() }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi \(model.dashboard.session.user?.displayName(fallback: "there") ?? "")")
                    .font(.largeTitle.weight(.bold))
                Text(store.liveLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            AccountButton()
        }
        .padding(.top, 8)
    }

    private var createCallout: some View {
        Button { model.selectTab(.create) } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolEffect(.bounce, value: store.all.count)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a new experience").font(.subheadline.weight(.semibold))
                    Text("Wedding, recipe box, brand, re-order…").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.maqrAccent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    private func section(_ title: LocalizedStringKey, link: (LocalizedStringKey, Route?)?) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            if let link {
                Button(link.0) {
                    if let route = link.1 { model.push(route) } else { model.tab = .explore }
                }
                .font(.subheadline.weight(.medium))
            }
        }
    }

    private func row(_ cards: [(String, Route, MiniCard)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(cards, id: \.0) { card in
                    NavigationLink(value: card.1) { card.2 }
                        .buttonStyle(.plain)
                        .zoomSource(id: zoomID(card.1), namespace: zoom)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content.scaleEffect(phase.isIdentity ? 1 : 0.94)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    private func zoomID(_ route: Route) -> String {
        switch route {
        case .experience(let id): return "experience-\(id)"
        case .design(let id): return "design-\(id)"
        default: return "\(route)"
        }
    }
}

/// What a long press on one of your experiences offers.
struct ExperienceMenu: View {
    @Environment(AppModel.self) private var model
    let experience: MyExperience

    var body: some View {
        if experience.design.liveURL != nil {
            Button("Launch", systemImage: "play.fill") { model.launch(experience.design) }
        }
        Button("Manage", systemImage: "slider.horizontal.3") { model.push(.experience(experience.id)) }
        Button("QR code", systemImage: "qrcode") { model.push(.code(experience.id)) }
        if experience.design.role.can(.analytics) {
            Button("How it's going", systemImage: "chart.bar") { model.push(.stats(experience.id)) }
        }
        if let live = experience.design.liveURL {
            ShareLink(item: live, subject: Text(experience.design.title)) { Label("Share link", systemImage: "square.and.arrow.up") }
        }
    }
}

// MARK: - B2 · Your events

struct EventsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.zoomNamespace) private var zoom
    @State private var store: MyExperiencesStore

    init(dashboard: Dashboard) {
        _store = State(initialValue: MyExperiencesStore(dashboard: dashboard))
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: Binding(get: { store.activeStatus }, set: { store.chosenStatus = $0 })) {
                    ForEach(EventStatus.allCases) { status in
                        let count = store.count(status)
                        Text(count > 0 ? "\(status.filterLabel) \(count)" : status.filterLabel).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if store.experiences.isFirstLoad {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let failure = store.experiences.failure {
                    FailureView(title: "Couldn't load your events", error: failure, retry: store.refresh)
                } else if store.shown.isEmpty {
                    Text(store.activeStatus.emptyMessage).foregroundStyle(.secondary)
                } else {
                    ForEach(store.shown) { experience in
                        NavigationLink(value: Route.experience(experience.id)) {
                            EventRow(experience: experience)
                        }
                        .zoomSource(id: "experience-\(experience.id)", namespace: zoom)
                        .contextMenu { ExperienceMenu(experience: experience) }
                        .swipeActions(edge: .leading) {
                            if experience.design.liveURL != nil {
                                Button { model.launch(experience.design) } label: {
                                    Label("Launch", systemImage: "play.fill")
                                }
                                .tint(.maqrLive)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            NavigationLink(value: Route.code(experience.id)) {
                                Label("QR code", systemImage: "qrcode")
                            }
                            .tint(.maqrAccent)
                        }
                    }
                }
            } header: {
                Text(store.activeStatus.filterLabel)
            }
        }
        .animation(.snappy, value: store.activeStatus)
        .navigationTitle("Your events")
        .refreshable { await store.refresh() }
        .savedCopyBanner(store.experiences)
        .sensoryFeedback(.selection, trigger: store.activeStatus)
        .task { await store.load() }
    }
}

private struct EventRow: View {
    let experience: MyExperience

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: experience.design.image, symbol: experience.design.symbol)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(experience.design.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text([experience.when, experience.design.meta].joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            StatusBadge(text: experience.badge, tone: experience.status == .upcoming ? .live : .muted)
        }
        .opacity(experience.status == .past ? 0.7 : 1)
        .padding(.vertical, 2)
    }
}
