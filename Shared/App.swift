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
import Combine

let spotifyDelegateInstance: SpotifyDelegate = SpotifyDelegate()

#if DEBUG
let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGlAam9saW1jLmFwcCIsImNyZWF0ZWRBdCI6IjIwMjAtMDgtMjJUMTM6NDQ6NTUuODY2WiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.OhxodQ0Zl0E_k_Su8CDwSB2scqteqfmyfUSMHwlfN00"
#else
let TOKEN: String? = nil
#endif


@main
struct JoliApp: AppClip {
    
    @Namespace var namespace
    
    @State var currentUser: User? = SEED_DATA.users.first { $0.isOwnDevice }
    @State var currentPlayroom: Musicroom? = nil//SEED_DATA.musicrooms.first
    
    var coordinator: AppCoordinator
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    let spotify = spotifyDelegateInstance
    var websocket: Socket
    var cancellables: Set<AnyCancellable> = []
    var playbackRefreshRate: TimeInterval = 0.15
    
    @AppStorage("spotify.devices.active") var activeDeviceId: String = .empty
    
    @State var activeDevice: Spotify.Device? = nil {
        didSet {
            guard let device = activeDevice else {
                return
            }
            
            activeDeviceId = device.id
            print("[activeDevice] updated preferred device: \(device.name)")
        }
    }
    
    @State var devices: [Spotify.Device] = []
    
    var appState: AppState {
        return appDelegate.appState
    }
    
    var api: JoliApi {
        return appState.api
    }
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        UITableView.appearance().separatorStyle = .none
        let url = JoliApi.Environment.current.baseUrl.ws //URL(string: "https://192.168.1.173:8080/ws")!
        
        
        self.websocket = Socket(url: url.appendingPathComponent("/ws"))
        
        let publisher = self.websocket.publish(PlayState.self, interval: playbackRefreshRate, path: \.progressMs, resolver: cb)
        
        self.coordinator = AppCoordinator(publisher)
        
        self.websocket.onConnect = self.onConnectionStateChanged
        
        websocket.connect()
    }
    
    let cb: Publishers.Smooth<PlayState.Publisher, String>.StateGetter = { (state, now) in
        
        guard let duration = state.durationMs, state.playingState == .playing else {
            return (id: state.trackUri, value: state.progressMs, duration: nil, idleTimeout: 5)
        }
        
        return (id: state.trackUri, value: state.progressMs, duration: TimeInterval(duration), idleTimeout: 5)
    }
    
    func onConnectionStateChanged(_ socket: Socket, _ connected: Bool){
        guard connected else {
            return
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_NOW_PLAYING"]) { error in
            print("[App] updated subscriptions: PLAYER_STATE_NOW_PLAYING - \(String(describing: error))")
            
            DispatchQueue.main.async {
                let publisher: PlayState.Publisher = self.websocket.publish(PlayState.self, interval: self.playbackRefreshRate, path: \.progressMs, resolver: cb)
                
                self.coordinator.playStatePublisher = publisher
            }
        }
    }
    
    var contentView: some View {
        
        AppView2(playroom: self.$currentPlayroom, currentUser: self.$currentUser, activeDevice: self.$activeDevice, devices: self.$devices)
            .onReceive(appDelegate.$shortcutItemToProcess) { _ in
                //print(appDelegate.shortcutItemType)
                //Do something here
                logger.debug("[Joli] shortcutItem change: \(String(describing: appDelegate.shortcutItemToProcess))")
            }
            .onChange(of: devices) { devices in
                
                let device = devices.first(where: { $0.isActive }) ?? devices.first(where: { $0.id == activeDeviceId }) ?? devices.first(where: { $0.type == .computer })
                
                guard let activeDevice = device ?? devices.last else {
                    return
                }
                
                self.activeDevice = activeDevice
            }
            .onAppear() {
                logger.debug("[Joli] setting coordinator animation namespace to \(namespace)")
                
                self.coordinator.namespace = namespace
                self.coordinator.api = api
                
                guard let token = TOKEN else {
                    return
                }
                
                appState.api.authenticate(token: token)
                    .then() { auth in
                        print("[LoggedIn] \(String(describing: auth?.user))")
                        self.currentUser = auth?.user
                        
                        api.fetchSpotifyDevices(on: DispatchQueue.global(qos: .userInitiated))
                            .catch(){ error in
                                logger.error("[App#fetchSpotifyDevices] error: \(error)")
                            }
                            .then(on: .main) { self.devices = $0 }
                    }
            }
    }
}

extension JoliApp {
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active2")
//                appState.api.wsClient.connect() { connectionState in
//                    self.appState.onServerConnectionStateChanged(connectionState)
//                }
                
                websocket.connect()
                print("[Reconnecting]")
                
                if let _ = self.spotify.appRemote.connectionParameters.accessToken {
                    logger.debug("[SceneDelegate#sceneDidBecomeActive] connecting Spotify remote")
                    self.spotify.appRemote.connect()
                } else {
                    logger.debug("[SceneDelegate#sceneDidBecomeActive] connecting Spotify remote aborted...")
                }
                
                if let shortcutItem = appDelegate.shortcutItemToProcess {
                    // In this sample an alert is being shown to indicate that the action has been triggered,
                    // but in real code the functionality for the quick action would be triggered.
                    var message = "\(shortcutItem.type) triggered"
                    if let name = shortcutItem.userInfo?["Name"] {
                        message += " for \(name)"
                    }
                    let alertController = UIAlertController(title: "Quick Action", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Close", style: .default, handler: nil))
                    appDelegate.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                    
                    // Reset the shortcut item so it's never processed twice.
                    appDelegate.shortcutItemToProcess = nil
                }
            case .inactive:
                print("App became inactive2")
                if self.spotify.appRemote.isConnected {
                    self.spotify.appRemote.disconnect()
                }
                //appState.api.wsClient.disconnect()
                appDelegate.stopObservingVolumeChanges()
                
                let application = UIApplication.shared
                application.shortcutItems = [
                    UIApplicationShortcutItem(type: "FavoriteAction",
                                             localizedTitle: "Explore",
                                             localizedSubtitle: "Listen",
                                             icon: UIApplicationShortcutIcon(type: .compose),
                                             userInfo: [:])
                ]
            case .background:
                print("App is running in the background")
                websocket.soc.disconnect()
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
