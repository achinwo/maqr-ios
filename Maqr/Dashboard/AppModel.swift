//
//  AppModel.swift
//  Maqr
//
//  Navigation and presentation for the dashboard: which tab, which screens
//  are pushed, what is presented over them. Everything the screens decide
//  lives in MaqrDashboard; this only moves between them.
//

import GuestExperience
import MaqrDashboard
import SwiftUI

/// Every screen that can be pushed, by what it is about.
enum Route: Hashable {
    case design(String)
    case events
    case billing
    case invitation(String)
    case experience(String)
    case code(String)
    case codeDownload(String)
    case printTemplates(String)
    case printTemplate(String, String)
    case stats(String)
    case notify(String)
    case people(String)
    case review(String)
    case publish(String)
    case plans(String)
    case published(String)
    case appClip(String)
    case appClipCard(String)
    case appClipBanner(String)
    case appClipStatus(String)
}

enum AppTab: Hashable {
    case home, explore, create, me
}

/// What the designer is opened on.
enum DesignerRequest: Identifiable {
    case new
    case remix(title: String, row: Data)
    case edit(uuid: String, row: Data)

    var id: String {
        switch self {
        case .new: return "new"
        case .remix(let title, _): return "remix-\(title)"
        case .edit(let uuid, _): return "edit-\(uuid)"
        }
    }
}

/// A request to sign in, and what to do once signed in.
struct SignInRequest: Identifiable {
    let id = UUID()
    var stage: SignInStore.Stage = .choices
    var designTitle: String?
    var onSignedIn: () -> Void = {}
}

@Observable
final class AppModel {
    let dashboard: Dashboard

    var tab: AppTab
    var homePath: [Route] = []
    var explorePath: [Route] = []
    var mePath: [Route] = []

    var signIn: SignInRequest?
    var designer: DesignerRequest?
    var webHandoff: WebHandoff?
    /// An experience opened as guests see it, over everything.
    var launching: GuestLink?

    @ObservationIgnored private var experienceStores: [String: ExperienceStore] = [:]

    init(dashboard: Dashboard) {
        self.dashboard = dashboard
        // The front door opens on different rooms: your own things if you
        // are signed in, everyone else's if not.
        self.tab = dashboard.session.isSignedIn ? .home : .explore
    }

    var isSignedIn: Bool { dashboard.session.isSignedIn }

    /// One store per experience, shared by the hub and every screen under it.
    func experienceStore(_ id: String) -> ExperienceStore {
        if let existing = experienceStores[id] { return existing }
        let store = ExperienceStore(dashboard: dashboard, id: id)
        experienceStores[id] = store
        return store
    }

    /// Everything that belonged to the last account goes when it changes.
    func accountChanged() {
        experienceStores = [:]
        homePath = []
        explorePath = []
        mePath = []
        if !isSignedIn, tab != .explore { tab = .explore }
    }

    // MARK: Moving around

    /// Pushes onto whichever tab is showing.
    func push(_ route: Route) {
        switch tab {
        case .home, .create: homePath.append(route)
        case .explore: explorePath.append(route)
        case .me: mePath.append(route)
        }
    }

    /// Pops the current tab back to its root.
    func popToRoot() {
        switch tab {
        case .home, .create: homePath = []
        case .explore: explorePath = []
        case .me: mePath = []
        }
    }

    /// Runs `action` signed in, asking first if need be.
    func requireAccount(designTitle: String? = nil, stage: SignInStore.Stage = .choices, then action: @escaping () -> Void) {
        if isSignedIn {
            action()
        } else {
            signIn = SignInRequest(stage: stage, designTitle: designTitle, onSignedIn: action)
        }
    }

    /// The Create tab, which opens the designer rather than a screen.
    func selectTab(_ next: AppTab) {
        guard next == .create else {
            tab = next
            return
        }
        requireAccount { self.designer = .new }
    }

    /// Opens the experience's guest page, full screen.
    func launch(_ design: Design) {
        launching = design.liveURL.flatMap(GuestLink.init(url:))
    }

    /// Opens the designer on a copy of someone else's design.
    func remix(_ design: Design, row: Data?) {
        requireAccount(designTitle: design.title) {
            if let row { self.designer = .remix(title: design.title, row: row) }
        }
    }

    // MARK: Links

    /// A maqr.co link, opened as the screen it names — `/my/experience/:id`,
    /// `/my/design/:id`, `/my/invite/:token` and the rest of src/my's routes.
    func open(_ url: URL) {
        // A guest page — `/ewed/<id>` and the rest — opens as guests see it.
        if let link = GuestLink(url: url) {
            launching = link
            return
        }
        var parts = url.pathComponents.filter { $0 != "/" }
        guard parts.first == "my" else { return }
        parts.removeFirst()

        func go(_ tab: AppTab, _ routes: [Route]) {
            self.tab = tab
            switch tab {
            case .explore: explorePath = routes
            case .me: mePath = routes
            default: homePath = routes
            }
        }

        switch parts.first {
        case "explore": go(.explore, [])
        case "design" where parts.count > 1: go(.explore, [.design(parts[1])])
        case "remix" where parts.count > 1: go(.explore, [.design(parts[1])])
        case "invite" where parts.count > 1: go(isSignedIn ? .home : .explore, [.invitation(parts[1])])
        case "events": requireAccount { go(.home, [.events]) }
        case "me": requireAccount { go(.me, []) }
        case "billing": requireAccount { go(.me, [.billing]) }
        case "experience" where parts.count > 1:
            let id = parts[1]
            let rest = Array(parts.dropFirst(2))
            requireAccount { go(.home, [.experience(id)] + Self.routes(under: id, rest)) }
        default:
            if isSignedIn { go(.home, []) } else { go(.explore, []) }
        }
    }

    /// The screens under an experience a link names, each one segment deeper.
    static func routes(under id: String, _ rest: [String]) -> [Route] {
        switch rest {
        case ["code"]: return [.code(id)]
        case ["code", "download"]: return [.code(id), .codeDownload(id)]
        case ["print"]: return [.printTemplates(id)]
        case let path where path.count == 2 && path[0] == "print": return [.printTemplates(id), .printTemplate(id, path[1])]
        case ["stats"]: return [.stats(id)]
        case ["notify"]: return [.notify(id)]
        case ["people"]: return [.people(id)]
        case ["review"]: return [.review(id)]
        case ["publish"]: return [.publish(id)]
        case ["publish", "plans"], ["publish", "pay"]: return [.publish(id), .plans(id)]
        case ["publish", "done"]: return [.publish(id), .published(id)]
        case ["appclip"]: return [.appClip(id)]
        case ["appclip", "card"]: return [.appClip(id), .appClipCard(id)]
        case ["appclip", "banner"]: return [.appClip(id), .appClipBanner(id)]
        case ["appclip", "status"]: return [.appClip(id), .appClipStatus(id)]
        default: return []
        }
    }
}
