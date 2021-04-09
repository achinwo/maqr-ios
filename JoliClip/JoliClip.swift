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
//import os
import Version
import KeychainAccess

//internal let logger = Logger(subsystem: "com.jolimc.JoliClip", category: "global.invite.room")

@main
struct JoliClip: AppClip {
    
    @State var safeAreaInsets: EdgeInsets = EdgeInsets()
    @State var activeSessionToken: String?
    @State var auths: [Auth] = []
    
    let keychain: Keychain = Keychain(service: "live.joli.session-token")
    
    @State var serverVersion: Version? = nil
    @State var appleSignInDelegates: SignInWithAppleDelegates?
    let apnTokenPublisher: NotificationCenter.Publisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
    
    @Namespace var namespace {
        didSet {
            logger.debug("[Joli] setting coordinator animation namespace to \(String(describing: namespace))")
            coordinator.namespace = namespace
        }
    }
    
    var coordinator: AppCoordinator
    
    var websocket: Socket
    @State var window: UIWindow?
    
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(key: .authToken, store: .groupContainer) var authToken: String = .empty
    
    @AppStorage(key: .location, store: .groupContainer) var currentLocation: AppLocation = .home {
        didSet {
            logger.debug("[\(Self.self)] \(currentLocation)")
        }
    }
    
    @State var playroom: Playroom? = nil
    @State var currentUser: User? = nil
    let spotify = SpotifyDelegate()
    
    var contentView: some View {
        ContentView(playroom: self.$playroom, currentUser: self.$currentUser, websocket: websocket, localPlaybackController: spotify)
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//            .overlay(
//                GeometryReader() { proxy in
//                    VStack(){
//                        Spacer()
//                        HStack(){
//                            Spacer()
//                            SignInWithApple()
//                                .onTapGesture(perform: self.presentSignInWithApple)
//                                .padding()
//                                .frame(width: 280, height: 80)
//                            Spacer()
//                        }
//                        .padding()
//                        .background(Color.white.opacity(0.7))
//                    }
//                    .padding(.bottom, proxy.safeAreaInsets.bottom)
//                }
//                .ignoresSafeArea(.all, edges: .bottom)
//            )
            .onAppear() {
                self.coordinator.serverLogDestination = ServerDestination(url: api.baseUrlHttp, urlSession: api.urlSession)
            }
    }
    
    var api: JoliApi
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        let url = JoliApi.Environment.current.baseUrl.ws //URL(string: "https://192.168.1.173:8080/ws")!
        
        print("[URL] \(JoliApi.Environment.current.baseUrl)")
        
        api = JoliApi(baseUrl: JoliApi.Environment.current.baseUrl, headers: Self.defaultHeaders)
        
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
