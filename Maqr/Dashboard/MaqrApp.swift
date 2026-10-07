//
//  MaqrApp.swift
//  Maqr
//
//  The maQR app: the /my dashboard, drawn natively over MaqrDashboard.
//

import GuestExperience
import MaqrDashboard
import SwiftData
import SwiftUI

@main
struct MaqrApp: App {
    @State private var model: AppModel

    init() {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif

        let env = Bundle.main.url(forResource: "env", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        var site = ServerEnvironment.site(envJSON: env, isDebug: isDebug)
        #if DEBUG
        // `-maqrServer https://127.0.0.1:18080` points a debug build at a
        // local server without touching env.json.
        if let override = UserDefaults.standard.string(forKey: "maqrServer"), let url = URL(string: override) {
            site = url
        }
        #endif
        let host = site.host ?? ""
        let urlSession = LocalServerTrust.isLocal(host)
            ? URLSession(configuration: .default, delegate: LocalServerTrust(host: host), delegateQueue: nil)
            : URLSession.shared

        let device = DeviceIdentity(
            uuid: DeviceIdentity.persistentUUID(),
            name: UIDevice.current.name,
            model: UIDevice.current.model)
        let client = MaqrClient(site: site, device: device, urlSession: urlSession)
        // Catalogue typefaces, for the guest pages and the designer.
        GuestFonts.install(client: client)

        // A store that cannot be opened (a failed migration, a full disk)
        // costs the offline copy, not the app: it runs from memory instead.
        let container = (try? DashboardSchema.container()) ?? (try! DashboardSchema.container(inMemory: true))

        let dashboard = Dashboard(client: client, container: container)
        // Publishing is bought through the App Store (Purchasing.swift).
        let purchases = StoreKitPurchases(client: client, isSignedIn: { @MainActor in dashboard.session.isSignedIn })
        dashboard.purchasing = purchases
        self.purchases = purchases

        _model = State(initialValue: AppModel(dashboard: dashboard))
    }

    private let purchases: StoreKitPurchases

    var body: some Scene {
        WindowGroup {
            DashboardRoot(model: model)
                .task {
                    await adoptLegacySession()
                    // Purchases interrupted last time, or approved since.
                    purchases.startListening()
                    #if DEBUG
                    // `-maqrToken <session token>` signs in as that session.
                    if let token = UserDefaults.standard.string(forKey: "maqrToken") {
                        await model.dashboard.session.adoptToken(token)
                    }
                    // `-maqrOpen https://maqr.co/my/…` as a launch argument opens
                    // that screen, for checking one without tapping to it.
                    if let link = UserDefaults.standard.string(forKey: "maqrOpen"), let url = URL(string: link) {
                        model.open(url)
                    }
                    #endif
                }
        }
    }

    /// The previous version of the app kept its session token in user
    /// defaults. Signing in with it once means an update does not sign
    /// anybody out.
    private func adoptLegacySession() async {
        let key = "active-session-id"
        guard let token = UserDefaults.standard.string(forKey: key), !token.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: key)
        if await model.dashboard.session.adoptToken(token) {
            model.tab = .home
        }
    }
}
