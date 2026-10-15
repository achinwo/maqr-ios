//
//  GuestExperienceView.swift
//  Maqr
//
//  The native engine: an experience as its guests see it — the App Clip's
//  whole screen, the app's Launch, and the designer's live preview.
//
//  Five parts, as on the web (docs/architecture/composable-experiences.md,
//  section 4): the loader (``GuestLoader``), the theme resolver
//  (``GuestLook`` → ``GuestPaint``), the layout resolver (``HubLayout``,
//  ``ScrollLayout`` and ``TabsLayout`` below), the block registry (``BlockView``) and the action
//  bus (``GuestServices`` and ``GuestConnection``). Nothing here knows what
//  kind of experience it is drawing.
//

import DesignerFoundation
import ExperienceModel
import GuestExperience
import SwiftUI

struct GuestExperienceView: View {
    let experience: GuestExperience
    /// The live page's connection; nil in the designer's preview, which must
    /// never count or send anything.
    var connection: GuestConnection?
    /// The section to open on: a link's `#slug`, or the designer's step.
    var focus: String = ""
    var table: Int?

    @State private var services: GuestServices

    init(experience: GuestExperience, connection: GuestConnection? = nil, focus: String = "", table: Int? = nil) {
        self.experience = experience
        self.connection = connection
        self.focus = focus
        self.table = table
        _services = State(initialValue: GuestServices(connection: connection, table: table))
    }

    var body: some View {
        Group {
            if experience.isHub {
                HubLayout(experience: experience, services: services, focus: focus)
            } else if experience.isTabs {
                TabsLayout(experience: experience, services: services, focus: focus)
            } else {
                ScrollLayout(experience: experience, services: services, focus: focus)
            }
        }
        .guestLook(experience.look)
        .task(id: experience.uuid) {
            connection?.record("scan")
            await services.stream.watch()
        }
    }
}

// MARK: - Hub

/// A home screen of tiles, each pushing its section — what ewed.tsx's
/// `HomeView` does, for any document laid out as a hub.
private struct HubLayout: View {
    let experience: GuestExperience
    let services: GuestServices
    let focus: String

    @State private var path: [String] = []
    /// The page last reported, so a link's page shown on appear is not
    /// counted again by the path change it causes.
    @State private var reported: String?
    @Namespace private var zoom
    @Environment(\.guestPaint) private var paint

    var body: some View {
        NavigationStack(path: $path) {
            HubHome(experience: experience, services: services, zoom: zoom) { path.append($0.id) }
                .navigationDestination(for: String.self) { id in
                    if let block = experience.composition.block(id: id) {
                        page(block).modifier(ZoomedIn(id: id, namespace: zoom))
                    }
                }
        }
        .sensoryFeedback(.selection, trigger: path.count)
        .onAppear {
            show(focus, animated: false)
            report(path.last ?? "")
        }
        .onChange(of: path) { _, path in report(path.last ?? "") }
        .onChange(of: focus) { _, focus in show(focus, animated: true) }
    }

    private func report(_ id: String) {
        guard let connection = services.connection, id != reported else { return }
        reported = id
        let slug = experience.composition.block(id: id)?.anchor ?? ""
        connection.record("page", page: GuestLink.analyticsSlug(slug))
    }

    private func show(_ fragment: String, animated: Bool) {
        let target = experience.block(fragment: fragment).map { [$0.id] } ?? []
        guard target != path else { return }
        if animated { withAnimation { path = target } } else { path = target }
    }

    private func page(_ block: ComposedBlock) -> some View {
        ScrollView {
            BlockView(block: block, experience: experience, services: services)
                .padding(.horizontal, block.kind == "story" ? 12 : 16)
                .padding(.top, 16).padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(GuestBackdrop(look: experience.look))
        .navigationTitle(experience.title(of: block))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// The page grows out of its tile, where the system can draw that.
private struct ZoomedIn: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

private struct ZoomSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct HubHome: View {
    let experience: GuestExperience
    let services: GuestServices
    let zoom: Namespace.ID
    let open: (ComposedBlock) -> Void
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                banner
                VStack(spacing: 0) {
                    Text(experience.title)
                        .foregroundStyle(paint.primary)
                        .multilineTextAlignment(.center)
                        .guestFormat(experience.titleFormat, size: 42, face: .display, relativeTo: .largeTitle)
                        .shadow(color: .black.opacity(paint.isDark ? 0.4 : 0), radius: 14, y: 2)
                        .reveal(delay: 0.3)
                    Ornament().reveal(delay: 0.38)
                    if !experience.welcome.isEmpty {
                        Text(experience.welcome)
                            .italic(paint.isDark)
                            .lineSpacing(4)
                            .foregroundStyle(paint.text.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .guestFormat(experience.welcomeFormat, size: 18, face: .body, relativeTo: .body)
                            .frame(maxWidth: 420)
                            .reveal(delay: 0.42)
                    }

                    VStack(spacing: 12) {
                        if let notice = experience.notice { GuestNoticeCard(notice: notice) }
                        if let live = services.stream.stream, !experience.streamID.isEmpty {
                            StreamCard(stream: live, calendar: services.stream.calendarURL)
                        }
                        ForEach(experience.homeBlocks, id: \.id) { block in
                            BlockView(block: block, experience: experience, services: services)
                                .padding(16)
                                .panel()
                        }
                    }
                    .padding(.top, 24)
                    .reveal(delay: 0.46)

                    tiles.padding(.top, 24)

                    ForEach(experience.footerBlocks, id: \.id) { block in
                        Button { open(block) } label: {
                            Text(String(localized: "Made with ♥ · \(experience.title(of: block))"))
                                .displayFont(19, relativeTo: .body)
                                .italic()
                                .foregroundStyle(paint.text.opacity(0.92))
                                .shadow(color: paint.primary.opacity(0.8), radius: 0.5)
                        }
                        .buttonStyle(.plain)
                        .modifier(ZoomSource(id: block.id, namespace: zoom))
                        .padding(.top, 36)
                        .reveal(delay: 0.9)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, experience.logoURL == nil ? 28 : 76)
                .padding(.bottom, 48)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(GuestBackdrop(look: experience.look))
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The photograph, stretching as it is pulled down, with the portrait
    /// hanging half off its rounded foot.
    private var banner: some View {
        GeometryReader { proxy in
            let pull = max(0, proxy.frame(in: .scrollView).minY)
            GuestImage(url: experience.bannerURL, placeholder: "heart")
                .frame(width: proxy.size.width, height: proxy.size.height + pull)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
                .offset(y: -pull)
        }
        .frame(height: 300)
        .overlay(alignment: .bottom) {
            if experience.logoURL != nil {
                Portrait(url: experience.logoURL)
                    .offset(y: 64)
                    .reveal(delay: 0.22, distance: 10)
            }
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(Array(experience.tiles.enumerated()), id: \.element.id) { index, block in
                Button { open(block) } label: {
                    VStack(spacing: 12) {
                        Image(systemName: block.symbol)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(paint.primary)
                            .frame(width: 48, height: 48)
                            .background(paint.primary.opacity(0.14), in: Circle())
                            .overlay(Circle().strokeBorder(paint.primary.opacity(0.4)))
                        Text(experience.title(of: block))
                            .displayFont(18, relativeTo: .headline)
                            .foregroundStyle(paint.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .padding(.horizontal, 10)
                    .panel()
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .modifier(ZoomSource(id: block.id, namespace: zoom))
                .reveal(delay: 0.5 + Double(index) * 0.06)
            }
        }
    }
}

// MARK: - Scroll

/// One long page: the identity, then every section in order, with chips that
/// scroll to each — what ebrand.tsx does, for any document laid out so.
private struct ScrollLayout: View {
    let experience: GuestExperience
    let services: GuestServices
    let focus: String
    @Environment(\.guestPaint) private var paint
    @Environment(\.openURL) private var openURL

    var body: some View {
        let sections = experience.sections
        let named = sections.filter { experience.registry.manifest($0.kind)?.isContent == false || !$0.title.isEmpty }
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    identity

                    if let notice = experience.notice { GuestNoticeCard(notice: notice).padding(.horizontal, 20) }
                    if let live = services.stream.stream, !experience.streamID.isEmpty {
                        StreamCard(stream: live, calendar: services.stream.calendarURL).padding(.horizontal, 20)
                    }
                    ForEach(experience.homeBlocks, id: \.id) { block in
                        BlockView(block: block, experience: experience, services: services)
                            .padding(16).panel().padding(.horizontal, 20)
                    }

                    if named.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(named, id: \.id) { block in
                                    Button {
                                        withAnimation(.smooth) { proxy.scrollTo(block.id, anchor: .top) }
                                        services.connection?.record("page", page: block.anchor)
                                    } label: {
                                        Label(experience.title(of: block), systemImage: block.symbol)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    ForEach(sections, id: \.id) { block in
                        BlockView(block: block, experience: experience, services: services)
                            .padding(18)
                            .panel(cornerRadius: 24)
                            .padding(.horizontal, 16)
                            .id(block.id)
                    }
                }
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .background(GuestBackdrop(look: experience.look))
            .onAppear {
                services.connection?.record("page", page: GuestLink.analyticsSlug(""))
                scroll(to: focus, proxy: proxy)
            }
            .onChange(of: focus) { _, focus in scroll(to: focus, proxy: proxy) }
        }
    }

    private func scroll(to fragment: String, proxy: ScrollViewProxy) {
        guard let block = experience.block(fragment: fragment) else { return }
        withAnimation(.smooth) { proxy.scrollTo(block.id, anchor: .top) }
    }

    /// A banner (or its video), the logo, the name and welcome on a card.
    private var identity: some View {
        VStack(spacing: 20) {
            ZStack {
                GuestImage(url: experience.bannerURL, placeholder: "sparkles")
                if let watch = YouTube.watchURL(experience.bannerVideoID), !experience.bannerVideoID.isEmpty {
                    Button { openURL(watch) } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 58))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.45))
                            .shadow(radius: 10)
                    }
                    .accessibilityLabel(Text("Play the video"))
                }
            }
            .frame(height: 240)
            .clipped()

            if let logo = experience.logoURL {
                GuestImage(url: logo, contentMode: .fit)
                    .frame(maxWidth: 180, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .reveal(delay: 0.1)
            }

            VStack(spacing: 10) {
                Text(experience.title)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(paint.text)
                    .guestFormat(experience.titleFormat, size: 30, face: .display)
                if !experience.welcome.isEmpty {
                    Text(experience.welcome)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(paint.soft)
                        .guestFormat(experience.welcomeFormat, size: 17, face: .body, relativeTo: .body)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .panel(cornerRadius: 24)
            .padding(.horizontal, 20)
            .reveal(delay: 0.18)
        }
    }
}

// MARK: - Tabs

/// A welcome screen and one tab per section, in the system tab bar — the
/// shape of the legacy recipe page (ecook.tsx's `ContentView`), for any
/// document laid out so. Each tab is its own navigation stack, titled by its
/// section, so it scrolls under a large title as a native screen does.
private struct TabsLayout: View {
    let experience: GuestExperience
    let services: GuestServices
    let focus: String

    /// The open tab: a block id, or empty for the welcome screen.
    @State private var selection = ""
    @Environment(\.guestPaint) private var paint

    var body: some View {
        let sections = experience.sections
        TabView(selection: $selection) {
            NavigationStack {
                TabsWelcome(experience: experience, services: services) {
                    if let first = sections.first { selection = first.id }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Welcome", systemImage: "house") }
            .tag("")

            ForEach(sections, id: \.id) { block in
                NavigationStack {
                    TabPage(block: block, experience: experience, services: services)
                }
                .tabItem { Label(experience.title(of: block), systemImage: block.symbol) }
                .tag(block.id)
            }
        }
        .tint(paint.primary)
        .sensoryFeedback(.selection, trigger: selection)
        .onAppear {
            show(focus)
            report(selection)
        }
        .onChange(of: selection) { _, id in report(id) }
        .onChange(of: focus) { _, focus in withAnimation { show(focus) } }
    }

    private func show(_ fragment: String) {
        let id = experience.block(fragment: fragment)?.id ?? ""
        selection = experience.sections.contains { $0.id == id } ? id : ""
    }

    private func report(_ id: String) {
        let slug = experience.composition.block(id: id)?.anchor ?? ""
        services.connection?.record("page", page: GuestLink.analyticsSlug(slug))
    }
}

/// One tab's screen. A recipe pins its progress under the title, as
/// ecook.tsx's frosted header did; every other kind draws as on a hub page.
private struct TabPage: View {
    let block: ComposedBlock
    let experience: GuestExperience
    let services: GuestServices
    @State private var progress = CookingProgress()

    var body: some View {
        let recipe = block.kind == "recipe" ? Recipe(block: block, identity: experience.composition.identity) : nil
        ScrollView {
            Group {
                if let recipe {
                    RecipeSection(recipe: recipe, title: experience.title(of: block), progress: $progress, inTab: true)
                } else {
                    BlockView(block: block, experience: experience, services: services)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let recipe, progress.lastDone != nil {
                CookingProgressBar(progress: progress, steps: recipe.steps.count)
            }
        }
        .background(GuestBackdrop(look: experience.look))
        .navigationTitle(recipe.map { $0.dishName.isEmpty ? experience.title(of: block) : String(localized: "Preparing \($0.dishName)") } ?? experience.title(of: block))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

/// "3 of 8 steps completed" over a green bar, on the bar's material.
private struct CookingProgressBar: View {
    let progress: CookingProgress
    let steps: Int
    @Environment(\.guestPaint) private var paint

    var body: some View {
        let done = min((progress.lastDone ?? 0) + 1, steps)
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if progress.isFinished(of: steps) {
                    Text("All done, enjoy your meal! 🥘")
                } else {
                    Text("\(Text("\(done)").bold()) of \(Text("\(steps)").bold()) steps completed")
                }
            }
            .font(.subheadline)
            .foregroundStyle(paint.soft)
            .contentTransition(.numericText())
            ProgressView(value: progress.fraction(of: steps)).tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.snappy, value: progress)
    }
}

/// ecook.tsx's `HomeView`: the banner, the logo over its foot, the name and
/// welcome on a tinted card, and the button into the first tab.
private struct TabsWelcome: View {
    let experience: GuestExperience
    let services: GuestServices
    let start: () -> Void
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GuestImage(url: experience.bannerURL, placeholder: "fork.knife")
                    .frame(height: 233)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        if experience.logoURL != nil {
                            Portrait(url: experience.logoURL).offset(y: 64).reveal(delay: 0.15, distance: 10)
                        }
                    }

                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text(experience.title)
                            .multilineTextAlignment(.center)
                            .guestFormat(experience.titleFormat, size: 26, face: .display, relativeTo: .title)
                        if !experience.welcome.isEmpty {
                            Text(experience.welcome)
                                .multilineTextAlignment(.center)
                                .guestFormat(experience.welcomeFormat, size: 17, face: .body, relativeTo: .body)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .environment(\.colorScheme, .dark)
                    .reveal(delay: 0.22)

                    if let notice = experience.notice { GuestNoticeCard(notice: notice) }
                    if let live = services.stream.stream, !experience.streamID.isEmpty {
                        StreamCard(stream: live, calendar: services.stream.calendarURL)
                    }

                    if !experience.start.isEmpty, !experience.sections.isEmpty {
                        Button(action: start) {
                            Text(experience.start).font(.headline).padding(.horizontal, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(paint.primary)
                        .reveal(delay: 0.3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, experience.logoURL == nil ? 28 : 92)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(GuestBackdrop(look: experience.look))
    }
}
