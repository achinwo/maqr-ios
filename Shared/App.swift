//
//  App.swift
//  Joli
//
//  Created by Anthony Chinwo on 12/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import UIKit
import PartialSheet
import JoliCore
import JoliApi
import Promises
import Foundation

let spotifyDelegateInstance: SpotifyDelegate = SpotifyDelegate()

#if DEBUG
let TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGlAam9saW1jLmFwcCIsImNyZWF0ZWRBdCI6IjIwMjAtMDgtMjJUMTM6NDQ6NTUuODY2WiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.OhxodQ0Zl0E_k_Su8CDwSB2scqteqfmyfUSMHwlfN00"
#endif

@main
struct JoliApp: AppClip {
    
    @Namespace var namespace
    
    @State var currentUser: User? = SEED_DATA.users.first { $0.isOwnDevice }
    @State var currentPlayroom: Musicroom? = SEED_DATA.musicrooms.first
    
    var coordinator: AppCoordinator = AppCoordinator()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    let spotify = spotifyDelegateInstance
    
    var appState: AppState {
        return appDelegate.appState
    }
    
    var api: JoliApi {
        return appState.api
    }
    
    init() {
        UITableView.appearance().separatorStyle = .none
    }
    
    var contentView: some View {
        AppView2(playroom: self.$currentPlayroom, currentUser: self.$currentUser)
            .onAppear() {
                logger.debug("[Joli] setting coordinator animation namespace to \(namespace)")
                
                self.coordinator.namespace = namespace
                self.coordinator.api = api
                
                appState.api.authenticate(token: TOKEN)
                    .then() { auth in
                        //print("[LoggedIn] \(auth?.user)")
                        self.currentUser = auth?.user
                    }
            }
    }
}

extension JoliApp {
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active")
                appState.api.wsClient.connect() { connectionState in
                    self.appState.onServerConnectionStateChanged(connectionState)
                }
                
                if let _ = self.spotify.appRemote.connectionParameters.accessToken {
                    logger.debug("[SceneDelegate#sceneDidBecomeActive] connecting Spotify remote")
                    self.spotify.appRemote.connect()
                } else {
                    logger.debug("[SceneDelegate#sceneDidBecomeActive] connecting Spotify remote aborted...")
                }
            case .inactive:
                print("App became inactive")
                if self.spotify.appRemote.isConnected {
                    self.spotify.appRemote.disconnect()
                }
                appState.api.wsClient.disconnect()
                appDelegate.stopObservingVolumeChanges()
            case .background:
                print("App is running in the background")
            @unknown default:
                // Fallback for future cases
                print("Unknown scene phase: \(phase)")
        }
    }
    
    func onOpenUrl(url: URL){
        logger.info("[SceneDelegate] url: \(url)")
        
        if let redirectUrl = appState.resolveSpotifyRedirectUrl(url), let urlComp = URLComponents(url: redirectUrl, resolvingAgainstBaseURL: false) {
            appState.spotifyWebAuthorize(urlComp)
                .then() { auth in
                    logger.info("[SceneDelegate] spotify auth recieved: \(auth)")
                    self.spotify.appRemote.connectionParameters.accessToken = auth.accessToken
                    self.spotify.accessToken = auth.accessToken
                }
                .catch() { error in
                    logger.error("[SceneDelegate] spotify auth error: \(error)")
                }
            return
        }
        
        let parameters = self.spotify.appRemote.authorizationParameters(from: url)
        logger.info("[\(#function)] spotify auth params: \(String(describing: parameters))")
        if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            self.spotify.appRemote.connectionParameters.accessToken = access_token
            self.spotify.accessToken = access_token
        } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
            logger.debug("Spotify error:", error_description)
        }
    }
    
}
