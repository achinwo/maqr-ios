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
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGlAam9saW1jLmFwcCIsImNyZWF0ZWRBdCI6IjIwMjAtMTAtMjhUMTU6MTQ6MzIuODgwWiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.CdMbtPMDYMWvnkZyJthTA_-LbR8V1wIZu8GAgZaZ7zk"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkyQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTEwLTI5VDE0OjA1OjE3LjkxOFoiLCJleHBpcmVzSW4iOjE0NDAwMDB9.pUfqJ22dsM-hLlYJA424EJQiTCi9VwGWz8DLWX4Zq44"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6InRjQGdtYWlsLm5ldCIsImNyZWF0ZWRBdCI6IjIwMjAtMTAtMzBUMTU6NDc6MTYuNzU5WiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0._ZUvHIetv4gDS7qYs6y65tIrEnj7Nkfs_BQGczOAf_k"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkzQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTExLTAxVDIxOjQxOjU3Ljk2MloiLCJleHBpcmVzSW4iOjE0NDAwMDB9.5FiYrRI9a_QaBp1a46bRV5fZo-pH-L5bUNozGb-_k80"
let TOKEN: String? = nil
#else
let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkyQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTEwLTI5VDE0OjA1OjE3LjkxOFoiLCJleHBpcmVzSW4iOjE0NDAwMDB9.pUfqJ22dsM-hLlYJA424EJQiTCi9VwGWz8DLWX4Zq44"
#endif


@main
struct JoliApp: AppClip {
    
    @AppStorage("spotify.devices.active") var activeDeviceId: String = .empty
    
    @Namespace var namespace
    
    @State var auth: Auth? = nil {
        didSet {
            
            self.devices = []
            self.currentPlayroom = nil
            self.activeDeviceId = .empty
            
            self.coordinator.activeSessionToken = auth?.session.token
            self.currentUser = auth?.user
            self.activeSessionId = auth?.session.token ?? .empty
            
            guard let user = auth?.user else {
                self.coordinator.userHeartsSubject.send(nil)
                return
            }
            
            let points = CGFloat(user.heartPoints ?? 375)
            self.coordinator.userHeartsSubject.send(Hearts(score: points <= HeartLevel.empty.rawValue ? HeartLevel.quarter.rawValue : points))
        }
    }
    
    @AppStorage("active-session-id") var activeSessionId: String = .empty
    @AppStorage("auths-data") var authsData: Data = Data() {
        didSet {
            
            guard let authsSerialized = try? jsonDecoder.decode(SerializedAuths.self, from: authsData), !self.authsData.isEmpty else {
                return
            }
            
            let auths = authsSerialized.auths
            self.auths = auths
            
            guard !activeSessionId.isEmpty else {
                self.auth = nil
                return
            }
            
            self.auth = auths.first() { $0.session.token == activeSessionId }
        }
    }
    
    @State var auths: [Auth] = [] {
        didSet {
            self.coordinator.authsSubject.send(auths)
        }
    }
    
    @State var currentUser: User? = nil
    
    @State var currentPlayroom: Musicroom? = nil//SEED_DATA.musicrooms.first
    
    let coordinator: AppCoordinator
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    let spotify = spotifyDelegateInstance
    var websocket: Socket
    var cancellables: Set<AnyCancellable> = []
    var playbackRefreshRate: TimeInterval = 0.15
    
    @State var devices: [Spotify.Device] = []
    
    var appState: AppState {
        return appDelegate.appState
    }
    
    var api: JoliApi {
        return appState.api
    }
    
    let jsonDecoder = Playroom.jsonDecoder()
    let jsonEncoder = Playroom.jsonEncoder()
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        UITableView.appearance().separatorStyle = .none
        let url = JoliApi.Environment.current.baseUrl.ws //URL(string: "https://192.168.1.173:8080/ws")!
        
        
        self.websocket = Socket(url: url.appendingPathComponent("/ws"))
        
        let publisher = self.websocket.publish(PlayState.self, interval: playbackRefreshRate, path: \.progressMs, resolver: cb)
        
        self.coordinator = AppCoordinator(publisher)
        
        self.websocket.onConnect = self.onConnectionStateChanged
        
        websocket.connect()
        
        print("[AppView.init] active token: \(activeSessionId)")
    }
    
    struct SerializedAuths: Codable {
        var auths: [Auth]
        var createdBy: Int?
        var updatedBy: Int?
        var version: String? = nil
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
    }
    
    let cb: Publishers.Smooth<PlayState.Publisher, String>.StateGetter = { (state, now) in
        
        let uid = state.trackUri == nil ? nil : state.trackUri! + state.id.description
        
        guard let duration = state.durationMs, state.playingState == .playing else {
            return (id: uid, value: state.progressMs, duration: nil, idleTimeout: 4)
        }
        
        return (id: uid, value: state.progressMs, duration: TimeInterval(duration), idleTimeout: 4)
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
        
        socket.write(topic: "/subscribe", body: ["subject": "database_updates"]) { error in
            print("[App] updated subscriptions: database_updates - \(String(describing: error))")
        }
    }
    
    var contentView: some View {

        AppView2(playroom: self.$currentPlayroom, currentUser: self.$currentUser)
//            .onReceive(appDelegate.$shortcutItemToProcess) { _ in
//                //print(appDelegate.shortcutItemType)
//                //Do something here
//                logger.debug("[Joli] shortcutItem change: \(String(describing: appDelegate.shortcutItemToProcess))")
//            }
            .onReceive(coordinator.activeDeviceSubject) { (device: Spotify.Device?) in
                
                guard let device = device else {
                    return
                }
                
                self.activeDeviceId = device.id
            }
            .onReceive(coordinator.$activeSessionToken) { token in
                
                print("[AppView] received new session token: \(token)")
                
                guard let token = token else {
                    return
                }
                
                guard token != activeSessionId else {
                    return
                }
                
                self.activeSessionId = token
                let auth = auths.first() { $0.session.token == token }
                
                appState.api.auth = auth
                self.auth = auth
            }
            .onAppear() {
                logger.debug("[Joli] setting coordinator animation namespace to \(namespace) - activeSessionId: \(activeSessionId)")
                
                self.coordinator.namespace = namespace
                self.coordinator.api = api
                self.coordinator.initialActiveDeviceId = activeDeviceId == .empty ? nil : activeDeviceId
                
//                if let authsSerialized = try? jsonDecoder.decode(SerializedAuths.self, from: authsData) {
//                    print("[AUTHS] existing: \(authsSerialized)")
//                } else {
//                    print("[AUTHS] nothing to set!")
//                }
                
                self.auths = self.authsData.isEmpty ? [] : (try? jsonDecoder.decode(SerializedAuths.self, from: authsData))?.auths ?? []
                
                guard let token = TOKEN else {
                    
                    let auth = auths.first() { $0.session.token == activeSessionId }
                    appState.api.auth = auth
                    self.auth = auth
                    
                    return
                }
                
                appState.api.authenticate(token: token)
                    .then() { auth in
                        appState.api.auth = auth
                        self.auth = auth
                        
                        guard let auth = auth, !auths.contains(where: { $0.session.token == auth.session.token }) else {
                            return
                        }
                        
                        var newAuths = self.auths
                        newAuths.append(auth)
                        
                        let serialized = SerializedAuths(auths: newAuths, createdBy: self.auth?.user.createdById, updatedBy: self.auth?.user.updatedById)
                        self.authsData = (try? jsonEncoder.encode(serialized)) ?? Data()
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
                
                if let shortcutItem = shortcutItemToProcess {
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
                    shortcutItemToProcess = nil
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
