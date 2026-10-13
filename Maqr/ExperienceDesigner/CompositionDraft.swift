//
//  CompositionDraft.swift
//  Maqr
//
//  The document the designer is editing — a composed experience
//  (docs/architecture/composable-experiences.md in maqr-server) held as JSON,
//  and every edit the designer makes to it, as one method each: a field by its
//  path, a section added, moved, hidden or removed, an item in a section's
//  list. Unknown keys are kept on every edit, so a section a newer server
//  added survives a save from this build.
//

import DesignerFoundation
import ExperienceModel
import Foundation
import Observation

@Observable
final class CompositionDraft {
    /// The whole document, as it will be saved.
    private(set) var document: JSONValue
    /// The template it started from — informational, saved with a new one.
    let templateCode: String
    let category: String?
    /// The saved experience's uuid; nil until the first save.
    private(set) var uuid: String?

    init(document: JSONValue, templateCode: String, category: String? = nil, uuid: String? = nil) {
        self.document = document
        self.templateCode = templateCode
        self.category = category
        self.uuid = uuid
    }

    /// A starting document — a template's, or a copy of someone's — made
    /// this experience's own: the row ids a copy carried go, since its items
    /// have no rows yet, as ``instantiate`` does on the server.
    static func starting(json: String, templateCode: String, category: String?) -> CompositionDraft {
        let document = JSONValue.parse(json).map(withoutRows) ?? .object(JSONObject())
        return CompositionDraft(document: document, templateCode: templateCode, category: category)
    }

    var composition: Composition { Composition(document) }
    var json: String { document.stringified() }
    var isHub: Bool { document["layout"]["kind"].string != "scroll" }

    func adopt(savedUuid: String) { uuid = savedUuid }

    // MARK: - Fields

    func value(_ path: String) -> JSONValue { document.value(at: path) }

    func set(_ path: String, _ value: JSONValue) { document.set(value, at: path) }

    /// Text for a field: empty text is stored as no value, so a cleared field
    /// leaves nothing behind.
    func setText(_ path: String, _ text: String) {
        set(path, text.isEmpty ? .null : .string(text))
    }

    // MARK: - Sections

    var blocks: [JSONValue] { document["blocks"].array ?? [] }

    func block(_ id: String) -> JSONValue? { blocks.first { $0["id"].string == id } }

    private func blockIndex(_ id: String) -> Int? { blocks.firstIndex { $0["id"].string == id } }

    func blockValue(_ id: String, _ path: String) -> JSONValue { block(id)?.value(at: path) ?? .null }

    func setBlock(_ id: String, _ path: String, _ value: JSONValue) {
        guard let index = blockIndex(id) else { return }
        var all = blocks
        all[index].set(value, at: path)
        document.set(.array(all), at: "blocks")
    }

    /// Adds a section of `kind` with its manifest's defaults, after the
    /// others, and returns its id. A notice or a stream goes on the home
    /// screen, where every engine draws them.
    @discardableResult
    func addBlock(_ manifest: BlockManifest) -> String {
        let id = Self.mint("b")
        var block = JSONObject()
        block["id"] = .string(id)
        block["kind"] = .string(manifest.kind)
        block["v"] = .number(Double(manifest.version))
        block["slug"] = .string(freeSlug(manifest.defaultSlug.isEmpty ? manifest.kind : manifest.defaultSlug))
        block["title"] = .string(manifest.defaultTitle)
        if manifest.staffOnly { block["staffOnly"] = .bool(true) }
        block["props"] = JSONValue.parse(manifest.defaultPropsJSON) ?? .object(JSONObject())
        document.set(.array(blocks + [.object(block)]), at: "blocks")

        if manifest.kind == "notice" || manifest.kind == "livestream" {
            let home = document["layout"]["home"].array ?? []
            document.set(.array(home + [.string(id)]), at: "layout.home")
        }
        return id
    }

    func removeBlock(_ id: String) {
        document.set(.array(blocks.filter { $0["id"].string != id }), at: "blocks")
        for list in ["layout.home", "layout.footer"] {
            let ids = value(list).array ?? []
            if !ids.isEmpty { set(list, .array(ids.filter { $0.string != id })) }
        }
    }

    func moveBlocks(from source: IndexSet, to destination: Int) {
        var all = blocks
        all.move(fromOffsets: source, toOffset: destination)
        document.set(.array(all), at: "blocks")
    }

    func isHidden(_ id: String) -> Bool { blockValue(id, "hidden").bool ?? false }

    func setHidden(_ id: String, _ hidden: Bool) { setBlock(id, "hidden", hidden ? .bool(true) : .null) }

    private func freeSlug(_ wanted: String) -> String {
        let taken = Set(blocks.compactMap { $0["slug"].string })
        guard taken.contains(wanted) else { return wanted }
        var number = 2
        while taken.contains("\(wanted)-\(number)") { number += 1 }
        return "\(wanted)-\(number)"
    }

    // MARK: - A section's items

    /// The items of a section's collection. The menu's `dishes` is a flat
    /// view over its courses and headings, so a dish is edited as one row
    /// with the course and heading it sits under.
    func items(_ id: String, collection: String) -> [JSONValue] {
        if isDishes(id, collection) { return dishes(id) }
        return blockValue(id, "props.\(collection)").array ?? []
    }

    func setItems(_ id: String, collection: String, _ items: [JSONValue]) {
        if isDishes(id, collection) {
            setBlock(id, "props.courses", Self.courses(from: items))
        } else {
            setBlock(id, "props.\(collection)", .array(items))
        }
    }

    func addItem(_ id: String, collection: String) {
        var item = JSONObject()
        item["id"] = .string(Self.mint("i"))
        let current = items(id, collection: collection)
        // A new dish joins the course and heading of the one before it.
        if isDishes(id, collection), let last = current.last {
            item["course"] = last["course"]
            item["heading"] = last["heading"]
        }
        setItems(id, collection: collection, current + [.object(item)])
    }

    func removeItem(_ id: String, collection: String, at index: Int) {
        var current = items(id, collection: collection)
        guard current.indices.contains(index) else { return }
        current.remove(at: index)
        setItems(id, collection: collection, current)
    }

    func moveItem(_ id: String, collection: String, from index: Int, by offset: Int) {
        var current = items(id, collection: collection)
        let target = index + offset
        guard current.indices.contains(index), current.indices.contains(target) else { return }
        current.swapAt(index, target)
        setItems(id, collection: collection, current)
    }

    func setItemField(_ id: String, collection: String, at index: Int, _ path: String, _ value: JSONValue) {
        var current = items(id, collection: collection)
        guard current.indices.contains(index) else { return }
        current[index].set(value, at: path)
        setItems(id, collection: collection, current)
    }

    private func isDishes(_ id: String, _ collection: String) -> Bool {
        collection == "dishes" && blockValue(id, "kind").string == "menu"
    }

    private func dishes(_ id: String) -> [JSONValue] {
        var flat: [JSONValue] = []
        for course in blockValue(id, "props.courses").array ?? [] {
            for heading in course["headings"].array ?? [] {
                for dish in heading["dishes"].array ?? [] {
                    var row = dish.object ?? JSONObject()
                    row["course"] = course["name"]
                    row["heading"] = heading["name"]
                    flat.append(.object(row))
                }
            }
        }
        return flat
    }

    /// Flat dishes regrouped into courses and headings, each in the order
    /// first met.
    static func courses(from dishes: [JSONValue]) -> JSONValue {
        var courseNames: [String] = []
        var headingNames: [String: [String]] = [:]
        var grouped: [String: [String: [JSONValue]]] = [:]
        for dish in dishes {
            let course = dish["course"].text, heading = dish["heading"].text
            if grouped[course] == nil { courseNames.append(course) }
            if grouped[course]?[heading] == nil { headingNames[course, default: []].append(heading) }
            var stored = dish.object ?? JSONObject()
            stored.removeValue(forKey: "course")
            stored.removeValue(forKey: "heading")
            if stored["name"].string == nil { stored["name"] = .string("") }
            grouped[course, default: [:]][heading, default: []].append(.object(stored))
        }
        return .array(courseNames.map { course in
            var object = JSONObject()
            object["name"] = .string(course)
            object["headings"] = .array((headingNames[course] ?? []).map { heading in
                var group = JSONObject()
                group["name"] = .string(heading)
                group["dishes"] = .array(grouped[course]?[heading] ?? [])
                return .object(group)
            })
            return .object(object)
        })
    }

    // MARK: - Support

    /// A fresh id — `mintId` in shared/document/templates.ts.
    static func mint(_ prefix: String) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return "\(prefix)_" + String((0..<8).map { _ in alphabet.randomElement()! })
    }

    /// The value without any `rowId` / `entryRowId`, recursively.
    private static func withoutRows(_ value: JSONValue) -> JSONValue {
        switch value {
        case .array(let items): return .array(items.map(withoutRows))
        case .object(let object):
            var out = JSONObject()
            for member in object.members where member.key != "rowId" && member.key != "entryRowId" {
                out[member.key] = withoutRows(member.value)
            }
            return .object(out)
        default: return value
        }
    }
}
