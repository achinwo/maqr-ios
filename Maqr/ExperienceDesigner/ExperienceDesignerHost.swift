//
//  ExperienceDesignerHost.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import Foundation
import GuestExperience
import MaqrDashboard
import UIKit

/// What the designer needs from the app around it: templates to start from,
/// documents to open and save, somewhere to put photos, and the font
/// catalogue.
///
/// Closures, so the view stays free of networking and previews can run
/// without a server.
struct ExperienceDesignerHost {
    var templates: () async throws -> [TemplateSummary]
    /// A template's starting document, as JSON text.
    var templateDocument: (_ code: String) async throws -> String
    /// An experience's document, for editing or for a copy.
    var open: (_ uuid: String) async throws -> DocumentEnvelope
    /// Creates an experience, at the address given when there is one.
    var create: (_ documentJSON: String, _ templateCode: String, _ category: String?, _ uuid: String?) async throws -> DocumentEnvelope
    /// Saves a whole document over an experience.
    var save: (_ uuid: String, _ documentJSON: String) async throws -> DocumentEnvelope
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

    /// Points the model's font hooks at this host. The designer calls it as
    /// it is made, before anything it draws asks for a font.
    @MainActor
    func install() {
        let fetchFonts = self.fetchFonts
        FontCatalog.requestCatalogue = {
            Task { @MainActor in
                FontCatalog.receive((try? await fetchFonts()) ?? "")
            }
        }
        // Catalogue fonts are web stylesheets; their TrueType faces are
        // registered for this process, so the preview and the font list draw
        // in them as they arrive.
        FontCatalog.loadStylesheet = { url in
            Task { @MainActor in await GuestFonts.shared.load(stylesheet: url) }
        }
    }
}

extension ExperienceDesignerHost {
    /// The Maqr server, through the dashboard's client — so the designer
    /// saves as whoever is signed in to the dashboard.
    static func live(client: MaqrClient) -> ExperienceDesignerHost {
        ExperienceDesignerHost(
            templates: { try await client.templates() },
            templateDocument: { try await client.templateDocument($0) },
            open: { try await client.experienceDocument($0) },
            create: { json, template, category, uuid in
                try await client.createExperience(documentJSON: json, templateCode: template, category: category, uuid: uuid)
            },
            save: { uuid, json in try await client.saveExperience(uuid: uuid, documentJSON: json) },
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

    /// No server: one blank template, and saves that hand back a made-up id,
    /// so previews can walk the whole flow.
    static let offline = ExperienceDesignerHost(
        templates: { [TemplateSummary(code: "blank", name: "Blank", tagline: "Start from nothing")] },
        templateDocument: { _ in
            #"{"version":1,"identity":{"title":"","subtitle":""},"theme":{"surface":"card-light","palette":{},"background":{"mode":"none"},"typography":{}},"layout":{"kind":"scroll","home":[]},"blocks":[]}"#
        },
        open: { _ in throw HostError.server(String(localized: "Opening needs a connection.")) },
        create: { _, _, _, _ in throw HostError.server(String(localized: "Saving needs a connection.")) },
        save: { _, _ in throw HostError.server(String(localized: "Saving needs a connection.")) },
        uploadImage: { _ in throw HostError.server(String(localized: "Uploads need a connection.")) },
        fetchFonts: { "[]" }
    )
}
