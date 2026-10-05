//
//  ExperienceDesignerHost.swift
//  Maqr
//

import DesignerFoundation
import ExperienceModel
import Foundation
import MaqrApi
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
            case .unreadableResponse: return "The server's answer couldn't be read."
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
    /// The Maqr server, through the app's API client.
    static func live(api: MaqrApi) -> ExperienceDesignerHost {
        ExperienceDesignerHost(
            save: { json in
                var request = URLRequest(url: api.baseUrlHttp.appendingPathComponent("/api/db/experiences"))
                request.httpMethod = HttpMethod.post.rawValue
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data(json.utf8)

                let (data, _) = try await api.urlSession.data(for: request)
                let reply = JSONValue.parse(String(decoding: data, as: UTF8.self))
                if let uuid = reply?["data"]["uuid"].string {
                    return uuid
                }
                if let message = reply?["error"]["message"].string {
                    throw HostError.server(message)
                }
                throw HostError.unreadableResponse
            },
            uploadImage: { image in
                try await MaqrApi.upload(image, baseUrl: api.baseUrlHttp, urlSession: api.urlSession).fileUrl
            },
            fetchFonts: {
                let url = api.baseUrlHttp.appendingPathComponent("/api/db/fonts")
                let (data, _) = try await api.urlSession.data(from: url)
                // The endpoint wraps its rows in `data`, like every `/api/db` one.
                let reply = JSONValue.parse(String(decoding: data, as: UTF8.self))
                let rows = reply?["data"] ?? reply ?? .array([])
                return rows.stringified()
            }
        )
    }

    /// No server: saves hand back a made-up id, so previews can walk the
    /// whole flow.
    static let offline = ExperienceDesignerHost(
        save: { _ in UUID().uuidString.lowercased() },
        uploadImage: { _ in throw HostError.server("Uploads need a connection.") },
        fetchFonts: { "[]" }
    )
}
