//
//  AppClipScreens.swift
//  Maqr
//
//  Row I: the App Clip card — I1 overview, I2 its words, I3 its banner and
//  I4 Apple's progress with it.
//

import MaqrDashboard
import PhotosUI
import SwiftUI

// MARK: - I1 · Overview

struct AppClipScreen: View {
    @State var store: AppClipStore

    var body: some View {
        RemoteContent(remote: store.card, failureTitle: "The App Clip card couldn't be loaded", retry: { await store.refresh() }) { view in
            List {
                Section {
                    StatusStrip(badge: store.badge.label, tone: store.badge.tone, line: store.checkedLine,
                                source: "ASC · APPCLIPADVANCEDEXPERIENCES.STATUS")
                    if let failure = store.failure {
                        NoticeCard(title: String(localized: "That didn't go through"), message: failure, kind: .alert)
                    }
                    if !view.reading.errors.isEmpty {
                        NoticeCard(title: String(localized: "Apple would not accept this"), message: view.reading.errors.joined(separator: " "), kind: .stop)
                    }
                    AppClipCardPreview(imageURL: view.image.url, title: view.card.title, subtitle: view.card.subtitle,
                                       action: view.card.action.label)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)

                Section {
                    NavigationLink(value: Route.appClipBanner(view.experience.uuid)) {
                        LabeledContent("Banner image", value: store.bannerValue)
                    }
                    NavigationLink(value: Route.appClipCard(view.experience.uuid)) {
                        LabeledContent("Title & subtitle", value: store.titleValue)
                    }
                    NavigationLink(value: Route.appClipCard(view.experience.uuid)) {
                        LabeledContent("When it opens", value: view.card.action.label)
                    }
                    NavigationLink(value: Route.appClipStatus(view.experience.uuid)) {
                        LabeledContent("Status from Apple") { StatusBadge(text: store.badge.label, tone: store.badge.tone) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button { Task { await store.submit() } } label: {
                        Text(store.submitLabel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.canSubmit)
                    Text("Apple reviews every change. The code keeps working meanwhile.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle("App Clip experience")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                    .symbolEffect(.pulse, isActive: store.card.isLoading)
            }
        }
        .refreshable { await store.refresh() }
        .task { await store.load() }
    }
}

/// The card as iOS shows it, so an owner can check what will be cut off.
struct AppClipCardPreview: View {
    let imageURL: String?
    let title: String
    let subtitle: String
    let action: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(.fill.tertiary)
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }
                } else {
                    Text("Your banner goes here").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .aspectRatio(3 / 2, contentMode: .fit)
            .clipped()
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.maqrAccent)
                    .frame(width: 44, height: 44)
                    .overlay(Text(verbatim: "maQR").font(.caption2.weight(.bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.isEmpty ? String(localized: "Your title") : title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(subtitle.isEmpty ? String(localized: "Your subtitle") : subtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    Text("maQR · App Clip").font(.caption2).textCase(.uppercase).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(action)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(Color.maqrAccent, in: Capsule())
            }
            .padding(14)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal)
    }
}

// MARK: - I2 · The card's words

struct AppClipDetailsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State var store: AppClipStore

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Text("The two lines under the banner when someone scans the code. Keep them short — iOS truncates rather than wraps.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            if let failure = store.failure {
                Section { NoticeCard(title: String(localized: "That couldn't be saved"), message: failure, kind: .alert) }
            }
            Section {
                counted("Title", text: $store.title, max: AppClipCard.titleMax, over: store.titleTooLong, prompt: "Esther & Jide")
                counted("Subtitle", text: $store.subtitle, max: AppClipCard.subtitleMax, over: store.subtitleTooLong,
                        prompt: "Seating, the menu and the order of the day")
            }
            Section {
                Picker("When someone taps it", selection: $store.action) {
                    ForEach(CardAction.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("When someone taps it")
            } footer: {
                Text(store.action.hint)
            }
            Section {
                AppClipCardPreview(imageURL: store.view?.image.url, title: store.title, subtitle: store.subtitle, action: store.action.label)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text("These go to App Store Connect as a localisation on the experience. \(store.view?.card.language ?? "en") is the default for this account; other languages fall back to it.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button { Task { if await store.saveDraft(thenSubmit: true) { dismiss() } } } label: {
                    Text(store.isBusy ? "Saving…" : "Save & submit").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.canSaveAndSubmit)
                Button("Save the draft") { Task { if await store.saveDraft(thenSubmit: false) { dismiss() } } }
                    .disabled(!store.canSaveDraft)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Card details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
    }

    private func counted(_ label: LocalizedStringKey, text: Binding<String>, max: Int, over: Bool, prompt: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) / \(max)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(over ? .red : .secondary)
                    .contentTransition(.numericText())
            }
            TextField(label, text: text, prompt: Text(prompt))
        }
        .listRowBackground(over ? Color.red.opacity(0.08) : nil)
    }
}

// MARK: - I3 · Banner

struct AppClipBannerScreen: View {
    @State var store: AppClipStore
    @State private var picked: PhotosPickerItem?

    var body: some View {
        let bannerSize = store.bannerSize
        let rejected = store.bannerRejected
        let progress = store.progress
        RemoteContent(remote: store.card, retry: { await store.refresh() }) { view in
            List {
                Section {
                    PhotosPicker(selection: $picked, matching: .images) {
                        ZStack(alignment: .bottomLeading) {
                            Rectangle().fill(.fill.tertiary)
                            if let url = view.image.url.flatMap(URL.init(string:)) {
                                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }
                            } else {
                                Label("No banner yet", systemImage: "photo.badge.plus")
                                    .font(.footnote).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            Text("BANNER · \(bannerSize)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top))
                        }
                        .aspectRatio(3 / 2, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(rejected ? Color.red : Color.secondary.opacity(0.3),
                                          style: StrokeStyle(lineWidth: 1.5, dash: view.image.url == nil ? [6, 4] : [])))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isBusy)
                    StatusStrip(badge: store.bannerBadge.label, tone: store.bannerBadge.tone, line: store.bannerLine,
                                source: "ASC · IMAGE.ASSETDELIVERYSTATE.STATE")
                    if let failure = store.failure {
                        NoticeCard(title: String(localized: "That image wasn't used"), message: failure, kind: .alert)
                    }
                    if !view.reading.errors.isEmpty {
                        NoticeCard(title: String(localized: "Apple rejected this image"), message: view.reading.errors.joined(separator: " "), kind: .stop)
                    }
                    if view.image.fromApple {
                        NoticeCard(title: String(localized: "This banner came from App Store Connect"),
                                   message: String(localized: "It was set up outside maQR, so what you see is Apple's copy rather than the original. Replacing it here is fine; going back to this one would mean uploading it again."))
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    LabeledContent("Size", value: store.bannerSize)
                    LabeledContent("Format", value: String(localized: "PNG or JPEG, sRGB"))
                } footer: {
                    Text("iOS crops this to fit the card, and how much it takes depends on the device. Keep the important part — and any words — near the middle.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    PhotosPicker(selection: $picked, matching: .images) {
                        Text(progress ?? (view.image.url == nil ? String(localized: "Choose an image") : String(localized: "Replace the image")))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isBusy)
                    Text("A new banner goes back to Apple for review. The code keeps working meanwhile.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)
            }
        }
        .navigationTitle("Banner image")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                defer { picked = nil }
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    return
                }
                let isPNG = item.supportedContentTypes.contains(.png)
                await store.useBanner(data, width: Int(image.size.width * image.scale), height: Int(image.size.height * image.scale), isPNG: isPNG)
            }
        }
        .task { await store.load() }
    }
}

// MARK: - I4 · Status

struct AppClipStatusScreen: View {
    @Environment(AppModel.self) private var model
    @State var store: AppClipStore

    var body: some View {
        RemoteContent(remote: store.card, retry: { await store.refresh() }) { view in
            List {
                Section {
                    StatusStrip(badge: store.badge.label, tone: store.badge.tone,
                                line: String(localized: "Checked \(Formatting.since(view.checkedAt))"),
                                source: "ASC · POLLED, NOT PUSHED — APPLE SENDS NO WEBHOOK")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(Array(store.timeline.enumerated()), id: \.element.id) { index, step in
                        TimelineRow(step: step, isLast: index == store.timeline.count - 1)
                    }
                }
                .listRowSeparator(.hidden)
                Section {
                    switch store.state {
                    case .failed:
                        NoticeCard(title: String(localized: "The card is not showing yet"),
                                   message: String(localized: "Scanning the code still opens the experience in a browser. The App Clip card appears once Apple has an image at 3000 × 2000."), kind: .stop)
                        Button("Replace the image & resubmit") { model.push(.appClipBanner(view.experience.uuid)) }
                    case .unknown:
                        NoticeCard(title: String(localized: "Apple could not be reached"),
                                   message: String(localized: "Nothing above was read just now, so it may be out of date. This is about this server's connection to App Store Connect, not about your experience."), kind: .alert)
                    case .live:
                        NoticeCard(title: String(localized: "The card is showing"),
                                   message: String(localized: "Scanning the code brings up your banner, your two lines and the button. Changing any of them sends the card back for review."))
                    default:
                        EmptyView()
                    }
                    if let url = URL(string: view.appStoreConnectUrl) {
                        Link("Open in App Store Connect", destination: url)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
            }
        }
        .refreshable { await store.refresh() }
        .task { await store.load() }
    }
}

private struct TimelineRow: View {
    let step: AppClipCard.Step
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .font(.body.weight(.semibold))
                    .symbolEffect(.pulse, isActive: step.state == .current)
                if !isLast {
                    Rectangle().fill(.quaternary).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label).font(.subheadline.weight(.medium))
                    .foregroundStyle(step.state == .pending ? .secondary : .primary)
                if let meta = step.meta { Text(meta).font(.footnote).foregroundStyle(.secondary) }
                Text(verbatim: step.source).font(.caption2).textCase(.uppercase).foregroundStyle(.tertiary)
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
    }

    private var symbol: String {
        switch step.state {
        case .done: return "checkmark.circle.fill"
        case .current: return "circle.dotted.circle"
        case .pending: return "circle"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch step.state {
        case .done: return .maqrLive
        case .current: return .maqrAccent
        case .pending: return .secondary
        case .failed: return .red
        }
    }
}
