//
//  User.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore

enum DeviceUid {
    case unknown
    case uuid(UUID)
}

enum EmailAddress: Equatable {
    case unknown
    case email(String)
}

enum UserName {
    case unknown
    case name(String)
}

protocol UserIdentifiable {
    var displayName: UserName { get }
    var emailAddress: EmailAddress { get }
    var deviceUid: DeviceUid { get }
    var isAnonymous: Bool { get }
    var isOwnDevice: Bool { get }
}

extension UserIdentifiable {
    
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

protocol UserProtocol: UserIdentifiable {
    var emailApi: Any? { get }
    
}

protocol UserVerified: UserIdentifiable, Identifiable {
    var emailApi: Any { get }
}


extension Builder: UserIdentifiable where PersistedType == User {
    var displayName: UserName {
        guard let name = name else {
            return .unknown
        }
        
        return .name(name)
    }
    
    
    var emailAddress: EmailAddress {
        guard let email = self.email else {
            return .unknown
        }
        
        return .email(email)
    }
    
    var deviceUid: DeviceUid {
        return .unknown
    }
    
}

extension Builder: UserProtocol where PersistedType == User {
    
    var emailApi: Any? {
        return self.email as Any
    }
    
}


extension User: UserVerified {
    
    var displayName: UserName {
        return .name(name)
    }
    
    var emailAddress: EmailAddress {
        return .email(email)
    }
    
    var deviceUid: DeviceUid {
        return .unknown
    }
    
    var emailApi: Any {
        return self.email as Any
    }
    
}

var thing = SEED_DATA.users.first?.email
