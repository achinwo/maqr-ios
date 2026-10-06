//
//  ExperienceDesignerHost.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import Foundation
import MaqrDashboard
import UIKit

/// What the designer needs from the app around it: somewhere to save, to put
/// photos, and to get the font catalogue from.
///
/// The browser designer asks its page for the same things through DOM events;
/// here they are closures, so the view stays free of networking and previews
/// can run without a server.
struct ExperienceDesignerHost {
    /// Saves a row as ``ExperienceCodec`` writes it, returning its uuid.
    var save: (_ json: String) async throws -> String
    /// Uploads a photo, returning where it can be read from.
    var uploadImage: (_ image: UIImage) async throws -> URL
    /// The `font_families` rows, as a JSON array.
    var fetchFonts: () async throws -> String

    enum HostError: LocalizedError {
        case unreadableResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .unreadableResponse: return String(localized: "The server's answer couldn't be read.")
            case .server(let message): return message
            }
        }
    }

    /// Points the model's host hooks at this host. The designer calls it as it
    /// appears; until then the font picker offers only the page's own font.
    @MainActor
    func install() {
        let fetchFonts = self.fetchFonts
        FontCatalog.requestCatalogue = {
            Task { @MainActor in
                FontCatalog.receive((try? await fetchFonts()) ?? "")
            }
        }
        // Catalogue fonts are web stylesheets; the native preview draws in the
        // system's faces, so there is nothing to load.
        FontCatalog.loadStylesheet = { _ in }
    }
}

extension ExperienceDesignerHost {
    /// The Maqr server, through the dashboard's client — so the designer
    /// saves as whoever is signed in to the dashboard.
    static func live(client: MaqrClient) -> ExperienceDesignerHost {
        ExperienceDesignerHost(
            save: { json in try await client.saveExperience(json: json) },
            uploadImage: { image in
                guard let data = image.jpegData(compressionQuality: 0.8) else {
                    throw HostError.server(String(localized: "That photo couldn't be read."))
                }
                let address = try await client.uploadImage(data, fileExtension: "jpg", prefix: "designer")
                guard let url = URL(string: address) else { throw HostError.unreadableResponse }
                return url
            },
            fetchFonts: { try await client.fontsJSON() }
        )
    }

    /// No server: saves hand back a made-up id, so previews can walk the
    /// whole flow.
    static let offline = ExperienceDesignerHost(
        save: { _ in UUID().uuidString.lowercased() },
        uploadImage: { _ in throw HostError.server(String(localized: "Uploads need a connection.")) },
        fetchFonts: { "[]" }
    )
}
