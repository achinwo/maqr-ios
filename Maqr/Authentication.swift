//
//  Authentication.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/04/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import Foundation
import MaqrApi

//public let logger = Logger(subsystem: "com.smartstickr.Smartz", category: "global.client")

public protocol AppAuthentication: AppClip {
    
    //func authenticate(_ credentials: MaqrApi.AuthCredentials, alertOnFail: Bool) async -> Auth?
    
}

public extension AppAuthentication {
    
    @discardableResult
    @MainActor
    func authenticate(_ credentials: MaqrApi.AuthCredentials, alertOnFail: Bool) async -> Auth? {
        print("[authenticate] authenticating cred \(credentials)")
        
        
        do {
            let auth = try await coordinator.api.authenticate(credentials)
            
            guard let auth = auth else {
                return nil
            }
            
            var newAuths = self.auths.filter() { $0.session.userId != auth.session.userId}
            newAuths.append(auth)
            
            self.auths = newAuths
            
            self.activeSessionToken = auth.session.token
            
            storeToKeychain(newAuths)
            self.coordinator.api.auth = auth
            
            self.coordinator.authsSubject.send(newAuths)
            self.coordinator.activeSessionToken = self.activeSessionToken
            print("[authenticate] authenticated: \(auth)")
            
            return auth
        } catch {
            print("auth error: \(error)")
        }
        
        return nil
    }
    
}
