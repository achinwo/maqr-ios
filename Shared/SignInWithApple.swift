//
//  SignInWithApple.swift
//  Joli
//
//  Created by Anthony Chinwo on 20/02/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import SwiftUI
import AuthenticationServices
import KeychainAccess
import MaqrApi

public struct SignInWithApple: UIViewRepresentable {
    
    public init() {}
    
    public func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        return ASAuthorizationAppleIDButton()
    }
    
    public func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
}

extension SignInWithApple {
    public func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        return ASAuthorizationAppleIDButton()
    }
    
    public func updateNSView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}


/// Represents the details about the user which were provided during initial registration.
struct UserData: Codable {
    /// The email address to use for user communications.  Remember it might be a relay!
    let email: String
    
    /// The components which make up the user's name.  See `displayName(style:)`
    let name: PersonNameComponents
    
    /// The team scoped identifier Apple provided to represent this user.
    let identifier: String
    
    /// Returns the localized name for the person
    /// - Parameter style: The `PersonNameComponentsFormatter.Style` to use for the display.
    func displayName(style: PersonNameComponentsFormatter.Style = .default) -> String {
        PersonNameComponentsFormatter.localizedString(from: name, style: style)
    }
}

public class SignInWithAppleDelegates: NSObject {
    
    private let signInSucceeded: (AppleAuthData?, Error?) -> Void
    private weak var window: UIWindow!
    private let keychain: Keychain
    
    public struct AppleAuthData {
        let user: UserData
        let identityToken: Data?
        let authorizationCode: Data?
    }
    
    public init(window: UIWindow?, keychain: Keychain, onSignedIn: @escaping (AppleAuthData?, Error?) -> Void) {
        self.window = window
        self.signInSucceeded = onSignedIn
        self.keychain = keychain
    }
    
}

public enum SignInWithAppleError: Error {
    case keychainPersist(Error)
    case keychainRetreive
    case unknownCredential(AnyObject)
}


extension SignInWithAppleDelegates: ASAuthorizationControllerDelegate {
    
    private func registerNewAccount(credential: ASAuthorizationAppleIDCredential) {
        let userData = UserData(email: credential.email!,
                                name: credential.fullName!,
                                identifier: credential.user)
        
        do {
            let data = try JSONCoding.encoder().encode(userData)
            try keychain.label("apple-signin").set(data, key: userData.identifier)
        } catch {
            self.signInSucceeded(nil, SignInWithAppleError.keychainPersist(error))
        }

        let success = AppleAuthData(
            user: userData,
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode
        )
        self.signInSucceeded(success, nil)
    }
    
    func retreiveUserDataStored(_ appleUserIdentifier: String) -> UserData? {
        let jsonDecoder = JSONCoding.decoder()
        let items = keychain.allKeys()
        
        for item in items {
            
            guard let attributes = try? keychain.get(item, handler: { $0 }),
                  let label = attributes.label,
                  let data = attributes.data,
                  let userData = try? jsonDecoder.decode(UserData.self, from: data),
                  label == "apple-signin",
                  userData.identifier == appleUserIdentifier else {
                continue
            }
            
            return userData
        }
        
        return nil
    }
    
    private func signInWithExistingAccount(credential: ASAuthorizationAppleIDCredential) {
        // You *should* have a fully registered account here.  If you get back an error
        // from your server that the account doesn't exist, you can look in the keychain
        // for the credentials and rerun setup
        
        guard let stored = retreiveUserDataStored(credential.user) else {
            self.signInSucceeded(nil, SignInWithAppleError.keychainRetreive)
            return
        }
        
        let success = AppleAuthData(
            user: stored,
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode
        )
        
        self.signInSucceeded(success, nil)
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
            case let appleIdCredential as ASAuthorizationAppleIDCredential:
                if let _ = appleIdCredential.email, let _ = appleIdCredential.fullName {
                    // 2
                    registerNewAccount(credential: appleIdCredential)
                } else {
                    // 3
                    signInWithExistingAccount(credential: appleIdCredential)
                }
            default:
                logger.error("Unknown Apple Auth creds: \(String(describing: authorization.credential))")
                self.signInSucceeded(nil, SignInWithAppleError.unknownCredential(authorization.credential))
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logger.error("[SignInWithAppleDelegates] error: \(String(describing: error))")
        self.signInSucceeded(nil, error)
    }
    
}

extension SignInWithAppleDelegates: ASAuthorizationControllerPresentationContextProviding {
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.window
    }
    
}

enum WindowKey: EnvironmentKey {
    static var defaultValue: UIWindow? {
        return nil
    }
}

extension EnvironmentValues {
    
    var window: UIWindow? {
        get {
            self[WindowKey.self]
        }
        set {
            self[WindowKey.self] = newValue
        }
    }
    
}
