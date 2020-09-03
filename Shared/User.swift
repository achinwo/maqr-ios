//
//  User.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import UIKit

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
    
    var name: String? {
        guard case let .name(name) = self else {
            return nil
        }
        return name
    }
}

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

public extension UserIdentifiable {
    
    var isAnonymous: Bool {
        return emailAddress == .unknown
    }
    
    var isOwnDevice: Bool {
        guard case let DeviceUid.uuid(uid) = deviceUid, let currentUuid = UIDevice.current.identifierForVendor else {
            return false
        }
        return uid == currentUuid
    }
}

public protocol UserProtocol: UserIdentifiable {
    var emailApi: Any? { get }
}

public protocol UserVerified: UserIdentifiable, Identifiable {
    var emailApi: Any { get }
}

//@dynamicMemberLookup
public struct PlayroomMembership: UserIdentifiable {
    
    public enum InviteStatus {
        case pending
        case accepted
    }
    
    public enum ActivityStatus {
        case online
        case offline
    }
    
    
    public var inviteStatus: InviteStatus
    public var activityStatus: ActivityStatus
    
    public var playroomId: Int
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

var thing = SEED_DATA.users.first?.email
