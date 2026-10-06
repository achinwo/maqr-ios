//
//  GuestLoaderView.swift
//  Maqr
//
//  A link in, an experience out: the App Clip's whole screen, and the app's
//  Launch.
//

import GuestExperience
import MaqrDashboard
import SwiftUI

struct GuestLoaderView: View {
    let link: GuestLink
    @State private var loader: GuestLoader
    @Environment(\.openURL) private var openURL

    init(link: GuestLink, client: MaqrClient) {
        self.link = link
        _loader = State(initialValue: GuestLoader(client: client))
    }

    var body: some View {
        Group {
            switch loader.state {
            case .loading:
                LoadingMark()
            case .loaded(let experience, let connection, let document):
                Group {
                    if let document {
                        GuestExperienceView(source: .document(document, uuid: experience.uuid), connection: connection, focus: link.focus, table: link.table)
                    } else {
                        GuestExperienceView(source: .experience(experience), connection: connection, focus: link.focus, table: link.table)
                    }
                }
                .transition(.opacity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't open this", systemImage: "qrcode.viewfinder")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await loader.load(link) } }
                        .buttonStyle(.borderedProminent)
                    Button("Open on the web") { openURL(link.webURL(site: loader.site)) }
                }
            }
        }
        .animation(.smooth(duration: 0.45), value: loader.isLoaded)
        .task(id: link) { await loader.load(link) }
    }
}

extension GuestLoader {
    var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }
}

/// The maQR mark breathing while a page is read.
struct LoadingMark: View {
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color(guestHex: GuestPalette.gold))
                .scaleEffect(isBreathing ? 1.06 : 0.94)
                .opacity(isBreathing ? 1 : 0.6)
            ProgressView().tint(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(guestHex: GuestPalette.ink).ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { isBreathing = true }
        }
    }
}
