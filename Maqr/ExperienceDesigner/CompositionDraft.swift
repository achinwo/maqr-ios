//
//  CompositionDraft.swift
//  Maqr
//
//  The document the designer is editing is ``CompositionDraft`` in maqr-core's
//  ExperienceModel — one class for this designer and the web's, so both make
//  the same edits to a composed experience. What is here is only what
//  SwiftUI's lists and the app's JSON text need of it.
//

import DesignerFoundation
import ExperienceModel
import Foundation

extension CompositionDraft {
    /// A starting document from JSON text — a template's, or a copy of
    /// someone's — made this experience's own (``starting(_:templateCode:category:)``).
    static func starting(json: String, templateCode: String, category: String?) -> CompositionDraft {
        starting(JSONValue.parse(json) ?? .object(JSONObject()), templateCode: templateCode, category: category)
    }

    /// `List.onMove`'s answer, applied one section at a time.
    func moveBlocks(from source: IndexSet, to destination: Int) {
        guard let from = source.first else { return }
        // `onMove` counts the destination in the list *with* the moved row.
        moveBlock(from: from, to: destination > from ? destination - 1 : destination)
    }
}
