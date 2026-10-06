//
//  GuestShareViews.swift
//  Maqr
//
//  The two pages guests add to: the album (`PhotoBucketView`) and the guest
//  book (`GuestBookPanel`).
//

import AVKit
import GuestExperience
import PhotosUI
import SafariServices
import SwiftUI

// MARK: - Album

struct AlbumPage: View {
    let experience: GuestExperience
    @Bindable var store: AlbumStore
    @State private var picks: [PhotosPickerItem] = []
    @State private var viewing: AlbumPhoto?
    @State private var deleting: AlbumPhoto?
    @Environment(\.guestPaint) private var paint

    var body: some View {
        let photos = store.photos(of: experience)
        ScrollView {
            VStack(spacing: 16) {
                PageHeading(title: String(localized: "Photos"), subtitle: String(localized: "Every picture from the day, in one place"))
                if store.uploading > 0 {
                    HStack(spacing: 10) {
                        ProgressView().tint(paint.gold)
                        Text("^[Uploading \(store.uploading) photo](inflect: true)…").font(.subheadline).foregroundStyle(paint.soft)
                    }
                    .padding(12).glassCard(cornerRadius: 14)
                    .transition(.scale.combined(with: .opacity))
                }
                if store.hasLoaded, photos.isEmpty {
                    EmptyPage(symbol: "photo.on.rectangle.angled", message: String(localized: "Be the first to add a photo."))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 4)], spacing: 4) {
                    ForEach(photos) { photo in
                        Button { viewing = photo } label: {
                            // A square the grid sizes, with the picture filling
                            // it — the picture never decides the cell's size.
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { GuestImage(url: photo.thumbnailURL) }
                                .clipped()
                                .overlay(alignment: .bottomLeading) {
                                    if photo.isVideo {
                                        Label(photo.durationText ?? "", systemImage: "play.fill")
                                            .labelStyle(.titleAndIcon)
                                            .font(.caption2.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                            .background(.black.opacity(0.5), in: Capsule())
                                            .padding(6)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            if let url = photo.mediaURL { ShareLink(item: url) }
                            if photo.mine {
                                Button("Delete", systemImage: "trash", role: .destructive) { deleting = photo }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 12)
                .animation(.snappy, value: photos.count)
            }
            .padding(.top, 16).padding(.bottom, 110)
        }
        .refreshable { await store.load() }
        .safeAreaInset(edge: .bottom) {
            if store.canUpload {
                PhotosPicker(selection: $picks, maxSelectionCount: 20, matching: .images) {
                    Label("Add your photos", systemImage: "plus")
                }
                .buttonStyle(GoldButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 8)
            }
        }
        .task { await store.load() }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            picks = []
            Task { await store.upload(await GuestPhotos.prepare(items)) }
        }
        .fullScreenCover(item: $viewing) { photo in
            PhotoViewer(photos: photos, current: photo)
        }
        .confirmationDialog("Delete this photo?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let photo = deleting { Task { await store.delete(photo) } }
            }
        } message: {
            Text("It's taken out of the album for everyone.")
        }
        .alert(store.failure ?? "", isPresented: Binding(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

/// One photo at a time, swiped through, full screen.
private struct PhotoViewer: View {
    let photos: [AlbumPhoto]
    @State var current: AlbumPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $current) {
                ForEach(photos) { photo in
                    Group {
                        if photo.isVideo, let url = photo.mediaURL {
                            AlbumVideo(url: url, poster: photo.thumbnailURL, isCurrent: current == photo)
                        } else {
                            GuestImage(url: photo.mediaURL, contentMode: .fit)
                        }
                    }
                    .tag(photo)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let url = current.mediaURL { ShareLink(item: url) }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.colorScheme, .dark)
    }
}

/// A video in the album, played in place from storage — which serves it
/// with ranges, so it seeks — and paused when swiped away.
private struct AlbumVideo: View {
    let url: URL
    let poster: URL?
    let isCurrent: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                GuestImage(url: poster, contentMode: .fit)
                ProgressView().tint(.white)
            }
        }
        .onAppear { if isCurrent { start() } }
        .onChange(of: isCurrent) { _, isCurrent in
            if isCurrent { start() } else { player?.pause() }
        }
        .onDisappear { player?.pause() }
    }

    private func start() {
        // Playback rather than the default ambient category, so a video is
        // heard with the ring switch on silent — as in Photos.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        if player == nil { player = AVPlayer(url: url) }
        player?.play()
    }
}

/// Photos as the album takes them: JPEG, no longer than 2048 points.
enum GuestPhotos {
    static func prepare(_ items: [PhotosPickerItem]) async -> [(data: Data, width: Int, height: Int)] {
        var prepared: [(data: Data, width: Int, height: Int)] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let photo = prepare(data) {
                prepared.append(photo)
            }
        }
        return prepared
    }

    static func prepare(_ data: Data) -> (data: Data, width: Int, height: Int)? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, 2048 / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        return (jpeg, Int(size.width), Int(size.height))
    }
}

// MARK: - Guest book

struct GuestBookPage: View {
    let wording: GuestBookWording
    @Bindable var store: GuestBookStore
    @State private var isWriting = false
    @Environment(\.guestPaint) private var paint

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeading(title: store.book?.title ?? wording.title, subtitle: store.book?.message ?? wording.message)
                if store.isOpen {
                    Button { isWriting = true } label: { Label("Leave a message", systemImage: "square.and.pencil") }
                        .buttonStyle(GoldButtonStyle())
                        .padding(.horizontal, 8)
                        .reveal(delay: 0.2)
                }
                if store.isLoading {
                    ProgressView().tint(paint.gold).padding()
                } else if store.entries.isEmpty {
                    EmptyPage(symbol: "signature", message: String(localized: "No messages yet."))
                }
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    EntryCard(entry: entry) { Task { await store.delete(entry) } }
                        .reveal(delay: min(0.3 + Double(index) * 0.05, 0.8))
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
            .animation(.snappy, value: store.entries)
        }
        .refreshable { await store.load() }
        .task { await store.load() }
        .sheet(isPresented: $isWriting) { ComposeMessage(store: store) }
    }
}

private struct EntryCard: View {
    let entry: GuestBookEntry
    let delete: () -> Void
    @State private var isExpanded = false
    @Environment(\.guestPaint) private var paint

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = entry.imageURL {
                GuestImage(url: url).frame(height: 200).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !entry.title.isEmpty {
                Text(markdown(entry.title)).displayFont(22, relativeTo: .title3).foregroundStyle(paint.gold)
            }
            Text(markdown(entry.message))
                .font(GuestType.body(17))
                .lineSpacing(4)
                .foregroundStyle(paint.text.opacity(0.92))
                .lineLimit(isExpanded ? nil : 7)
            if entry.message.count > 260 {
                Button(isExpanded ? "Show less" : "Read more") { withAnimation(.snappy) { isExpanded.toggle() } }
                    .font(.footnote.weight(.semibold)).tint(paint.gold)
            }
            HStack {
                if !entry.signature.isEmpty {
                    Text("— \(entry.signature)").font(GuestType.body(16)).italic().foregroundStyle(paint.soft)
                }
                Spacer()
                if let posted = entry.posted {
                    Text(posted, format: .relative(presentation: .named)).font(.caption).foregroundStyle(paint.faint)
                }
            }
        }
        .padding(18)
        .glassCard()
        .contextMenu {
            if entry.mine {
                Button("Delete my message", systemImage: "trash", role: .destructive, action: delete)
            }
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

private struct ComposeMessage: View {
    let store: GuestBookStore
    @State private var title = ""
    @State private var message = ""
    @State private var signature = ""
    @State private var pick: PhotosPickerItem?
    @State private var photo: (data: Data, width: Int, height: Int)?
    @State private var sent = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("A title (optional)", text: $title)
                    TextField("Your message", text: $message, axis: .vertical).lineLimit(6...14)
                }
                Section {
                    TextField("Signed", text: $signature)
                        .textContentType(.name)
                } footer: {
                    Text("Everyone who visits this page will see it.")
                }
                Section {
                    PhotosPicker(selection: $pick, matching: .images) {
                        if let photo, let image = UIImage(data: photo.data) {
                            Image(uiImage: image).resizable().scaledToFill().frame(height: 180).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            Label("Add a photo", systemImage: "photo.badge.plus")
                        }
                    }
                }
                if let failure = store.failure {
                    Section { Label(failure, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Leave a message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if store.isPosting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            Task {
                                if await store.post(message: message, signature: signature, title: title, photo: photo) {
                                    sent += 1
                                    dismiss()
                                }
                            }
                        }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onChange(of: pick) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    photo = GuestPhotos.prepare(data)
                }
            }
            .sensoryFeedback(.success, trigger: sent)
        }
        .presentationDetents([.large])
    }
}

// MARK: - Safari

/// A web page over the guest page — for the one thing finished on the web,
/// paying by card.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
