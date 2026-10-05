//
//  User.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import MaqrApi
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
public protocol UserIdentifiable {
    var displayName: UserName { get }
    var emailAddress: EmailAddress { get }
    var deviceUid: DeviceUid { get }
    var isAnonymous: Bool { get }
    var isOwnDevice: Bool { get }
    var imageLarge: String? { get }
    var imageMedium: String? { get }
    var imageSmall: String? { get }
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
