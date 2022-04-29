//
//  Authentication.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/04/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import JoliApi
import UIKit
import Combine

public protocol AppAuthentication: AppClip {
    
    //func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool) async -> Auth?
    
}

public extension AppAuthentication {
    
    // MARK: - authenticate
    @discardableResult
    @MainActor
    func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool = true) async -> Auth? {
        
        defer {
            
            if let token = activeSessionToken, !self.websocket.isConnected {
                var req = Self.wssUrlRequest
                req.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
                websocket.request = req
                
                websocket.connect()
            }
            
        }
        
        if case let .sessionToken(token) = credentials, token.isEmpty {
            logger.error("[\(Self.self)#authentication] call aborted, empty token")
            return nil
        }
        
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
            
            let points = CGFloat(auth.user.heartPoints ?? 375)
            self.coordinator.userHeartsSubject.send(Hearts(score: points <= HeartLevel.empty.rawValue ? HeartLevel.quarter.rawValue : points))
            
                //logger.debug("[App#authentication] activeSessionToken: \(String(describing: self.activeSessionToken))")
            
            DispatchQueue.main.async { // Hack - authentication sideeffect needs refactoring
                if case .spotifyRefreshToken(_) = credentials, let pendingCallback = self.coordinator.pendingSpotifyAuthCallback.value {
                    pendingCallback(true)
                }
            }
            
            return auth
        } catch {
            logger.error("[App#authentication] creds: \(String(describing: credentials)), error: \(String(describing: error))")
            
            DispatchQueue.main.async { // Hack - authentication sideeffect needs refactoring
                if case .spotifyRefreshToken(_) = credentials, let pendingCallback = self.coordinator.pendingSpotifyAuthCallback.value {
                    pendingCallback(false)
                }
            }
            
            guard case let .sessionToken(token) = credentials, let error = error as? SpotifyError, error != SpotifyError.unathorized else {
                
                
                if alertOnFail {
                    let message = "If the issue persists, try closing and re-launching the app"
                    coordinator.withAlert("Unable to complete Sign In", message: message)
                }
                
                return nil
            }
            
            let auths = self.auths.filter() { $0.session.token != token}.sorted(by: { $0.user.name < $1.user.name })
            storeToKeychain(auths)
            
            return nil
        }
        
    }
    
}
