//
//  MaqrApp.swift
//  Maqr
//
//  The maQR app: the /my dashboard, drawn natively over MaqrDashboard.
//

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

        // A store that cannot be opened (a failed migration, a full disk)
        // costs the offline copy, not the app: it runs from memory instead.
        let container = (try? DashboardSchema.container()) ?? (try! DashboardSchema.container(inMemory: true))

        _model = State(initialValue: AppModel(dashboard: Dashboard(client: client, container: container)))
    }

    var body: some Scene {
        WindowGroup {
            DashboardRoot(model: model)
                .task {
                    await adoptLegacySession()
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
                    if let l = UserDefaults.standard.string(forKey: "maqrTmpLaunch"), let u = URL(string: l) { model.launching = WebHandoff(url: u, title: "Esther & Jide", session: nil) } // TMP
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
