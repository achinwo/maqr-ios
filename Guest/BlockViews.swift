//
//  BlockViews.swift
//  Maqr
//
//  The engine's block registry: one view per kind of section, drawn the same
//  whichever layout holds it — pushed as a page from a hub's tile, or stacked
//  on a long page. Interactive kinds have their own view; content kinds with
//  none are drawn from their manifest's `render` spec (``SpecSection``), so a
//  new content kind needs no code here; a kind this build has never heard of
//  is a card pointing at the web, never a crash (App Clip builds lag the
//  server). src/engine/registry.tsx in maqr-server is the web's twin.
//

import DesignerFoundation
import ExperienceModel
import GuestExperience
import SwiftUI

/// The stores a page's interactive sections share, one of each, made once per
/// page. Each runs without a connection in the designer's preview.
@Observable
final class GuestServices {
    let connection: GuestConnection?
    let book: GuestBookStore
    let album: AlbumStore
    let gift: GiftStore
    let meal: MealChoiceStore
    let stream: StreamStore
    let feedback: FeedbackStore

    init(connection: GuestConnection?, table: Int?) {
        self.connection = connection
        book = GuestBookStore(connection: connection)
        album = AlbumStore(connection: connection)
        gift = GiftStore(connection: connection)
        meal = MealChoiceStore(connection: connection, table: table)
        stream = StreamStore(connection: connection)
        feedback = FeedbackStore(connection: connection)
    }
}

/// One block, as its kind draws it.
struct BlockView: View {
    let block: ComposedBlock
    let experience: GuestExperience
    let services: GuestServices

    var body: some View {
        switch block.kind {
        case "story": StorySection(chapters: StoryChapter.chapters(block))
        case "timeline": TimelineSection(timeline: Timeline(block: block, title: experience.title(of: block)))
        case "menu": MenuSection(menu: GuestMenu(block: block), title: experience.title(of: block), store: services.meal)
        case "seating": SeatingSection(seating: Seating(block: block), table: services.meal.table)
        case "gift": GiftSection(experience: experience, page: GiftPage(block: block, coupleName: experience.title), services: services, slug: block.anchor)
        case "contacts": ContactsSection(heading: block.props["heading"].text, title: experience.title(of: block), people: Contact.people(block))
        case "photos": AlbumSection(experience: experience, settings: AlbumSettings(block: block), title: experience.title(of: block), store: services.album)
        case "guestbook": GuestBookSection(wording: GuestBookWording(block: block), store: services.book)
        case "cards": CardsSection(deck: CardDeck(block: block), title: experience.title(of: block))
        case "recipe": RecipeHost(recipe: Recipe(block: block, identity: experience.composition.identity), title: experience.title(of: block))
        case "feedback": FeedbackSection(block: block, wording: FeedbackWording(block: block), store: services.feedback)
        case "notice":
            if let notice = GuestNotice(block: block) { GuestNoticeCard(notice: notice) }
        case "livestream":
            if let live = services.stream.stream, !LiveStream(block: block).videoID.isEmpty {
                StreamCard(stream: live, calendar: services.stream.calendarURL)
            }
        case "monitor":
            WebSection(title: experience.title(of: block), message: String(localized: "For the service team. The monitor opens on the web."),
                       experience: experience, slug: block.anchor, site: services.connection?.client.site)
        default:
            if let manifest = experience.registry.manifest(block.kind), !manifest.render.isEmpty {
                SpecSection(nodes: BlockRender.guest(block, identity: experience.composition.identity, manifest: manifest))
            } else {
                WebSection(title: experience.title(of: block), message: String(localized: "This section needs a newer version of maQR."),
                           experience: experience, slug: block.anchor, site: services.connection?.client.site)
            }
        }
    }
}

// MARK: - Notice and stream

/// A word from the host — `AnnouncementBanner`.
struct GuestNoticeCard: View {
    let notice: GuestNotice
    @Environment(\.guestPaint) private var paint

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notice.symbol)
                .font(.title3)
                .foregroundStyle(notice.isWarning ? .orange : paint.primary)
                .symbolEffect(.bounce, value: notice.message)
            VStack(alignment: .leading, spacing: 4) {
                if !notice.title.isEmpty {
                    Text(notice.title).font(.headline).foregroundStyle(paint.text)
                }
                Text(notice.message).font(paint.body(16)).foregroundStyle(paint.soft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .panel()
        .overlay(alignment: .leading) {
            Capsule().fill(notice.isWarning ? Color.orange : paint.primary).frame(width: 3).padding(.vertical, 14)
        }
    }
}

/// The stream — counting down, then live.
struct StreamCard: View {
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
                        Image(systemName: "calendar.badge.plus").font(.title3).foregroundStyle(paint.primary)
                    }
                    .accessibilityLabel(Text("Add to calendar"))
                }
            }
            .padding(12)
            .panel()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Story

struct StorySection: View {
    let chapters: [StoryChapter]
    @Environment(\.guestPaint) private var paint

    var body: some View {
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
    }

    @ViewBuilder private func chapterView(_ chapter: StoryChapter, isCover: Bool) -> some View {
        VStack(spacing: 0) {
            if let url = chapter.imageURL {
                GuestImage(url: url)
                    .frame(height: isCover ? 380 : 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        if !chapter.title.isEmpty {
                            VStack(spacing: 10) {
                                Rectangle().fill(paint.primary).frame(width: 44, height: 1)
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
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(paint.isDark ? 0.6 : 0.15), radius: 20, y: 14)
            } else if !chapter.title.isEmpty {
                Text(chapter.title)
                    .displayFont(28)
                    .foregroundStyle(paint.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
            }
            if !chapter.body.isEmpty {
                Text(chapter.body)
                    .font(paint.body(18))
                    .lineSpacing(7)
                    .foregroundStyle(paint.text.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 24)
            }
        }
    }
}

// MARK: - Timeline

struct TimelineSection: View {
    let timeline: Timeline
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 0) {
            PageHeading(title: timeline.heading)
            VStack(alignment: .leading, spacing: 0) {
                if timeline.moments.isEmpty {
                    EmptyPage(symbol: "list.number", message: String(localized: "The running order will appear here."))
                }
                ForEach(Array(timeline.moments.enumerated()), id: \.offset) { index, moment in
                    row(moment).reveal(delay: 0.15 + Double(index) * 0.05)
                }
            }
            .padding(20)
            .background(alignment: .leading) {
                Rectangle().fill(paint.rule).frame(width: 1).padding(.leading, 27).padding(.vertical, 30)
            }
            .panel(cornerRadius: 24)
        }
    }

    private func row(_ moment: Timeline.Moment) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(paint.primary)
                .frame(width: 8, height: 8)
                .background(Circle().fill(paint.primary.opacity(0.22)).frame(width: 16, height: 16))
                .opacity(moment.isInterlude ? 0 : 1)
                .frame(width: 16)
                .padding(.top, moment.time.isEmpty ? 10 : 5)
            VStack(alignment: moment.isInterlude ? .center : .leading, spacing: 4) {
                if !moment.time.isEmpty {
                    Text(moment.time.uppercased())
                        .font(paint.body(12).weight(.semibold))
                        .tracking(2.4)
                        .foregroundStyle(paint.primary)
                }
                Text(moment.title)
                    .displayFont(moment.isInterlude ? 19 : 23, relativeTo: .title3)
                    .italic(moment.isInterlude)
                    .foregroundStyle(paint.text)
                if !moment.note.isEmpty {
                    Text(moment.note).font(paint.body(16)).foregroundStyle(paint.soft)
                }
            }
            .frame(maxWidth: .infinity, alignment: moment.isInterlude ? .center : .leading)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Menu

/// Courses as tabs, headings within them — and, served `set`, a choice a
/// guest submits with their table (`FoodMenuView`).
struct MenuSection: View {
    let menu: GuestMenu
    let title: String
    @Bindable var store: MealChoiceStore
    @Environment(\.guestPaint) private var paint
    @State private var taps = 0

    var body: some View {
        let option = store.option(in: menu)
        VStack(spacing: 0) {
            PageHeading(title: menu.service == .buffet ? String(localized: "Food Selection") : title, subtitle: subtitle)

            VStack(spacing: 18) {
                if menu.options.count > 1 {
                    Picker("Menu", selection: SwiftUI.Binding(get: { option }, set: { store.option = $0 })) {
                        ForEach(menu.options, id: \.self) { Text($0.isEmpty ? String(localized: "Menu") : $0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if menu.options.isEmpty {
                    EmptyPage(symbol: "fork.knife", message: String(localized: "The menu will appear here."))
                }
                ForEach(menu.headings(in: option)) { heading in
                    VStack(alignment: .leading, spacing: 0) {
                        if !heading.name.isEmpty {
                            HStack(spacing: 12) {
                                Text(heading.name.uppercased())
                                    .font(paint.body(12).weight(.semibold)).tracking(2.4)
                                    .foregroundStyle(paint.primary)
                                Rectangle().fill(paint.hairline).frame(height: 1)
                            }
                            .padding(.bottom, 6)
                        }
                        ForEach(heading.dishes) { dish in dishRow(dish) }
                    }
                }
                .animation(.snappy, value: option)

                if menu.isServed, !menu.options.isEmpty { submission }
            }
            .padding(18)
            .panel(cornerRadius: 24)
        }
        .sensoryFeedback(.selection, trigger: taps)
        .task(id: store.table) { if menu.isServed { await store.load() } }
        .alert(store.notice ?? "", isPresented: SwiftUI.Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var subtitle: String? {
        switch menu.service {
        case .set: String(localized: "Choose one of the set menus below")
        case .buffet: String(localized: "Served as a buffet")
        case .listing: nil
        }
    }

    private func dishRow(_ dish: GuestMenu.Dish) -> some View {
        let isChosen = store.isChosen(dish, in: menu)
        return Button {
            guard menu.isServed else { return }
            taps += 1
            withAnimation(.spring(duration: 0.3)) { store.toggle(dish, in: menu) }
        } label: {
            HStack(spacing: 14) {
                if dish.imageURL != nil || menu.isServed {
                    GuestImage(url: dish.imageURL, placeholder: "fork.knife", contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .background(paint.text.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(dish.heat > 0 ? "\(dish.title) \(String(repeating: "🌶", count: dish.heat))" : dish.title)
                        .font(paint.body(17)).foregroundStyle(paint.text)
                    if !dish.subtitle.isEmpty {
                        Text(dish.subtitle).font(paint.body(15)).italic(paint.isDark).foregroundStyle(paint.faint)
                    }
                    if !dish.caution.isEmpty {
                        Label(dish.caution, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                if menu.isServed {
                    Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isChosen ? (store.isServed ? paint.soft : paint.primary) : paint.faint)
                        .scaleEffect(isChosen ? 1.12 : 1)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isServed || !menu.isServed)
    }

    @ViewBuilder private var submission: some View {
        VStack(spacing: 12) {
            if !store.isTableLocked {
                Picker("Table", selection: SwiftUI.Binding(get: { store.table ?? 0 }, set: { store.table = $0 == 0 ? nil : $0 })) {
                    Text("Select Table").tag(0)
                    ForEach(MealSelection.tableNumbers, id: \.self) { Text("Table \($0)").tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(paint.text.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if let table = store.table {
                Text("Table \(table)").font(paint.body(16)).foregroundStyle(paint.soft)
            }
            if store.saved == nil || store.name.isEmpty {
                TextField("Your name (optional)", text: $store.name)
                    .font(paint.body(17))
                    .padding(14)
                    .background(paint.text.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(store.isServed)
            } else {
                Text("Your name: \(store.name)").font(paint.body(16)).foregroundStyle(paint.soft)
            }
            if let blocker = store.blocker(in: menu) {
                Text(blocker).font(paint.body(15)).italic().foregroundStyle(paint.faint).multilineTextAlignment(.center)
            } else if store.isSubmitting {
                ProgressView().tint(paint.primary)
            } else {
                Button(store.submitLabel) { Task { await store.submit(menu) } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isServed)
            }
        }
        .padding(.top, 8)
        .animation(.snappy, value: store.blocker(in: menu))
    }
}

// MARK: - Seating

struct SeatingSection: View {
    let seating: Seating
    /// The table a code on a table names, opened first.
    var table: Int?
    @State private var query = ""
    @State private var open: Int?
    @Environment(\.guestPaint) private var paint

    var body: some View {
        let tables = seating.tables(matching: query)
        VStack(spacing: 0) {
            PageHeading(title: String(localized: "Seating"), subtitle: String(localized: "Find your name to find your table"))
            VStack(spacing: 0) {
                if !seating.tables.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(paint.faint)
                        TextField("Guest name", text: $query).textInputAutocapitalization(.words)
                    }
                    .padding(12)
                    .background(paint.text.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.vertical, 10)
                }
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
            .panel(cornerRadius: 24)
            .animation(.snappy, value: query)
        }
        .sensoryFeedback(.selection, trigger: open)
        .onAppear { if open == nil { open = table } }
    }

    private func tableRow(_ table: Seating.Table, isOpen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { open = open == table.number ? nil : table.number }
            } label: {
                HStack {
                    Text(table.title).displayFont(22, relativeTo: .title3).foregroundStyle(isOpen ? paint.primary : paint.text)
                    Spacer()
                    Text("\(table.names.count)").font(.caption.monospacedDigit()).foregroundStyle(paint.faint)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(paint.primary)
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
                            .font(paint.body(17))
                            .italic(table.isPlaceholder(name))
                            .foregroundStyle(matches ? paint.primary : (table.isPlaceholder(name) ? paint.faint : paint.soft))
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Gift

struct GiftSection: View {
    let experience: GuestExperience
    let page: GiftPage
    let services: GuestServices
    let slug: String
    @State private var copied: String?
    @State private var showsCard = false
    @Environment(\.guestPaint) private var paint

    private var store: GiftStore { services.gift }

    var body: some View {
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
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(services.connection == nil)
                } else if let notice = store.cardNotice(page) {
                    Text(notice).font(paint.body(16)).foregroundStyle(paint.soft).multilineTextAlignment(.center)
                        .padding(16).panel()
                }

                ForEach(store.banks(page)) { bank in bankCard(bank) }
                if !store.banks(page).isEmpty {
                    Text(store.bankNote(page)).font(paint.body(15)).italic().foregroundStyle(paint.faint)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
                ForEach(page.methods, id: \.self) { method in methodRow(method) }
            }
            .reveal(delay: 0.2)
        }
        .task { await store.load() }
        .sensoryFeedback(.success, trigger: copied)
        .sheet(isPresented: $showsCard) {
            if let connection = services.connection {
                SafariView(url: GuestLink(id: connection.uuid, slug: slug).webURL(site: connection.client.site)).ignoresSafeArea()
            }
        }
    }

    private func bankCard(_ bank: GiftBank) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bank.currency).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(paint.onPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(paint.primary, in: Capsule())
                Text(bank.bankName).font(paint.body(17)).foregroundStyle(paint.text)
                Spacer()
            }
            copyRow(String(localized: "Account name"), bank.accountName)
            copyRow(String(localized: "Account number"), bank.accountNumber)
            if !bank.sortCode.isEmpty { copyRow(String(localized: "Sort code"), bank.sortCode) }
            copyRow(String(localized: "Reference"), bank.reference)
        }
        .padding(18)
        .panel()
    }

    private func copyRow(_ label: String, _ value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation(.snappy) { copied = value }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased()).font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(paint.faint)
                    Text(value).font(paint.body(17).monospacedDigit()).foregroundStyle(paint.text).textSelection(.enabled)
                }
                Spacer()
                Image(systemName: copied == value ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(paint.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Copies it"))
    }

    @ViewBuilder private func methodRow(_ method: GiftPage.Method) -> some View {
        let link = GuestURL.loadable(method.detail)
        HStack(spacing: 14) {
            GuestImage(url: method.imageURL, placeholder: "gift", contentMode: .fit)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if let link {
                    Link(method.title, destination: link).font(paint.body(17).weight(.semibold))
                } else {
                    Text(method.title).font(paint.body(17)).foregroundStyle(paint.text)
                    if !method.detail.isEmpty {
                        Text(method.detail).font(paint.body(15)).foregroundStyle(paint.soft).textSelection(.enabled)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .panel()
    }
}

private extension String {
    var nonEmptyText: String? {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

// MARK: - Contacts

struct ContactsSection: View {
    let heading: String
    let title: String
    let people: [Contact]
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 0) {
            PageHeading(title: heading.nonEmptyText ?? title)
            VStack(spacing: 0) {
                if people.isEmpty {
                    EmptyPage(symbol: "heart.text.square", message: String(localized: "Thank-yous will appear here."))
                }
                ForEach(Array(people.enumerated()), id: \.offset) { index, person in
                    row(person).reveal(delay: 0.2 + Double(index) * 0.05)
                    if index < people.count - 1 { Divider().overlay(paint.rule) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .panel(cornerRadius: 24)
        }
    }

    private func row(_ person: Contact) -> some View {
        HStack(alignment: .top, spacing: 14) {
            GuestImage(url: person.imageURL, placeholder: "sparkles", contentMode: .fit)
                .padding(6)
                .frame(width: 60, height: 60)
                .background(.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name).font(paint.body(18)).foregroundStyle(paint.text)
                if !person.detail.isEmpty {
                    Text(person.detail).font(paint.body(15)).italic(paint.isDark).foregroundStyle(paint.faint)
                }
                HStack(spacing: 14) {
                    if let phone = person.phoneURL {
                        Link(destination: phone) { Label(person.phone, systemImage: "phone.fill") }
                    }
                    if let instagram = person.instagramURL {
                        Link(destination: instagram) { Label("@\(person.instagram)", systemImage: "camera.fill") }
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(paint.primary)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Cards

/// A brand's products: a button into a full-screen carousel, or a list.
struct CardsSection: View {
    let deck: CardDeck
    let title: String
    @State private var isShowing = false
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 16) {
            if deck.cards.isEmpty {
                EmptyPage(symbol: "bag", message: String(localized: "Products will appear here."))
            } else if deck.isCarousel {
                Button { isShowing = true } label: {
                    Label(deck.buttonLabel, systemImage: "bag.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                PageHeading(title: title)
                ForEach(deck.cards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        if card.imageURL != nil {
                            GuestImage(url: card.imageURL, placeholder: "bag").frame(height: 200).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        Text(card.title).font(.title3.bold()).foregroundStyle(paint.text)
                        if !card.tagline.isEmpty { Text(card.tagline).foregroundStyle(paint.primary) }
                        if !card.detail.isEmpty { Text(card.detail).foregroundStyle(paint.soft) }
                    }
                    .padding(16)
                    .panel()
                }
            }
        }
        .fullScreenCover(isPresented: $isShowing) { ProductCarousel(cards: deck.cards) }
    }
}

/// The products, one to a screen — `SwipeableTextMobileStepper`.
private struct ProductCarousel: View {
    let cards: [CardDeck.Card]
    @State private var current = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $current) {
            ForEach(cards) { card in
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(card.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                            if !card.tagline.isEmpty {
                                Text(card.tagline).font(.title3).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 60)
                        GuestImage(url: card.imageURL, placeholder: "bag", contentMode: .fit)
                            .frame(maxHeight: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        if !card.detail.isEmpty {
                            Text(card.detail).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                }
                .tag(card.id)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .padding(12)
                .background(.thinMaterial, in: Circle())
                .padding()
        }
        .sensoryFeedback(.selection, trigger: current)
    }
}

// MARK: - Recipe

/// The dish, its ingredients, and steps a cook ticks off — ecook.tsx.
/// A recipe that keeps its own progress — on a hub page or a long one.
struct RecipeHost: View {
    let recipe: Recipe
    let title: String
    @State private var progress = CookingProgress()

    var body: some View {
        RecipeSection(recipe: recipe, title: title, progress: $progress)
    }
}

struct RecipeSection: View {
    let recipe: Recipe
    let title: String
    @SwiftUI.Binding var progress: CookingProgress
    /// In a tab, the title and the progress are the screen's — its navigation
    /// title and the bar pinned under it — so the section draws neither.
    var inTab = false
    @Environment(\.guestPaint) private var paint
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !inTab {
                PageHeading(title: recipe.dishName.isEmpty ? title : String(localized: "Preparing \(recipe.dishName)"))
            }
            if recipe.dishImageURL != nil {
                GuestImage(url: recipe.dishImageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if !recipe.dishDescription.isEmpty {
                Text(recipe.dishDescription).foregroundStyle(paint.soft)
            }

            if !recipe.ingredients.isEmpty {
                Text("Ingredients").font(.title3.bold()).foregroundStyle(paint.primary)
                VStack(spacing: 10) {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack(spacing: 12) {
                            GuestImage(url: ingredient.imageURL, placeholder: "carrot", contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(ingredient.name).foregroundStyle(paint.text)
                            Spacer()
                            Text(ingredient.amount).foregroundStyle(paint.soft)
                        }
                    }
                }
                .padding(14)
                .panel()
            }

            if !recipe.steps.isEmpty {
                HStack {
                    Text("Method").font(.title3.bold()).foregroundStyle(paint.primary)
                    Spacer()
                    if progress.lastDone != nil, !inTab {
                        Text("\(min((progress.lastDone ?? 0) + 1, recipe.steps.count)) of \(recipe.steps.count) done")
                            .font(.footnote.weight(.medium)).foregroundStyle(paint.soft)
                            .contentTransition(.numericText())
                    }
                }
                if !inTab {
                    ProgressView(value: progress.fraction(of: recipe.steps.count)).tint(.green)
                }
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step, index: index)
                }
            }

            if progress.isFinished(of: recipe.steps.count) {
                VStack(spacing: 8) {
                    Text("All done — enjoy your meal! 🥘").font(.headline)
                    if !recipe.instagram.isEmpty, let url = URL(string: "https://www.instagram.com/\(recipe.instagram)") {
                        Link(destination: url) { Label("Share it @\(recipe.instagram)", systemImage: "camera.fill") }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .panel()
                .transition(.scale.combined(with: .opacity))
            }

            if !recipe.feedbackEmail.isEmpty {
                Button {
                    var components = URLComponents()
                    components.scheme = "mailto"
                    components.path = recipe.feedbackEmail
                    components.queryItems = [URLQueryItem(name: "subject", value: String(localized: "Feedback: \(recipe.dishName.isEmpty ? title : recipe.dishName)"))]
                    if let url = components.url { openURL(url) }
                } label: {
                    Label("Send feedback", systemImage: "text.bubble")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .animation(.snappy, value: progress)
        .sensoryFeedback(.impact(weight: .light), trigger: progress)
        .sensoryFeedback(.success, trigger: progress.isFinished(of: recipe.steps.count))
    }

    private func stepRow(_ step: Recipe.Step, index: Int) -> some View {
        let isDone = progress.isDone(index)
        let isNext = (progress.lastDone.map { $0 + 1 } ?? 0) == index
        return Button { progress.tap(index) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(paint.soft).frame(width: 24)
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title).strikethrough(isDone).foregroundStyle(isDone ? paint.soft : paint.text)
                    if isNext, !step.detail.isEmpty {
                        Text(step.detail).font(.subheadline).foregroundStyle(paint.soft)
                    }
                    let badges = badges(step)
                    if !badges.isEmpty {
                        HStack(spacing: 10) { ForEach(badges, id: \.0) { Label($0.0, systemImage: $0.1).foregroundStyle($0.2) } }
                            .font(.caption)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? .green : paint.faint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .panel(cornerRadius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badges(_ step: Recipe.Step) -> [(String, String, Color)] {
        var badges: [(String, String, Color)] = []
        if step.isOptional { badges.append((String(localized: "Optional"), "info.circle", .blue)) }
        if step.heat > 0 { badges.append((String(repeating: "🌶", count: step.heat), "flame", .red)) }
        if let duration = step.duration { badges.append((duration, "timer", paint.soft)) }
        if !step.caution.isEmpty { badges.append((step.caution, "exclamationmark.triangle.fill", .orange)) }
        return badges
    }
}

// MARK: - Feedback

/// A private note to the author — ecook.tsx's Feedback tab. Kept with the
/// experience as a response rather than handed to the guest's mail app.
struct FeedbackSection: View {
    let block: ComposedBlock
    let wording: FeedbackWording
    let store: FeedbackStore
    @State private var message = ""
    @State private var sent = false
    @FocusState private var editing: Bool
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(spacing: 20) {
            Text(wording.heading)
                .font(.title2.weight(.semibold))
                .foregroundStyle(paint.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(wording.prompt).font(.subheadline.weight(.medium)).foregroundStyle(paint.soft)
                TextEditor(text: $message)
                    .focused($editing)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(paint.text)
                    .padding(10)
                    .panel(cornerRadius: 14)
            }

            if let failure = store.failure {
                Label(failure, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.orange)
            }

            Button {
                Task {
                    if await store.send(message, block: block.id) {
                        message = ""
                        editing = false
                        sent = true
                    }
                }
            } label: {
                if store.isSending { ProgressView().tint(paint.onPrimary) } else { Text(wording.button) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSending || !store.canSend)

            HStack(spacing: 8) {
                Text("Powered by")
                Image(systemName: "qrcode").foregroundStyle(paint.primary)
                Text(verbatim: "maQR").fontWeight(.semibold).foregroundStyle(paint.text)
            }
            .font(.title3)
            .foregroundStyle(paint.soft)
            .padding(.top, 36)
        }
        .sensoryFeedback(.success, trigger: sent)
        .alert("Thank you!", isPresented: $sent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your message was sent.")
        }
    }
}

// MARK: - Content kinds, from their spec

/// A content kind drawn from its manifest's `render` spec — the same
/// primitives `SpecView` draws on the web.
struct SpecSection: View {
    let nodes: [SpecNode]
    @Environment(\.guestPaint) private var paint
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                view(node)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func view(_ node: SpecNode) -> some View {
        switch node {
        case .heading(let line):
            Text(line).displayFont(26, relativeTo: .title2).foregroundStyle(paint.primary)
        case .tagline(let line):
            Text(line).font(paint.body(17)).italic().foregroundStyle(paint.soft)
        case .paragraph(let line):
            Text(line).font(paint.body(17)).foregroundStyle(paint.text).lineSpacing(4)
        case .footnote(let line):
            Text(line).font(.footnote).foregroundStyle(paint.faint)
        case .empty:
            EmptyView()
        case .banner(let url, let caption):
            VStack(alignment: .leading, spacing: 6) {
                GuestImage(url: GuestURL.loadable(url), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if !caption.isEmpty { Text(caption).font(.footnote).foregroundStyle(paint.soft) }
            }
        case .row(let image, let title, let detail):
            HStack(alignment: .top, spacing: 12) {
                if GuestURL.loadable(image) != nil {
                    GuestImage(url: GuestURL.loadable(image), contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(paint.body(17).weight(.semibold)).foregroundStyle(paint.text)
                    if !detail.isEmpty { Text(detail).font(paint.body(15)).foregroundStyle(paint.soft) }
                }
            }
        case .moment(let time, let title, let note, let muted):
            VStack(alignment: muted ? .center : .leading, spacing: 3) {
                if !time.isEmpty {
                    Text(time.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(paint.primary)
                }
                Text(title).font(paint.body(muted ? 16 : 18)).italic(muted).foregroundStyle(paint.text)
                if !note.isEmpty { Text(note).font(paint.body(15)).foregroundStyle(paint.soft) }
            }
            .frame(maxWidth: .infinity, alignment: muted ? .center : .leading)
        case .button(let label, let url):
            Button(label) { if let target = Self.url(url, as: "url") { openURL(target) } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(Self.url(url, as: "url") == nil)
        case .link(let label, let url, let kind):
            if let target = Self.url(url, as: kind) {
                Link(destination: target) {
                    HStack(spacing: 12) {
                        Image(systemName: Self.symbol(kind)).frame(width: 28)
                        Text(Self.label(label, as: kind)).foregroundStyle(paint.text)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(paint.faint)
                    }
                    .padding(14)
                    .panel(cornerRadius: 14)
                }
            }
        case .quote(let text, let by):
            VStack(alignment: .leading, spacing: 6) {
                Text("“\(text)”").font(paint.body(19)).italic().foregroundStyle(paint.text)
                if !by.isEmpty { Text("— \(by)").font(.footnote).foregroundStyle(paint.soft) }
            }
        case .table(let label, let names):
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.headline).foregroundStyle(paint.primary)
                ForEach(names, id: \.self) { Text($0).foregroundStyle(paint.soft) }
            }
        case .embed(let url):
            let video = YouTube.videoID(url)
            Button {
                if let target = video.isEmpty ? GuestURL.loadable(url) : YouTube.watchURL(video) { openURL(target) }
            } label: {
                ZStack {
                    GuestImage(url: video.isEmpty ? nil : URL(string: "https://img.youtube.com/vi/\(video)/hqdefault.jpg"), placeholder: "play.rectangle")
                    Image(systemName: "play.circle.fill").font(.system(size: 52)).foregroundStyle(.white).shadow(radius: 8)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        case .grid(let images):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                        .overlay { GuestImage(url: GuestURL.loadable(image.url)) }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    /// An address as the link kind means it — `linkHref` in src/engine/spec.tsx.
    static func url(_ text: String, as kind: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let handle = value.hasPrefix("@") ? String(value.dropFirst()) : value
        switch kind {
        case "tel":
            let digits = value.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
        case "email": return URL(string: "mailto:\(value)")
        case "instagram" where !value.contains("/"): return URL(string: "https://www.instagram.com/\(handle)")
        case "twitter" where !value.contains("/"): return URL(string: "https://x.com/\(handle)")
        case "tiktok" where !value.contains("/"): return URL(string: "https://www.tiktok.com/@\(handle)")
        case "facebook" where !value.contains("/"): return URL(string: "https://www.facebook.com/\(handle)")
        default:
            return GuestURL.loadable(value) ?? GuestURL.loadable("https://\(value)")
        }
    }

    static func label(_ text: String, as kind: String) -> String {
        let isHandle = ["instagram", "twitter", "tiktok"].contains(kind) && !text.contains("/") && !text.hasPrefix("@")
        return isHandle ? "@\(text)" : text
    }

    static func symbol(_ kind: String) -> String {
        switch kind {
        case "instagram": return "camera.fill"
        case "twitter": return "at"
        case "facebook": return "person.2.fill"
        case "tiktok": return "music.note"
        case "tel": return "phone.fill"
        case "email": return "envelope.fill"
        default: return "globe"
        }
    }
}

// MARK: - The web's half

/// A section the app hands to the web — the service monitor, and any kind
/// this build is older than.
struct WebSection: View {
    let title: String
    let message: String
    let experience: GuestExperience
    let slug: String
    let site: URL?
    @Environment(\.guestPaint) private var paint
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            Text(title).displayFont(24).foregroundStyle(paint.primary)
            Text(message).font(paint.body(16)).foregroundStyle(paint.soft).multilineTextAlignment(.center)
            if !experience.uuid.isEmpty, let site {
                Button("Open on the web") {
                    openURL(GuestLink(id: experience.uuid, slug: slug).webURL(site: site))
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
