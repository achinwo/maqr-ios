//
//  JoliClipApp.swift
//  JoliClip
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import JoliCore
import CancellationToken
import Combine
import JoliApi

@main
struct JoliClip: AppClip {
    
    @Namespace var namespace {
        didSet {
            logger.debug("[Joli] setting coordinator animation namespace to \(namespace)")
            coordinator.namespace = namespace
        }
    }
    
    
    var coordinator: AppCoordinator
    
    var websocket: Socket
    
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(key: .authToken, store: .groupContainer) var authToken: String = .empty
    
    @AppStorage(key: .location, store: .groupContainer) var currentLocation: AppLocation = .home {
        didSet {
            logger.debug("[\(Self.self)] \(currentLocation)")
        }
    }
    
    @State var filterText: String = ""
    @State var preview: AppPreview? = nil
    @State var tabbarExpaned = false
    
    var contentView: some View {
        ContentView(websocket: websocket, tabbarExpaned: $tabbarExpaned, preview: $preview, filterText: $filterText)
    }
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        let url = JoliApi.Environment.current.baseUrl.ws //URL(string: "https://192.168.1.173:8080/ws")!
        
        print("[URL] \(JoliApi.Environment.current.baseUrl)")
        
        let headers: [String: String] = [
            "X-PLATFORM": "ios",
            "X-DEVICE-UUID": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "X-DEVICE-MODEL": UIDevice.current.model,
            "X-DEVICE-NAME": UIDevice.current.name,
        ]
        
        let api = JoliApi(baseUrl: JoliApi.Environment.current.baseUrl, headers: headers)
        
        self.websocket = Socket(url: url.appendingPathComponent("/ws")) { (socket, connected) in
            
            guard connected else { return }
            
            socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_NOW_PLAYING"]) { error in
                print("[App] updated subscriptions: PLAYER_STATE_NOW_PLAYING - \(String(describing: error))")
            }
        }
        
        let pub: PlayState.Publisher = self.websocket
            .deserialize(PlayState.self)
            .autoconnect()
            .multicast() {
                return PassthroughSubject<PlayState, SocketError>()
            }
            .autoconnect()
            .eraseToAnyPublisher()
        
        let votesPubs: QueuedTrackVote.Publisher = self.websocket
            .deserialize(QueuedTrackVote.self)
            .autoconnect()
            .multicast() {
                return PassthroughSubject<QueuedTrackVote, SocketError>()
            }
            .autoconnect()
            .eraseToAnyPublisher()
        
        self.coordinator = AppCoordinator(pub, votesPubs)
        self.coordinator.api = api
    }
    
    func onUserActivity(_ activity: NSUserActivity) -> Void {
        self.coordinator.currentLocation = AppLocation(activity) ?? .home
        
        logger.debug("[\(Self.self)] onUserActivity: \(self.coordinator.currentLocation)")
    }
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active")
            case .inactive:
                print("App became inactive")
            case .background:
                print("App is running in the background")
            @unknown default:
            // Fallback for future cases
                print("Unknown scene phase: \(phase)")
        }
    }
    
}
