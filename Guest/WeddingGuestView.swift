//
//  WeddingGuestView.swift
//  Maqr
//
//  A wedding as its guests see it — ewed.tsx drawn natively: the home
//  screen's banner, portrait and tiles, and the page behind each tile.
//

import GuestExperience
import PhotosUI
import SwiftUI

struct WeddingGuestView: View {
    let experience: GuestExperience
    let wedding: WeddingGuide
    let connection: GuestConnection?
    /// The page to show — a link's fragment, or the designer's step.
    var page: WeddingPage = .home

    @State private var path: [WeddingPage] = []
    @State private var stream: StreamStore
    @State private var book: GuestBookStore
    @State private var album: AlbumStore
    @State private var gift: GiftStore
    @State private var meal: MealChoiceStore
    @Namespace private var zoom
    @Environment(\.guestPaint) private var paint

    init(experience: GuestExperience, wedding: WeddingGuide, connection: GuestConnection?, page: WeddingPage, table: Int?) {
        self.experience = experience
        self.wedding = wedding
        self.connection = connection
        self.page = page
        _stream = State(initialValue: StreamStore(connection: connection))
        _book = State(initialValue: GuestBookStore(connection: connection))
        _album = State(initialValue: AlbumStore(connection: connection))
        _gift = State(initialValue: GiftStore(connection: connection))
        _meal = State(initialValue: MealChoiceStore(connection: connection, table: table))
    }

    var body: some View {
        NavigationStack(path: $path) {
            WeddingHome(experience: experience, wedding: wedding, stream: stream, zoom: zoom) { path.append($0) }
                .navigationDestination(for: WeddingPage.self) { page in
                    destination(page)
                        .modifier(ZoomedIn(id: page, namespace: zoom))
                }
        }
        .tint(paint.gold)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: path.count)
        .onAppear { show(page, animated: false) }
        .onChange(of: page) { _, page in show(page, animated: true) }
        .task { await stream.watch() }
    }

    private func show(_ page: WeddingPage, animated: Bool) {
        let target: [WeddingPage] = page == .home ? [] : [page]
        guard target != path else { return }
        if animated { withAnimation { path = target } } else { path = target }
    }

    @ViewBuilder private func destination(_ page: WeddingPage) -> some View {
        Group {
            switch page {
            case .home: EmptyView()
            case .story: StoryPage(chapters: wedding.story)
            case .programme: ProgrammePage(programme: wedding.programme)
            case .menu: MenuPage(menu: wedding.menu, store: meal)
            case .seating: SeatingPage(seating: wedding.seating)
            case .gift: GiftGuestPage(experience: experience, page: wedding.gift, store: gift, connection: connection)
            case .credits: CreditsPage(vendors: wedding.credits)
            case .photos: AlbumPage(experience: experience, store: album)
            case .guestBook: GuestBookPage(wording: wedding.guestBook, store: book)
            }
        }
        .background(GuestBackdrop(look: experience.look))
        .navigationTitle(wedding.label(for: page))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// The page grows out of its tile, where the system can draw that.
private struct ZoomedIn: ViewModifier {
    let id: WeddingPage
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
    let id: WeddingPage
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Home

private struct WeddingHome: View {
    let experience: GuestExperience
    let wedding: WeddingGuide
    let stream: StreamStore
    let zoom: Namespace.ID
    let open: (WeddingPage) -> Void
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                banner
                VStack(spacing: 0) {
                    Text(experience.title)
                        .foregroundStyle(paint.gold)
                        .multilineTextAlignment(.center)
                        .guestFormat(experience.titleFormat, size: 42, face: .display, relativeTo: .largeTitle)
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 2)
                        .reveal(delay: 0.3)
                    Ornament().reveal(delay: 0.38)
                    if !experience.welcome.isEmpty {
                        Text(experience.welcome)
                            .italic()
                            .lineSpacing(4)
                            .foregroundStyle(paint.text.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .guestFormat(experience.welcomeFormat, size: 18, face: .body, relativeTo: .body)
                            .frame(maxWidth: 420)
                            .reveal(delay: 0.42)
                    }

                    VStack(spacing: 12) {
                        if let notice = wedding.notice { GuestNoticeCard(notice: notice) }
                        if let live = stream.stream, !wedding.streamID.isEmpty { StreamCard(stream: live, calendar: stream.calendarURL) }
                    }
                    .padding(.top, 24)
                    .reveal(delay: 0.46)

                    tiles.padding(.top, 24)

                    Button { open(.credits) } label: {
                        Text(L10n.madeWith(wedding.label(for: .credits)))
                            .displayFont(19, relativeTo: .body)
                            .italic()
                            .foregroundStyle(paint.text.opacity(0.92))
                            .shadow(color: paint.gold.opacity(0.8), radius: 0.5)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 36)
                    .reveal(delay: 0.9)
                }
                .padding(.horizontal, 20)
                .padding(.top, 76)
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
            Portrait(url: experience.logoURL)
                .offset(y: 64)
                .reveal(delay: 0.22, distance: 10)
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(Array(wedding.tiles.enumerated()), id: \.element.id) { index, tile in
                Button { open(tile.page) } label: {
                    VStack(spacing: 12) {
                        Image(systemName: tile.page.symbol)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(paint.gold)
                            .frame(width: 48, height: 48)
                            .background(paint.gold.opacity(0.14), in: Circle())
                            .overlay(Circle().strokeBorder(paint.gold.opacity(0.4)))
                        Text(tile.label)
                            .displayFont(18, relativeTo: .headline)
                            .foregroundStyle(paint.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .padding(.horizontal, 10)
                    .glassCard()
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .modifier(ZoomSource(id: tile.page, namespace: zoom))
                .reveal(delay: 0.5 + Double(index) * 0.06)
            }
        }
    }
}

private enum L10n {
    static func madeWith(_ credits: String) -> String {
        String(localized: "Made with ♥ · \(credits)")
    }
}

/// A word from the host — `AnnouncementBanner`.
private struct GuestNoticeCard: View {
    let notice: GuestNotice
    @Environment(\.guestPaint) private var paint

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notice.symbol)
                .font(.title3)
                .foregroundStyle(notice.isWarning ? .orange : paint.gold)
                .symbolEffect(.bounce, value: notice.message)
            VStack(alignment: .leading, spacing: 4) {
                if !notice.title.isEmpty {
                    Text(notice.title).font(.headline).foregroundStyle(paint.text)
                }
                Text(notice.message).font(GuestType.body(16)).foregroundStyle(paint.soft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard()
        .overlay(alignment: .leading) {
            Capsule().fill(notice.isWarning ? Color.orange : paint.gold).frame(width: 3).padding(.vertical, 14)
        }
    }
}

/// The ceremony's stream — counting down, then live.
private struct StreamCard: View {
    let stream: StreamDetails
    let calendar: URL?
    @Environment(\.guestPaint) private var paint
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = stream.watchURL { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                GuestImage(url: stream.thumbnailURL, placeholder: "play.rectangle")
                    .frame(width: 88, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if stream.isLive {
                            Text("LIVE").font(.caption2.weight(.heavy)).padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.red, in: Capsule()).foregroundStyle(.white).padding(4)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(stream.title.isEmpty ? String(localized: "Live stream") : stream.title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(paint.text).lineLimit(2)
                    Group {
                        if stream.isLive {
                            Text("^[\(stream.viewers) watching](inflect: true)")
                        } else if let start = stream.startsAt, stream.isUpcoming {
                            Text("Starts \(start, style: .relative)")
                        } else {
                            Text("Watch on YouTube")
                        }
                    }
                    .font(.caption).foregroundStyle(paint.faint)
                }
                Spacer(minLength: 0)
                if stream.isUpcoming, let calendar {
                    Link(destination: calendar) {
                        Image(systemName: "calendar.badge.plus").font(.title3).foregroundStyle(paint.gold)
                    }
                    .accessibilityLabel(Text("Add to calendar"))
                }
            }
            .padding(12)
            .glassCard()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Our Story

private struct StoryPage: View {
    let chapters: [StoryChapter]
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if chapters.isEmpty {
                    EmptyPage(symbol: "book.pages", message: String(localized: "The story will appear here."))
                }
                ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                    if index > 0 { Ornament().padding(.top, 4).padding(.bottom, 16) }
                    chapterView(chapter, isCover: index == 0)
                        .reveal(distance: 20)
                }
            }
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: chapters.first?.imageURL == nil ? [] : .top)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }

    @ViewBuilder private func chapterView(_ chapter: StoryChapter, isCover: Bool) -> some View {
        VStack(spacing: 0) {
            if let url = chapter.imageURL {
                GuestImage(url: url)
                    .frame(height: isCover ? 440 : 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        if !chapter.title.isEmpty {
                            VStack(spacing: 10) {
                                Rectangle().fill(paint.gold).frame(width: 44, height: 1)
                                Text(chapter.title)
                                    .displayFont(isCover ? 34 : 26)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.6), radius: 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24).padding(.top, 60).padding(.bottom, 22)
                            .background(LinearGradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: isCover ? 0 : 18, style: .continuous))
                    .padding(.horizontal, isCover ? 0 : 16)
                    .shadow(color: .black.opacity(isCover ? 0 : 0.6), radius: 20, y: 14)
            } else if !chapter.title.isEmpty {
                Text(chapter.title)
                    .displayFont(28)
                    .foregroundStyle(paint.gold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
            if !chapter.body.isEmpty {
                Text(chapter.body)
                    .font(GuestType.body(18))
                    .lineSpacing(7)
                    .foregroundStyle(paint.text.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
            }
        }
    }
}

// MARK: - Order of the day

private struct ProgrammePage: View {
    let programme: Programme
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PageHeading(title: programme.title)
                VStack(alignment: .leading, spacing: 0) {
                    if programme.moments.isEmpty {
                        EmptyPage(symbol: "list.number", message: String(localized: "The running order will appear here."))
                    }
                    ForEach(Array(programme.moments.enumerated()), id: \.offset) { index, moment in
                        row(moment).reveal(delay: 0.15 + Double(index) * 0.05)
                    }
                }
                .padding(20)
                .background(alignment: .leading) {
                    Rectangle().fill(paint.rule).frame(width: 1).padding(.leading, 27).padding(.vertical, 30)
                }
                .glassCard(cornerRadius: 24)
                .padding(.horizontal, 16)
            }
            .padding(.top, 16).padding(.bottom, 40)
        }
    }

    private func row(_ moment: Programme.Moment) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(paint.gold)
                .frame(width: 8, height: 8)
                .background(Circle().fill(paint.gold.opacity(0.22)).frame(width: 16, height: 16))
                .opacity(moment.isInterlude ? 0 : 1)
                .frame(width: 16)
                .padding(.top, moment.time.isEmpty ? 10 : 5)
            VStack(alignment: moment.isInterlude ? .center : .leading, spacing: 4) {
                if !moment.time.isEmpty {
                    Text(moment.time.uppercased())
                        .font(GuestType.body(12).weight(.semibold))
                        .tracking(2.4)
                        .foregroundStyle(paint.gold)
                }
                Text(moment.title)
                    .displayFont(moment.isInterlude ? 19 : 23, relativeTo: .title3)
                    .italic(moment.isInterlude)
                    .foregroundStyle(paint.text)
                if !moment.note.isEmpty {
                    Text(moment.note).font(GuestType.body(16)).foregroundStyle(paint.soft)
                }
            }
            .frame(maxWidth: .infinity, alignment: moment.isInterlude ? .center : .leading)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Menu

private struct MenuPage: View {
    let menu: WeddingMenu
    @Bindable var store: MealChoiceStore
    @Environment(\.guestPaint) private var paint
    @State private var taps = 0

    var body: some View {
        let option = store.option(in: menu)
        ScrollView {
            VStack(spacing: 0) {
                PageHeading(
                    title: menu.isServed ? String(localized: "Food Menu") : String(localized: "Food Selection"),
                    subtitle: menu.isServed ? String(localized: "Choose one of the set menus below") : String(localized: "Served as a buffet"))

                VStack(spacing: 18) {
                    if menu.options.count > 1 {
                        Picker("Menu", selection: Binding(get: { option }, set: { store.option = $0 })) {
                            ForEach(menu.options, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if menu.options.isEmpty {
                        EmptyPage(symbol: "fork.knife", message: String(localized: "The menu will appear here."))
                    }
                    ForEach(menu.courses(in: option)) { course in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                Text(course.name.uppercased())
                                    .font(GuestType.body(12).weight(.semibold)).tracking(2.4)
                                    .foregroundStyle(paint.gold)
                                Rectangle().fill(paint.hairline).frame(height: 1)
                            }
                            .padding(.bottom, 6)
                            ForEach(course.dishes) { dish in dishRow(dish) }
                        }
                    }
                    .animation(.snappy, value: option)

                    if menu.isServed, !menu.options.isEmpty { submission }
                }
                .padding(18)
                .glassCard(cornerRadius: 24)
                .padding(.horizontal, 16)
            }
            .padding(.top, 16).padding(.bottom, 40)
        }
        .overlay(alignment: .topTrailing) {
            if let table = store.table, table > 0 {
                Text("\(table)")
                    .displayFont(110, relativeTo: .largeTitle)
                    .foregroundStyle(paint.gold.opacity(0.18))
                    .padding(.trailing, 12)
                    .allowsHitTesting(false)
                    .contentTransition(.numericText())
            }
        }
        .toolbar {
            if menu.isServed, !store.isTableLocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Table", selection: Binding(get: { store.table ?? 0 }, set: { store.table = $0 == 0 ? nil : $0 })) {
                            Text("Select Table").tag(0)
                            ForEach(1...48, id: \.self) { Text("Table \($0)").tag($0) }
                        }
                    } label: {
                        Label(store.table.map { String(localized: "Table \($0)") } ?? String(localized: "Table"), systemImage: "table.furniture")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
        .task(id: store.table) { await store.load() }
        .alert(store.notice ?? "", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func dishRow(_ dish: WeddingMenu.Dish) -> some View {
        let isChosen = store.isChosen(dish, in: menu)
        return Button {
            guard menu.isServed else { return }
            taps += 1
            withAnimation(.spring(duration: 0.3)) { store.toggle(dish, in: menu) }
        } label: {
            HStack(spacing: 14) {
                GuestImage(url: dish.imageURL, placeholder: "fork.knife", contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(dish.title).font(GuestType.body(17)).foregroundStyle(paint.text)
                    if !dish.subtitle.isEmpty {
                        Text(dish.subtitle).font(GuestType.body(15)).italic().foregroundStyle(paint.faint)
                    }
                }
                Spacer(minLength: 0)
                if menu.isServed {
                    Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isChosen ? (store.isServed ? paint.soft : paint.gold) : paint.faint)
                        .scaleEffect(isChosen ? 1.12 : 1)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isServed)
    }

    @ViewBuilder private var submission: some View {
        VStack(spacing: 12) {
            if store.saved == nil || store.name.isEmpty {
                TextField("Your name (optional)", text: $store.name)
                    .font(GuestType.body(17))
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(store.isServed)
            } else {
                Text("Your name: \(store.name)").font(GuestType.body(16)).foregroundStyle(paint.soft)
            }
            if let blocker = store.blocker(in: menu) {
                Text(blocker).font(GuestType.body(15)).italic().foregroundStyle(paint.faint).multilineTextAlignment(.center)
            } else if store.isSubmitting {
                ProgressView().tint(paint.gold)
            } else {
                Button(store.submitLabel) { Task { await store.submit(menu) } }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(store.isServed)
            }
        }
        .padding(.top, 8)
        .animation(.snappy, value: store.blocker(in: menu))
    }
}

// MARK: - Seating

private struct SeatingPage: View {
    let seating: Seating
    @State private var query = ""
    @State private var open: Int?
    @Environment(\.guestPaint) private var paint

    var body: some View {
        let tables = seating.tables(matching: query)
        ScrollView {
            VStack(spacing: 0) {
                PageHeading(title: String(localized: "Seating"), subtitle: String(localized: "Find your name to find your table"))
                VStack(spacing: 0) {
                    if seating.tables.isEmpty {
                        EmptyPage(symbol: "chair.lounge", message: String(localized: "The seating plan will appear here."))
                    } else if tables.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                    ForEach(tables) { table in
                        tableRow(table, isOpen: open == table.number || (!query.isEmpty && tables.count <= 3))
                        if table != tables.last { Divider().overlay(paint.rule) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .glassCard(cornerRadius: 24)
                .padding(.horizontal, 16)
                .animation(.snappy, value: query)
            }
            .padding(.top, 16).padding(.bottom, 40)
        }
        .searchable(text: $query, prompt: Text("Guest name"))
        .sensoryFeedback(.selection, trigger: open)
    }

    private func tableRow(_ table: Seating.Table, isOpen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { open = open == table.number ? nil : table.number }
            } label: {
                HStack {
                    Text(table.title).displayFont(22, relativeTo: .title3).foregroundStyle(isOpen ? paint.gold : paint.text)
                    Spacer()
                    Text("\(table.names.count)").font(.caption.monospacedDigit()).foregroundStyle(paint.faint)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(paint.gold)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(table.names, id: \.self) { name in
                        let matches = !query.isEmpty && name.localizedCaseInsensitiveContains(query)
                        Text(name)
                            .font(GuestType.body(17))
                            .italic(table.isPlaceholder(name))
                            .foregroundStyle(matches ? paint.gold : (table.isPlaceholder(name) ? paint.faint : paint.soft))
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Gift

private struct GiftGuestPage: View {
    let experience: GuestExperience
    let page: GiftPage
    let store: GiftStore
    let connection: GuestConnection?
    @State private var copied: String?
    @State private var showsCard = false
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if experience.logoURL != nil {
                    Portrait(url: experience.logoURL, size: 112).padding(.bottom, 20).reveal(distance: 10)
                }
                PageHeading(title: store.config?.title.nonEmptyText ?? page.title, subtitle: store.config?.subtitle.nonEmptyText ?? page.subtitle)

                VStack(spacing: 16) {
                    if store.takesCards(page) {
                        Button { showsCard = true } label: {
                            Label("Give by card", systemImage: "creditcard")
                        }
                        .buttonStyle(GoldButtonStyle())
                        .disabled(connection == nil)
                    } else if let notice = store.cardNotice(page) {
                        Text(notice).font(GuestType.body(16)).foregroundStyle(paint.soft).multilineTextAlignment(.center)
                            .padding(16).glassCard()
                    }

                    ForEach(store.banks(page)) { bank in bankCard(bank) }
                    if !store.banks(page).isEmpty {
                        Text(store.bankNote(page)).font(GuestType.body(15)).italic().foregroundStyle(paint.faint)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    ForEach(page.methods, id: \.self) { method in methodRow(method) }
                }
                .padding(.horizontal, 16)
                .reveal(delay: 0.2)
            }
            .padding(.top, 24).padding(.bottom, 40)
        }
        .task { await store.load() }
        .sensoryFeedback(.success, trigger: copied)
        .sheet(isPresented: $showsCard) {
            if let connection {
                SafariView(url: GuestLink(id: connection.uuid, page: .gift).webURL(site: connection.client.site)).ignoresSafeArea()
            }
        }
    }

    private func bankCard(_ bank: GiftBank) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bank.currency).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(paint.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(paint.gold, in: Capsule())
                Text(bank.bankName).font(GuestType.body(17)).foregroundStyle(paint.text)
                Spacer()
            }
            copyRow(String(localized: "Account name"), bank.accountName)
            copyRow(String(localized: "Account number"), bank.accountNumber)
            if !bank.sortCode.isEmpty { copyRow(String(localized: "Sort code"), bank.sortCode) }
            copyRow(String(localized: "Reference"), bank.reference)
        }
        .padding(18)
        .glassCard()
    }

    private func copyRow(_ label: String, _ value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation(.snappy) { copied = value }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased()).font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(paint.faint)
                    Text(value).font(GuestType.body(17).monospacedDigit()).foregroundStyle(paint.text).textSelection(.enabled)
                }
                Spacer()
                Image(systemName: copied == value ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(paint.gold)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Copies it"))
    }

    private func methodRow(_ method: GiftPage.Method) -> some View {
        HStack(spacing: 14) {
            GuestImage(url: method.imageURL, placeholder: "gift", contentMode: .fit)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(method.title).font(GuestType.body(17)).foregroundStyle(paint.text)
                if !method.detail.isEmpty {
                    Text(method.detail).font(GuestType.body(15)).foregroundStyle(paint.soft).textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard()
    }
}

private extension String {
    var nonEmptyText: String? {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

// MARK: - Credits

private struct CreditsPage: View {
    let vendors: [Vendor]
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PageHeading(title: String(localized: "Special Thanks"), subtitle: String(localized: "The people who made the day"))
                VStack(spacing: 0) {
                    if vendors.isEmpty {
                        EmptyPage(symbol: "heart.text.square", message: String(localized: "Thank-yous will appear here."))
                    }
                    ForEach(Array(vendors.enumerated()), id: \.offset) { index, vendor in
                        vendorRow(vendor).reveal(delay: 0.2 + Double(index) * 0.05)
                        if index < vendors.count - 1 { Divider().overlay(paint.rule) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .glassCard(cornerRadius: 24)
                .padding(.horizontal, 16)
            }
            .padding(.top, 16).padding(.bottom, 40)
        }
    }

    private func vendorRow(_ vendor: Vendor) -> some View {
        HStack(alignment: .top, spacing: 14) {
            GuestImage(url: vendor.logoURL, placeholder: "sparkles", contentMode: .fit)
                .padding(6)
                .frame(width: 60, height: 60)
                .background(.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name).font(GuestType.body(18)).foregroundStyle(paint.text)
                if !vendor.detail.isEmpty {
                    Text(vendor.detail).font(GuestType.body(15)).italic().foregroundStyle(paint.faint)
                }
                HStack(spacing: 14) {
                    if let phone = vendor.phoneURL {
                        Link(destination: phone) { Label(vendor.phone, systemImage: "phone.fill") }
                    }
                    if let instagram = vendor.instagramURL {
                        Link(destination: instagram) { Label("@\(vendor.instagram)", systemImage: "camera.fill") }
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(paint.gold)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Shared

struct EmptyPage: View {
    let symbol: String
    let message: String
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(paint.gold.opacity(0.6))
            Text(message).font(GuestType.body(16)).italic().foregroundStyle(paint.faint).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
