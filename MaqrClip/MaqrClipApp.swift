//
//  MaqrClipApp.swift
//  MaqrClip
//
//  What a printed code opens: the experience it names, drawn natively by
//  the same views as the app's Launch and the designer's preview.
//

import GuestExperience
import MaqrDashboard
import StoreKit
import SwiftUI

@main
struct MaqrClipApp: App {
    private let client: MaqrClient
    @State private var link: GuestLink?
    @State private var offersApp = false

    init() {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif

        let env = Bundle.main.url(forResource: "env", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        var site = ServerEnvironment.site(envJSON: env, isDebug: isDebug)
        var opened: GuestLink?
        #if DEBUG
        // `-maqrServer https://127.0.0.1:18080` and `-maqrOpen https://maqr.co/ewed/<id>`
        // stand in for an invocation while checking a page on a simulator.
        if let override = UserDefaults.standard.string(forKey: "maqrServer"), let url = URL(string: override) {
            site = url
        }
        if let open = UserDefaults.standard.string(forKey: "maqrOpen"), let url = URL(string: open) {
            opened = GuestLink(url: url)
        }
        #endif
        let host = site.host ?? ""
        let session = LocalServerTrust.isLocal(host)
            ? URLSession(configuration: .default, delegate: LocalServerTrust(host: host), delegateQueue: nil)
            : URLSession.shared

        let device = DeviceIdentity(uuid: DeviceIdentity.persistentUUID(), name: UIDevice.current.name, model: UIDevice.current.model)
        client = MaqrClient(site: site, device: device, urlSession: session)
        GuestFonts.install(client: client)
        _link = State(initialValue: opened)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let link {
                    GuestLoaderView(link: link, client: client).id(link)
                } else {
                    ClipWelcome { offersApp = true }
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { open(url) }
            }
            .onOpenURL(perform: open)
            .appStoreOverlay(isPresented: $offersApp) {
                SKOverlay.AppClipConfiguration(position: .bottom)
            }
            .task(id: link) {
                // Once a guest has had a look round, the full app is offered
                // once — never over the first thing they came to see.
                guard link != nil else { return }
                try? await Task.sleep(for: .seconds(45))
                offersApp = true
            }
        }
    }

    private func open(_ url: URL) {
        guard let next = GuestLink(url: url) else { return }
        withAnimation(.smooth) { link = next }
    }
}

/// Opened without a code — from the home screen, or a link that names
/// nothing a guest can see.
private struct ClipWelcome: View {
    let getApp: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Scan a maQR code", systemImage: "qrcode.viewfinder")
        } description: {
            Text("Point your camera at a code on an invitation, a table or a box, and its page opens here.")
        } actions: {
            Button("Get the maQR app", action: getApp).buttonStyle(.borderedProminent)
        }
        .tint(Color(guestHex: GuestPalette.gold))
    }
}
