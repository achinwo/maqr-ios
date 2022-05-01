//
//  User.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import AuthenticationServices
import SwiftUI

#if os(OSX)
import AppKit
#else
import UIKit
#endif

public struct PersonGenericImage: View {
    public var body: some View {
        return GeometryReader() { proxy in
            Image(systemName: "person.fill")
            .resizable()
                //.frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .foregroundColor(.gray)
            .background(Colors.lightGray.opacity(0.7))
                .offset(x: 0, y: proxy.size.height * 0.2)
            .background(Colors.lightGray.opacity(0.7))
        }
        .clipShape(Circle())
    }
}

public enum DeviceUid {
    case unknown
    case uuid(UUID)
    
    var uuid: UUID? {
        guard case let .uuid(uuid) = self else {
            return nil
        }
        return uuid
    }
}

public enum EmailAddress: Equatable {
    case unknown
    case email(String)
    
    var email: String? {
        guard case let .email(email) = self else {
            return nil
        }
        return email
    }
}

public enum UserName: Equatable {
    case unknown
    case name(String)
    
    public var name: String? {
        guard case let .name(name) = self else {
            return nil
        }
        return name
    }
}
//
//public enum ImageReference: Equatable, UrlConvertible {
//    case small(String)
//    case medium(String)
//    case large(String)
//
//    var fileName: String? {
//        switch self {
//        case .small(let fileName), .large(let fileName), .medium(let fileName):
//            return fileName
//        }
//    }
//
//    public func url(relativeTo: URL? = nil) -> URL? {
//        return self.fileName?.url(relativeTo: relativeTo)
//    }
//}

public protocol UserIdentifiable {
    var displayName: UserName { get }
    var emailAddress: EmailAddress { get }
    var deviceUid: DeviceUid { get }
    var isAnonymous: Bool { get }
    var isOwnDevice: Bool { get }
    var imageLarge: String? { get }
    var imageMedium: String? { get }
    var imageSmall: String? { get }
    
    var ranking: DiscjockeyPosition { get }
}

import CryptoKit

public extension String {
    
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
}

public extension UserIdentifiable {
    
    var isAnonymous: Bool {
        return emailAddress == .unknown
    }
    
    var isOwnDevice: Bool {
        #if os(macOS)
        return false
        #else
        guard case let DeviceUid.uuid(uid) = deviceUid, let currentUuid = UIDevice.current.identifierForVendor else {
            return false
        }
        return uid == currentUuid
        #endif
    }
    
    var gravatarUrl: URL? {
        
        guard case let EmailAddress.email(email) = emailAddress else {
            return nil
        }
        
        var baseUrl = URLComponents(string: "https://www.gravatar.com/avatar/\(email.md5)?s=512&r=g")
        
        let name = displayName.name ?? "Anonymous"
        let avatarUrl = URL(staticString: "https://ui-avatars.com/api/")
            .appendingPathComponent(name) // name
            .appendingPathComponent("512") // size
            .appendingPathComponent("f0e9e9") // background
            .appendingPathComponent("8b5d5d") // color
            .appendingPathComponent("2") // length
            .appendingPathComponent("0.6") // font-size
            .appendingPathComponent("true") // rounded
            .appendingPathComponent("true") // uppercase
            .appendingPathComponent("true") // bold
        
        baseUrl?.queryItems?.append(URLQueryItem(name: "d", value: avatarUrl.absoluteString))
        
        print("[gravatarUrl] url: \(String(describing: baseUrl?.url))")
        
        return baseUrl?.url
    }
}

public protocol UserProtocol: UserIdentifiable {
    var emailApi: Any? { get }
}

public protocol UserVerified: UserIdentifiable, Identifiable {
    var emailApi: Any { get }
}

//@dynamicMemberLookup
public struct PlayroomMembership: UserIdentifiable, Identifiable, Equatable, Hashable {
    
    public var id: String {
        return "membership:\(playroom.id)/\(user.id)"
    }
    
    public enum InviteStatus {
        case pending
        case accepted
    }
    
    public enum ActivityStatus: Int {
        case online = 1
        case offline = 0
    }
    
    public var inviteStatus: InviteStatus
    public var activityStatus: ActivityStatus
    
    public var playroom: Musicroom
    public var user: User
    public var membership: Membership = .inviteOnly
    
    public var displayName: UserName {
        return user.displayName
    }
    
    public var emailAddress: EmailAddress {
        return user.emailAddress
    }
    
    public var deviceUid: DeviceUid {
        return user.deviceUid
    }
    
    public var imageLarge: String? {
        return user.imageLarge
    }
    
    public var imageMedium: String? {
        return user.imageMedium
    }
    
    public var imageSmall: String? {
        return user.imageSmall
    }
    
    public var ranking: DiscjockeyPosition {
        return user.ranking
    }
    
//    subscript<T>(dynamicMember keyPath: KeyPath<User, T>) -> T {
//        get { user[keyPath: keyPath] }
//    }
}

extension Builder: UserIdentifiable where PersistedType == User {
    
    public var displayName: UserName {
        guard let name = name else {
            return .unknown
        }
        
        return .name(name)
    }
    
    
    public var emailAddress: EmailAddress {
        guard let email = self.email else {
            return .unknown
        }
        
        return .email(email)
    }
    
    public var deviceUid: DeviceUid {
        guard let deviceIdStr = self.activeDeviceUuid, let uuid = UUID.init(uuidString: deviceIdStr) else {
            return .unknown
        }
        
        return .uuid(uuid)
    }
    
}

extension Builder: UserProtocol where PersistedType == User {
    
    public var emailApi: Any? {
        return self.email as Any
    }
    
}


extension User: UserVerified {
    
    public var displayName: UserName {
        return .name(name)
    }
    
    public var emailAddress: EmailAddress {
        return .email(email)
    }
    
    public var deviceUid: DeviceUid {
        guard let deviceIdStr = self.activeDeviceUuid, let uuid = UUID.init(uuidString: deviceIdStr) else {
            return .unknown
        }
        
        return .uuid(uuid)
    }
    
    public var emailApi: Any {
        return self.email as Any
    }
    
}

public protocol Room {
    
    var musicroom: Musicroom { get }
    
    var inviteUrl: URL? { get }
    var baseUrl: URL? { get }
    
    func inviteUrl<U: UserIdentifiable & Identifiable>(for: U) -> URL? where U.ID == Int
    func inviteUrl<U: UserIdentifiable & Identifiable>(for: U?, fallback: URL?) -> URL? where U.ID == Int
    
    var themeAlbumIds: String?  { get }
    var themeArtistIds: String? { get }
    var themeGenreNames: String? { get }
    
    var uuid: String? { get }
    var createdByUser: User { get }
    var deletedAt: Date? { get }
    var deletedById: Int? { get }
    var deletedByUser: User? { get }
    var details: String { get }
    var entitlements: [Entitlement]? { get set }
    var imageLarge: String? { get }
    var imageMedium: String? { get }
    var imageSmall: String? { get }
    var membership: Membership { get }
    var name: String { get set }
    var playingState: PlayingState? { get }
    var playlistUri: String? { get }
    var progressMs: Int? { get }
    var snapshotId: String? { get }
    var themeTrackUri: String { get }
    var themeTrackUri2: String? { get }
    var trackUri: String? { get }
    var updatedAt: Date { get }
    var updatedById: Int { get }
    var updatedByUser: User? { get }
    
    var genres: [String] { get }
    
    var themeTracks: [Track] { get }
}

public extension Room {
    
    var themeTracks: [Track] {
        return []
    }
    
    var baseUrl: URL? {
        return nil
    }
    
    var inviteUrl: URL? {
        guard let uuid = uuid, let url = URL(string: uuid, relativeTo: baseUrl) else {
            return nil
        }
        return url
    }
    
    func inviteUrl<U: UserIdentifiable & Identifiable>(for user: U) -> URL? where U.ID == Int {
        
        let entitlement: Entitlement? = entitlements?.first() { $0.createdById == user.id }
        
        guard let uuid = entitlement?.uuid ?? uuid, let url = URL(string: "/i/\(uuid)", relativeTo: baseUrl) else {
            return nil
        }
        
        return url
    }
    
    func inviteUrl<U: UserIdentifiable & Identifiable>(for user: U?, fallback: URL?) -> URL? where U.ID == Int {
        
        guard let user = user else {
            return fallback
        }
        
        return inviteUrl(for: user)
    }
    
    var genres: [String] {
        guard let genreNames = themeGenreNames else { return [] }
        
        return Array(genreNames.split(separator: ",").map() {String($0)}) //?? []
    }
    
    var themeAlbumIds: String?  {
        musicroom.themeAlbumIds
    }
    
    var themeArtistIds: String? {
        musicroom.themeArtistIds
    }
    
    var themeGenreNames: String? {
        musicroom.themeGenreNames
    }
    
    var uuid: String? {
        return musicroom.uuid
    }
    
    var createdByUser: User {
        return musicroom.createdByUser
    }
    
    var deletedAt: Date? {
        return musicroom.deletedAt
    }
    
    var deletedById: Int? {
        return musicroom.deletedById
    }
    
    var deletedByUser: User? {
        return musicroom.deletedByUser
    }
    
    var details: String {
        return musicroom.details
    }
    
    var imageLarge: String? {
        return musicroom.imageLarge
    }
    
    var imageMedium: String? {
        return musicroom.imageMedium
    }
    
    var imageSmall: String? {
        return musicroom.imageSmall
    }
    
    var membership: Membership {
        return musicroom.membership
    }
    
    var playingState: PlayingState? {
        return musicroom.playingState
    }
    
    var playlistUri: String? {
        return musicroom.playlistUri
    }
    
    var progressMs: Int? {
        return musicroom.progressMs
    }
    
    var snapshotId: String? {
        return musicroom.snapshotId
    }
    
    var themeTrackUri: String {
        return musicroom.themeTrackUri
    }
    
    var themeTrackUri2: String? {
        return musicroom.themeTrackUri2
    }
    
    var trackUri: String? {
        return musicroom.trackUri
    }
    
    var updatedAt: Date {
        return musicroom.updatedAt
    }
    
    var updatedById: Int {
        return musicroom.updatedById
    }
    
    var updatedByUser: User? {
        return musicroom.updatedByUser
    }
    
}

extension Musicroom: Room {
    
    public var musicroom: Musicroom {
        return self
    }
    
}
