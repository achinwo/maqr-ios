//
//  GuestExperienceView.swift
//  Maqr
//
//  An experience as its guests see it — the App Clip's whole screen, the
//  app's Launch, and the designer's live preview. Built from the document
//  in the body, so an edit in the designer, or a font arriving, redraws it.
//

import ExperienceModel
import GuestExperience
import SwiftUI

struct GuestExperienceView: View {
    enum Source {
        /// A document — the designer's own, or a row read into one.
        case document(ExperienceDocument, uuid: String)
        /// A page no designer schema describes.
        case experience(GuestExperience)
    }

    let source: Source
    var connection: GuestConnection?
    /// What to open on: a link's page, or the designer's step.
    var focus: GuestFocus = .home
    var table: Int?

    var body: some View {
        let experience = switch source {
        case .document(let document, let uuid): GuestExperience(document: document, uuid: uuid)
        case .experience(let experience): experience
        }
        Group {
            switch experience.kind {
            case .wedding(let wedding):
                WeddingGuestView(experience: experience, wedding: wedding, connection: connection, page: focus.weddingPage, table: table)
            case .brand(let brand):
                BrandGuestView(experience: experience, brand: brand, showsProducts: focus == .products)
            case .mealbox(let mealbox):
                MealboxGuestView(experience: experience, mealbox: mealbox, focus: focus)
            case .restaurant(let restaurant):
                RestaurantGuestView(experience: experience, restaurant: restaurant)
            }
        }
        .environment(\.guestFamily, experience.look.displayFamily)
    }
}

// MARK: - Brand

/// `BrandPromoView`.
private struct BrandGuestView: View {
    let experience: GuestExperience
    let brand: BrandGuide
    var showsProducts = false
    @State private var isShowingProducts = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    GuestImage(url: experience.bannerURL, placeholder: "sparkles")
                    if let watch = YouTube.watchURL(brand.videoID), !brand.videoID.isEmpty {
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
                        .guestFormat(experience.titleFormat, size: 30, face: .display)
                    if !experience.welcome.isEmpty {
                        Text(experience.welcome)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .guestFormat(experience.welcomeFormat, size: 17, face: .system, relativeTo: .body)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
                .reveal(delay: 0.18)

                if !brand.products.isEmpty {
                    Button { isShowingProducts = true } label: {
                        Label(brand.callToAction, systemImage: "bag.fill").font(.headline).padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .reveal(delay: 0.24)
                }

                if !brand.links.isEmpty {
                    HStack(spacing: 14) {
                        ForEach(brand.links) { link in
                            Link(destination: link.url) {
                                VStack(spacing: 6) {
                                    Image(systemName: symbol(link.kind)).font(.title2)
                                        .frame(width: 54, height: 54)
                                        .background(.tint.opacity(0.14), in: Circle())
                                    Text(link.label).font(.caption2).foregroundStyle(.secondary)
                                    Text(link.detail).font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 20)
                    .reveal(delay: 0.3)
                }
            }
            .padding(.bottom, 48)
        }
        .ignoresSafeArea(edges: .top)
        .background(GuestBackdrop(look: experience.look, isWedding: false))
        .onAppear { if showsProducts { isShowingProducts = true } }
        .onChange(of: showsProducts) { _, shows in isShowingProducts = shows }
        .fullScreenCover(isPresented: $isShowingProducts) {
            ProductCarousel(products: brand.products)
        }
    }

    private func symbol(_ kind: BrandGuide.Link.Kind) -> String {
        switch kind {
        case .instagram: "camera.fill"
        case .twitter: "at"
        case .website: "globe"
        }
    }
}

/// The products, one to a screen — `SwipeableTextMobileStepper`.
private struct ProductCarousel: View {
    let products: [BrandGuide.Product]
    @State private var current = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $current) {
            ForEach(products) { product in
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(product.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                            if !product.tagline.isEmpty {
                                Text(product.tagline).font(.title3).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 60)
                        GuestImage(url: product.imageURL, placeholder: "bag", contentMode: .fit)
                            .frame(maxHeight: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        if !product.detail.isEmpty {
                            Text(product.detail).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                }
                .tag(product.id)
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

// MARK: - Mealbox

/// `MealboxView`: welcome, the recipe, feedback.
struct MealboxGuestView: View {
    enum Tab: Hashable {
        case welcome, recipe, feedback

        init(_ focus: GuestFocus) {
            switch focus {
            case .recipe: self = .recipe
            case .feedback: self = .feedback
            default: self = .welcome
            }
        }
    }

    let experience: GuestExperience
    let mealbox: MealboxGuide
    let focus: GuestFocus
    @State private var tab: Tab
    @State private var progress = CookingProgress()

    init(experience: GuestExperience, mealbox: MealboxGuide, focus: GuestFocus) {
        self.experience = experience
        self.mealbox = mealbox
        self.focus = focus
        _tab = State(initialValue: Tab(focus))
    }

    var body: some View {
        TabView(selection: $tab) {
            welcome
                .tabItem { Label("Welcome", systemImage: "house") }
                .tag(Tab.welcome)
            NavigationStack { recipe }
                .tabItem { Label("Steps", systemImage: "list.number") }
                .tag(Tab.recipe)
            NavigationStack { MealboxFeedback(mealbox: mealbox) }
                .tabItem { Label("Feedback", systemImage: "text.bubble") }
                .tag(Tab.feedback)
        }
        .tint(.orange)
        .sensoryFeedback(.selection, trigger: tab)
        .onChange(of: focus) { _, focus in withAnimation { tab = Tab(focus) } }
    }

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 0) {
                GuestImage(url: experience.bannerURL, placeholder: "fork.knife")
                    .frame(height: 260).clipped()
                    .overlay(alignment: .bottom) {
                        GuestImage(url: experience.logoURL, placeholder: "fork.knife.circle")
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                            .shadow(radius: 12)
                            .offset(y: 60)
                    }
                VStack(spacing: 10) {
                    Text(experience.title).multilineTextAlignment(.center)
                        .guestFormat(experience.titleFormat, size: 30, face: .display)
                    if !experience.welcome.isEmpty {
                        Text(experience.welcome).multilineTextAlignment(.center).foregroundStyle(.secondary)
                            .guestFormat(experience.welcomeFormat, size: 17, face: .system, relativeTo: .body)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 84)
                .reveal(delay: 0.1)

                Button { withAnimation { tab = .recipe } } label: {
                    Label("Get to cooking!", systemImage: "frying.pan.fill").font(.headline).padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.top, 28)
                .reveal(delay: 0.2)
            }
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
        .background(GuestBackdrop(look: experience.look, isWedding: false))
    }

    private var recipe: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    if mealbox.dishImageURL != nil {
                        GuestImage(url: mealbox.dishImageURL, contentMode: .fit)
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if !mealbox.dishDescription.isEmpty {
                        Text(mealbox.dishDescription).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !mealbox.ingredients.isEmpty {
                Section("Ingredients") {
                    ForEach(mealbox.ingredients) { ingredient in
                        HStack(spacing: 12) {
                            GuestImage(url: ingredient.imageURL, placeholder: "carrot", contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading) {
                                Text(ingredient.name)
                                if !ingredient.amount.isEmpty {
                                    Text(ingredient.amount).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(Array(mealbox.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step, index: index)
                }
            } header: {
                Text("Method")
            }

            if progress.isFinished(of: mealbox.steps.count) {
                Section {
                    VStack(spacing: 8) {
                        Text("All done — enjoy your meal! 🥘").font(.headline)
                        if !mealbox.instagram.isEmpty, let url = URL(string: "https://www.instagram.com/\(mealbox.instagram)") {
                            Link(destination: url) { Label("Share it @\(mealbox.instagram)", systemImage: "camera.fill") }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationTitle(mealbox.dishName.isEmpty ? String(localized: "Recipe") : mealbox.dishName)
        .safeAreaInset(edge: .top, spacing: 0) {
            if progress.lastDone != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(min((progress.lastDone ?? 0) + 1, mealbox.steps.count)) of \(mealbox.steps.count) steps done")
                        .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    ProgressView(value: progress.fraction(of: mealbox.steps.count)).tint(.green)
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(.bar)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: progress)
        .sensoryFeedback(.impact(weight: .light), trigger: progress)
        .sensoryFeedback(.success, trigger: progress.isFinished(of: mealbox.steps.count))
    }

    private func stepRow(_ step: MealboxGuide.Step, index: Int) -> some View {
        let isDone = progress.isDone(index)
        let isNext = (progress.lastDone.map { $0 + 1 } ?? 0) == index
        return Button { progress.tap(index) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 24)
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title).strikethrough(isDone).foregroundStyle(isDone ? .secondary : .primary)
                    if isNext, !step.detail.isEmpty {
                        Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
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
                    .foregroundStyle(isDone ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badges(_ step: MealboxGuide.Step) -> [(String, String, Color)] {
        var badges: [(String, String, Color)] = []
        if step.isOptional { badges.append((String(localized: "Optional"), "info.circle", .blue)) }
        if step.heat > 0 { badges.append((String(repeating: "🌶", count: step.heat), "flame", .red)) }
        if let duration = step.duration { badges.append((duration, "timer", .secondary)) }
        if !step.caution.isEmpty { badges.append((step.caution, "exclamationmark.triangle.fill", .orange)) }
        return badges
    }
}

/// `FeedbackView` — a message to the cook, by email.
private struct MealboxFeedback: View {
    let mealbox: MealboxGuide
    @State private var message = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                TextField("What did you think?", text: $message, axis: .vertical).lineLimit(6...12)
            } header: {
                Text("We'd love to hear from you!")
            }
            Section {
                Button {
                    var components = URLComponents()
                    components.scheme = "mailto"
                    components.path = mealbox.feedbackEmail.isEmpty ? "smartstikr@gmail.com" : mealbox.feedbackEmail
                    components.queryItems = [URLQueryItem(name: "subject", value: "Feedback"), URLQueryItem(name: "body", value: message)]
                    if let url = components.url { openURL(url) }
                } label: {
                    Label("Send message", systemImage: "paperplane.fill")
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Feedback")
    }
}

// MARK: - Restaurant

/// `RestaurantView` in emeal.tsx.
private struct RestaurantGuestView: View {
    let experience: GuestExperience
    let restaurant: RestaurantGuide
    @State private var section = ""
    @State private var showsAbout = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GuestImage(url: experience.bannerURL, placeholder: "fork.knife")
                        .frame(height: 200).clipped()
                        .listRowInsets(EdgeInsets())
                }
                if restaurant.sections.count > 1 {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(restaurant.sections, id: \.self) { name in
                                    Button(name) { withAnimation(.snappy) { section = name } }
                                        .buttonStyle(.bordered)
                                        .tint(current == name ? .accentColor : .secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                ForEach(restaurant.headings(in: current)) { heading in
                    Section(heading.name) {
                        ForEach(heading.dishes) { dish in
                            HStack(spacing: 12) {
                                GuestImage(url: dish.imageURL, placeholder: "fork.knife")
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dish.title)
                                    if !dish.subtitle.isEmpty { Text(dish.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(experience.title)
            .toolbar {
                if !experience.welcome.isEmpty {
                    Button("About us", systemImage: "info.circle") { showsAbout = true }
                }
            }
            .sheet(isPresented: $showsAbout) {
                NavigationStack {
                    ScrollView { Text(experience.welcome).padding() }
                        .navigationTitle("About us")
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var current: String { restaurant.sections.contains(section) ? section : (restaurant.sections.first ?? "") }
}
