// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let authToken = try? newJSONDecoder().decode(AuthToken.self, from: jsonData)
//   let musicroom = try? newJSONDecoder().decode(Musicroom.self, from: jsonData)
//   let roomTrack = try? newJSONDecoder().decode(RoomTrack.self, from: jsonData)
//   let queuedTrack = try? newJSONDecoder().decode(QueuedTrack.self, from: jsonData)
//   let queuedTrackVote = try? newJSONDecoder().decode(QueuedTrackVote.self, from: jsonData)
//   let session = try? newJSONDecoder().decode(Session.self, from: jsonData)
//   let user = try? newJSONDecoder().decode(User.self, from: jsonData)
//   let track = try? newJSONDecoder().decode(Track.self, from: jsonData)

import Foundation

/// AuthToken
// MARK: - AuthToken
public struct AuthToken: Persisted, DataConvertible {
    public let accessToken: String
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let expiresIn: Int
    public let id: Int
    public let parentId: Int?
    public let refreshToken: String?
    public let scope: String
    public let tokenType: String?
    public let updatedAt: Date
    public let updatedById: Int?
    public let userId: Int?

    public enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case expiresIn = "expiresIn"
        case id = "id"
        case parentId = "parentId"
        case refreshToken = "refreshToken"
        case scope = "scope"
        case tokenType = "tokenType"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
        case userId = "userId"
    }

    public init(accessToken: String, createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, expiresIn: Int, id: Int, parentId: Int?, refreshToken: String?, scope: String, tokenType: String?, updatedAt: Date, updatedById: Int?, userId: Int?) {
        self.accessToken = accessToken
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.expiresIn = expiresIn
        self.id = id
        self.parentId = parentId
        self.refreshToken = refreshToken
        self.scope = scope
        self.tokenType = tokenType
        self.updatedAt = updatedAt
        self.updatedById = updatedById
        self.userId = userId
    }
}

/// RoomTrack
// MARK: - RoomTrack
public struct RoomTrack: Persisted, DataConvertible {
    public let addedBy: Int?
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let id: Int
    public let musicroom: Musicroom?
    public let roomId: Int
    public let track: Track?
    public let trackId: Int
    public let updatedAt: Date
    public let updatedById: Int?

    public enum CodingKeys: String, CodingKey {
        case addedBy = "addedBy"
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case id = "id"
        case musicroom = "musicroom"
        case roomId = "roomId"
        case track = "track"
        case trackId = "trackId"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
    }

    public init(addedBy: Int?, createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, id: Int, musicroom: Musicroom?, roomId: Int, track: Track?, trackId: Int, updatedAt: Date, updatedById: Int?) {
        self.addedBy = addedBy
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.id = id
        self.musicroom = musicroom
        self.roomId = roomId
        self.track = track
        self.trackId = trackId
        self.updatedAt = updatedAt
        self.updatedById = updatedById
    }
}

/// Musicroom
// MARK: - Musicroom
public struct Musicroom: Persisted, DataConvertible {
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let details: String
    public let id: Int
    public let name: String
    public let status: String?
    public let updatedAt: Date
    public let updatedById: Int?

    public enum CodingKeys: String, CodingKey {
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case details = "details"
        case id = "id"
        case name = "name"
        case status = "status"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
    }

    public init(createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, details: String, id: Int, name: String, status: String?, updatedAt: Date, updatedById: Int?) {
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.details = details
        self.id = id
        self.name = name
        self.status = status
        self.updatedAt = updatedAt
        self.updatedById = updatedById
    }
}

/// Track
// MARK: - Track
public struct Track: Persisted, DataConvertible {
    public let artistName: String
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let durationMs: Int?
    public let explicit: Bool?
    public let href: String?
    public let id: Int
    public let isLocal: Bool?
    public let name: String?
    public let popularity: Int?
    public let previewUrl: String?
    public let thumbnailUrl: String
    public let title: String
    public let trackId: String
    public let trackNumber: Int?
    public let type: String?
    public let updatedAt: Date
    public let updatedById: Int?
    public let uri: String

    public enum CodingKeys: String, CodingKey {
        case artistName = "artistName"
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case durationMs = "durationMs"
        case explicit = "explicit"
        case href = "href"
        case id = "id"
        case isLocal = "isLocal"
        case name = "name"
        case popularity = "popularity"
        case previewUrl = "previewUrl"
        case thumbnailUrl = "thumbnailUrl"
        case title = "title"
        case trackId = "trackId"
        case trackNumber = "trackNumber"
        case type = "type"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
        case uri = "uri"
    }

    public init(artistName: String, createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, durationMs: Int?, explicit: Bool?, href: String?, id: Int, isLocal: Bool?, name: String?, popularity: Int?, previewUrl: String?, thumbnailUrl: String, title: String, trackId: String, trackNumber: Int?, type: String?, updatedAt: Date, updatedById: Int?, uri: String) {
        self.artistName = artistName
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.durationMs = durationMs
        self.explicit = explicit
        self.href = href
        self.id = id
        self.isLocal = isLocal
        self.name = name
        self.popularity = popularity
        self.previewUrl = previewUrl
        self.thumbnailUrl = thumbnailUrl
        self.title = title
        self.trackId = trackId
        self.trackNumber = trackNumber
        self.type = type
        self.updatedAt = updatedAt
        self.updatedById = updatedById
        self.uri = uri
    }
}

/// QueuedTrack
// MARK: - QueuedTrack
public struct QueuedTrack: Persisted, DataConvertible {
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let id: Int
    public let playEndedAt: Date?
    public let playStartedAt: Date?
    public let roomId: Int?
    public let roomtrackId: Int
    public let trackId: Int?
    public let updatedAt: Date
    public let updatedById: Int?

    public enum CodingKeys: String, CodingKey {
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case id = "id"
        case playEndedAt = "playEndedAt"
        case playStartedAt = "playStartedAt"
        case roomId = "roomId"
        case roomtrackId = "roomtrackId"
        case trackId = "trackId"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
    }

    public init(createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, id: Int, playEndedAt: Date?, playStartedAt: Date?, roomId: Int?, roomtrackId: Int, trackId: Int?, updatedAt: Date, updatedById: Int?) {
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.id = id
        self.playEndedAt = playEndedAt
        self.playStartedAt = playStartedAt
        self.roomId = roomId
        self.roomtrackId = roomtrackId
        self.trackId = trackId
        self.updatedAt = updatedAt
        self.updatedById = updatedById
    }
}

/// QueuedTrackVote
// MARK: - QueuedTrackVote
public struct QueuedTrackVote: Persisted, DataConvertible {
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let id: Int
    public let queuedTrackId: Int
    public let updatedAt: Date
    public let updatedById: Int?

    public enum CodingKeys: String, CodingKey {
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case id = "id"
        case queuedTrackId = "queuedTrackId"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
    }

    public init(createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, id: Int, queuedTrackId: Int, updatedAt: Date, updatedById: Int?) {
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.id = id
        self.queuedTrackId = queuedTrackId
        self.updatedAt = updatedAt
        self.updatedById = updatedById
    }
}

/// Session
// MARK: - Session
public struct Session: Persisted, DataConvertible {
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let id: Int
    public let token: String
    public let updatedAt: Date
    public let updatedById: Int?
    public let userId: Int

    public enum CodingKeys: String, CodingKey {
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case id = "id"
        case token = "token"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
        case userId = "userId"
    }

    public init(createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, id: Int, token: String, updatedAt: Date, updatedById: Int?, userId: Int) {
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.id = id
        self.token = token
        self.updatedAt = updatedAt
        self.updatedById = updatedById
        self.userId = userId
    }
}

/// User
// MARK: - User
public struct User: Persisted, DataConvertible {
    public let activatedAt: Date?
    public let createdAt: Date
    public let createdById: Int?
    public let deletedAt: Date?
    public let deletedById: Int?
    public let email: String
    public let id: Int
    public let name: String
    public let passwordHash: String
    public let updatedAt: Date
    public let updatedById: Int?

    public enum CodingKeys: String, CodingKey {
        case activatedAt = "activatedAt"
        case createdAt = "createdAt"
        case createdById = "createdById"
        case deletedAt = "deletedAt"
        case deletedById = "deletedById"
        case email = "email"
        case id = "id"
        case name = "name"
        case passwordHash = "passwordHash"
        case updatedAt = "updatedAt"
        case updatedById = "updatedById"
    }

    public init(activatedAt: Date?, createdAt: Date, createdById: Int?, deletedAt: Date?, deletedById: Int?, email: String, id: Int, name: String, passwordHash: String, updatedAt: Date, updatedById: Int?) {
        self.activatedAt = activatedAt
        self.createdAt = createdAt
        self.createdById = createdById
        self.deletedAt = deletedAt
        self.deletedById = deletedById
        self.email = email
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
        self.updatedAt = updatedAt
        self.updatedById = updatedById
    }
}
