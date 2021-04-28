//
//  App.swift
//  Joli (macOS)
//
//  Created by Anthony Chinwo on 06/10/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import Combine
import JoliCore
import KeychainAccess
import Version

final class LocalPlaybackProxy: PlaybackController, ObservableObject {
    
    init() {
    }
    
    func checkInstalled() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error>(){ promise in
            promise(.success(false))
        }
        .eraseToAnyPublisher()
    }
    
    @Published var auth: AuthTokenRecord? = nil
    
    var authPublisher: Published<AuthTokenRecord?>.Publisher {
        return $auth
    }
    
    var pendingPlayRequest: PlayRequest? = nil
    
    @Published var metadata: PlaybackControllerMetadata = .init(id: "joli-proxy",
                                                                name: "Joli - Proxy",
                                                                logoImage: Images.joliIconRounded,
                                                                brandColor: Color.systemIndigo,
                                                                isInstalled: false,
                                                                connectionState: .stopped)
    
    var metadataPublisher: Published<PlaybackControllerMetadata>.Publisher {
        return $metadata
    }
    
    @Published var connectionState: ConnectionState = .stopped
    
    var connectionStatePublisher: Published<ConnectionState>.Publisher {
        return $connectionState
    }
    
    @Published var playbackState: PlaybackState? = nil
    
    var playbackStatePublisher: Published<PlaybackState?>.Publisher {
        return $playbackState
    }
    
    func play(_ track: Playable, positionMs: Int?, contextUri: String?, device: Spotify.Device?) -> Future<Any, Error> {
        return Future<Any, Error>(){ promise in
            promise(.success(false))
        }
    }
    
    func play(_ track: Playable, positionMs: Int?, contentOffset: ContentOffset?, completionHandler: (() -> Void)?) {
        
    }
    
    func authorize(token: String?) {
        
    }
    
    func connect() -> Cancellable {
        return AnyCancellable() {
            
        }
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, ConnectionState == S.Input {
        
    }
    
    
}

@main
struct JoliMacApp: AppClip {
    
    @Environment(\.scenePhase) var scenePhase: ScenePhase
    
    @Namespace var namespace: Namespace.ID
    
    @State var appleSignInDelegates: SignInWithAppleDelegates? = nil
    
    @State var serverVersion: Version? = nil
    
    var apnTokenPublisher: NotificationCenter.Publisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
    
    var websocket: Socket
    
    @State var window: UIWindow? = nil
    
    @State var safeAreaInsets: EdgeInsets = .init()
    
    var keychain: Keychain = Keychain(service: "live.joli.session-token")
    
    @State var auths: [Auth] = []
    
    
    let coordinator: AppCoordinator
    @State var activeSessionToken: String? = nil
    
    let playbackProxy = LocalPlaybackProxy()
    let api: JoliApi
    
    init() {
        
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let baseUrls = JoliApi.Environment.current.baseUrl
        
        
        var request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        
        self.api = JoliApi(baseUrl: baseUrls, headers: request.allHTTPHeaderFields ?? [:])
        
        
        self._auths = State(initialValue: Self.resolveAuths(keychain))
        
        api.urlSessionConfiguration = api.urlSessionConfiguration.withAuthHeader(self.activeSessionToken)
        
        coordinator.api = self.api
        
        if let token = self.activeSessionToken {
            request.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
        }
        
        self.websocket.request = request
        
        self.websocket.onConnect = { (socket, connected) in
            coordinator.onConnectionStateChange(connected ? .connected : .stopped)
        }
    }
    
    var contentView: some View {
        ListenView(tabbarExpaned: .constant(true),
                   preview: .constant(nil),
                   filterText: .constant(.empty),
                   animation: namespace,
                   playroom: .constant(nil),
                   currentUser: .constant(nil),
                   websocket: websocket)
            .frame(idealWidth: 400, idealHeight: 500)
    }
}

struct ContectView {
    
}
