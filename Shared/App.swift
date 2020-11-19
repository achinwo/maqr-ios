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
//eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6Imhhd2FAZ21haWwubmV0IiwiY3JlYXRlZEF0IjoiMjAyMC0xMS0xMlQxOTowMTozMC4xNzVaIiwiZXhwaXJlc0luIjoxNDQwMDAwfQ.DVEEwDmG0pW9EBQwcdJGJvpqLfrhNJmbyRlq30Aar0o
#if DEBUG
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGlAam9saW1jLmFwcCIsImNyZWF0ZWRBdCI6IjIwMjAtMTAtMjhUMTU6MTQ6MzIuODgwWiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.CdMbtPMDYMWvnkZyJthTA_-LbR8V1wIZu8GAgZaZ7zk"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkyQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTEwLTI5VDE0OjA1OjE3LjkxOFoiLCJleHBpcmVzSW4iOjE0NDAwMDB9.pUfqJ22dsM-hLlYJA424EJQiTCi9VwGWz8DLWX4Zq44"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6InRjQGdtYWlsLm5ldCIsImNyZWF0ZWRBdCI6IjIwMjAtMTAtMzBUMTU6NDc6MTYuNzU5WiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0._ZUvHIetv4gDS7qYs6y65tIrEnj7Nkfs_BQGczOAf_k"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkzQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTExLTAxVDIxOjQxOjU3Ljk2MloiLCJleHBpcmVzSW4iOjE0NDAwMDB9.5FiYrRI9a_QaBp1a46bRV5fZo-pH-L5bUNozGb-_k80"
let TOKEN: String? = nil
#else
let TOKEN: String? = nil
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkyQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTEwLTI5VDE0OjA1OjE3LjkxOFoiLCJleHBpcmVzSW4iOjE0NDAwMDB9.pUfqJ22dsM-hLlYJA424EJQiTCi9VwGWz8DLWX4Zq44"
#endif


extension Array where Element == DispatchWorkItem {
    
    func cancelAll(){
        print("[App#DispatchWorkItems] cancelling \(self.count) items...")
        
        for item in self {
            item.cancel()
        }
    }
    
}

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
    
    @State var authPublishCancel: AnyCancellable? = nil
    
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
        
        spotifyDelegateInstance.playStateCallback = self.onLocalSpotifyPlayStateChanged
        spotifyDelegateInstance.authCallback = self.onLocalSpotifyAuth
        
        DispatchQueue.main.async {
            spotifyDelegateInstance.remoteConnect()
        }
        
        self.authPublishCancel = self.websocket.deserialize(AuthToken.self)
            .sink() { completion in
                print("[AppView#AuthToken] completion: \(completion)")
            } receiveValue: { auth in
                print("[AppView#AuthToken] auth: \(auth)")
            }
    }
    
    func onLocalSpotifyPlayStateChanged(localPlayState: SPTAppRemotePlayerState) {
        print("[AppView#onLocalPlayStateChanged] localPlayState: \(localPlayState.track.name)")
        coordinator.playRequestedSubject.send(true)
        coordinator.playRequestedSubject.send(false)
    }
    
    func onLocalSpotifyAuth(_ auth: AuthToken?, _ error: Error?){
        print("[AppView#onLocalSpotifyAuth] auth: \(String(describing: auth)), error: \(String(describing: error))")
        coordinator.authorizedSpotify = auth
        coordinator.refreshDevices()
        
        guard let auth = auth else {
            return
        }
        
        self.spotify.appRemote.connectionParameters.accessToken = auth.accessToken
        self.spotify.accessToken = auth.accessToken
        
        self.authenticate(.spotifyRefreshToken(auth.refreshToken))
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
    
    @State var reconnectingTasks: [DispatchWorkItem] = []
    
    func scheduleSocketReconnect(){
        
        guard reconnectingTasks.isEmpty && !self.websocket.isConnected && [.background, .active].contains(scenePhase) else {
            return
        }
        
        let maxDelay = 300000 // 5 minutes
        
        func getDelay(for n: Int) -> Int {
            let delay = Int(pow(2.0, Double(n))) * 1000
            let jitter = Int.random(in: 0...1000)
            return min(delay + jitter, maxDelay)
        }
        
        let now = Date()
        
        var attempt = 1
        var delay = getDelay(for: attempt)
        
        while delay < maxDelay {
            
            let thisAttempt = attempt
            
            print("[App#scheduleSocketReconnect] scheduling retry: \(attempt) - \(now.advanced(by: Double(delay) / 1000))")
            
            let workItem = DispatchWorkItem {
                // Your async code goes in here
                print("[App#scheduleSocketReconnect] triggered retry: \(thisAttempt) - \(Date())")
                
                guard !self.websocket.isConnected && [.background, .active].contains(scenePhase) else {
                    self.reconnectingTasks.cancelAll()
                    self.reconnectingTasks.removeAll()
                    return
                }
                
                self.websocket.connect()
                print("[App#scheduleSocketReconnect] connect called: \(thisAttempt)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: workItem)
            self.reconnectingTasks.append(workItem)
            
            attempt += 1
            delay = getDelay(for: attempt)
        }
        
    }
    
    func onConnectionStateChanged(_ socket: Socket, _ connected: Bool){
        print("[App#onConnectionStateChanged] connected: \(connected)")
        
        guard connected else {
            scheduleSocketReconnect()
            return
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_NOW_PLAYING"]) { error in
            print("[App] updated subscriptions: PLAYER_STATE_NOW_PLAYING - \(String(describing: error))")
            
            self.reconnectingTasks.cancelAll()
            self.reconnectingTasks.removeAll()
            
            DispatchQueue.main.async {
                let publisher: PlayState.Publisher = self.websocket.publish(PlayState.self, interval: self.playbackRefreshRate, path: \.progressMs, resolver: cb)
                
                self.coordinator.playStatePublisher = publisher
            }
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "database_updates"]) { error in
            print("[App] updated subscriptions: database_updates - \(String(describing: error))")
        }
    }
    
    func assertWebsocketConnected() {
        self.websocket.write(topic: "/status", body: [:]) { error in
            
            guard let error = error else {
                logger.info("[App] asserting websocket connected successful")
                return
            }
            
            logger.error("[App] asserting websocket connected: \(error)")
        }
    }
    
    
    var spotifyRemote: SPTAppRemote? {
        return spotifyDelegateInstance.appRemote
    }
    
    func authorizeSpotify(uri: String? = nil){
        
        guard let spotifyRemote = self.spotifyRemote, !spotifyRemote.isConnected else {
            logger.debug("[authorizeSpotify] spotify remote is not initialized")
            spotifyDelegateInstance.remoteConnect()
            return
        }
        
        //spotifyRemote.imageAPI
        let mgr = spotifyDelegateInstance.requestSpotifyAccess(uri: uri)
        
        logger.debug("[authorizeSpotify] spotify authresult: \(mgr)")
    }
    
    
    func authenticate(_ credentials: JoliApi.AuthCredentials){
        
        appState.api.authenticate(credentials)
            .then() { auth -> Promise<AuthToken?> in
                appState.api.auth = auth
                self.auth = auth
                
                guard let auth = auth else {
                    return Promise(nil)
                }
                
                var newAuths = self.auths.filter() { $0.session.userId != auth.session.userId}
                newAuths.append(auth)
                
                let serialized = SerializedAuths(auths: newAuths.sorted(by: { $0.user.name < $1.user.name }),
                                                 createdBy: self.auth?.user.createdById,
                                                 updatedBy: self.auth?.user.updatedById)
                self.authsData = (try? jsonEncoder.encode(serialized)) ?? Data()
                
                return self.fetchSpotifyAuthToken().then() { $0 }
            }
            .then() { authToken in
                self.coordinator.authorizedSpotify = authToken
            }
            .catch() { error in
                logger.error("[App#authentication] creds: \(credentials), error: \(error)")
                
                guard case let .sessionToken(token) = credentials else { return }
                
                let serialized = SerializedAuths(auths: self.auths.filter() { $0.session.token != token}.sorted(by: { $0.user.name < $1.user.name }),
                                                 createdBy: self.auth?.user.createdById,
                                                 updatedBy: self.auth?.user.updatedById)
                
                self.authsData = (try? jsonEncoder.encode(serialized)) ?? Data()
            }
    }
    
    @State var isSheetPresented: Bool = false
    @State var modalView: AppPreview? = nil {
        didSet {
            isSheetPresented = modalView != nil
        }
    }
    
    var contentView: some View {

        AppView2(playroom: self.$currentPlayroom, currentUser: self.$currentUser)
//            .onReceive(appDelegate.$shortcutItemToProcess) { _ in
//                //print(appDelegate.shortcutItemType)
//                //Do something here
//                logger.debug("[Joli] shortcutItem change: \(String(describing: appDelegate.shortcutItemToProcess))")
//            }
            .sheet(isPresented: $isSheetPresented){
                print("[App] sheet dismissed")
                self.modalView = nil
            } content: {
                GeometryReader() { proxy in
                    AppPreviewView(preview: self.$modalView, currentUser: self.$currentUser, animation: namespace)
                        .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom)
                        .animation(.spring())
                        .edgesIgnoringSafeArea(.bottom)
                        .background(Color.yellow)
                }
            }
            .onReceive(coordinator.$spotifyAuthCallback) { callback in
                
                guard let callback = callback else {
                    return
                }
                
                self.authorizeSpotify()
                callback(nil)
            }
            .onReceive(coordinator.$localPlayRequested) { localRequest in
                
                guard let localRequest = localRequest, let spotifyRemote = self.spotifyRemote else {
                    return
                }
                
                guard spotifyRemote.isConnected else {
                    authorizeSpotify(uri: localRequest.track.uri)
                    return
                }
                
                self.spotifyRemote?.playerAPI?.play(localRequest.track.uri, asRadio: true) { (res, error) in
                    print("[App#$localPlayRequested] play: \(res) - \(error)")
                }
                
                print("[App#$localPlayRequested] local play: \(localRequest)")
            }
            .onReceive(coordinator.globalModalSubject) { view in
                self.modalView = view
            }
            .onReceive(coordinator.activeDeviceSubject) { (device: Spotify.Device?) in
                
                guard let device = device else {
                    return
                }
                
                self.activeDeviceId = device.id
            }
            .onReceive(coordinator.voteRequestedSubject) { voting in
                guard voting != nil else { return }
                
                self.assertWebsocketConnected()
            }
            .onReceive(coordinator.playRequestedSubject) { playing in
                guard playing else { return }
                
                self.assertWebsocketConnected()
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
            .onReceive(self.coordinator.$authorizedSpotify) { authToken in
                spotifyDelegateInstance.accessToken = authToken?.accessToken
                spotifyDelegateInstance.remoteConnect(token: authToken?.accessToken)
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
                let token = TOKEN ?? activeSessionId
                
                self.auths = self.authsData.isEmpty ? [] : (try? jsonDecoder.decode(SerializedAuths.self, from: authsData))?.auths ?? []
                self.authenticate(.sessionToken(token))
            }
    }
    
    // MARK: - fetchSpotifyAuth
    public func fetchSpotifyAuthToken() -> Promise<AuthToken> {
        
        guard self.auth != nil else {
            return Promise<AuthToken>(SpotifyError.unathorized)
        }
        
        return HttpMethod.Fetch.post(url: "/api/spotify/auth", dataType: AuthToken.self,
                                     baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
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
                    self.onLocalSpotifyAuth(auth, nil)
                }
                .catch() { error in
                    logger.error("[SceneDelegate] spotify auth error: \(error)")
                    self.onLocalSpotifyAuth(nil, error)
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
