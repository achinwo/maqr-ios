//
//  SignInWithApple.swift
//  Joli
//
//  Created by Anthony Chinwo on 20/02/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import AuthenticationServices

public final class SignInWithApple: UIViewRepresentable {
    
    public init() {}
    
    public func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        return ASAuthorizationAppleIDButton()
    }
    
    public func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
}

public class SignInWithAppleDelegates: NSObject {
    
    private let signInSucceeded: (Bool) -> Void
    private weak var window: UIWindow!
    
    public init(window: UIWindow?, onSignedIn: @escaping (Bool) -> Void) {
        self.window = window
        self.signInSucceeded = onSignedIn
    }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerDelegate {
    
    private func registerNewAccount(credential: ASAuthorizationAppleIDCredential) {
        // 1
        //        let userData = UserData(email: credential.email!,
        //                                name: credential.fullName!,
        //                                identifier: credential.user)
        //
        //        // 2
        //        let keychain = UserDataKeychain()
        print("[SignInWithAppleDelegates] recieved new credentials: \(credential)")
//        do {
//            //try keychain.store(userData)
//        } catch {
//            self.signInSucceeded(false)
//        }
//
//        // 3
//        do {
//            //            let success = try WebApi.Register(
//            //                user: userData,
//            //                identityToken: credential.identityToken,
//            //                authorizationCode: credential.authorizationCode
//            //            )
//            //self.signInSucceeded(success)
//        } catch {
//            self.signInSucceeded(false)
//        }
    }
    
    private func signInWithExistingAccount(credential: ASAuthorizationAppleIDCredential) {
        // You *should* have a fully registered account here.  If you get back an error
        // from your server that the account doesn't exist, you can look in the keychain
        // for the credentials and rerun setup
        
        // if (WebAPI.login(credential.user,
        //                  credential.identityToken,
        //                  credential.authorizationCode)) {
        //   ...
        // }
        print("[SignInWithAppleDelegates] existing credentials: \(credential)")
        self.signInSucceeded(true)
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
        }
        
        
        
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logger.error("[SignInWithAppleDelegates] error: \(String(describing: error))")
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
