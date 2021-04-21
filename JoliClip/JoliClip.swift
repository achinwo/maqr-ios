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
import Promises
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
    
    func onLocalSpotifyAuth(_ auth: AuthToken?, _ error: Error?){
        logger.info("[AppView#onLocalSpotifyAuth] auth: \(String(describing: auth)), error: \(String(describing: error))")
        coordinator.authorizedSpotify = auth
        
        guard let auth = auth else {
            return
        }
        
        self.authenticate(.spotifyRefreshToken(auth.refreshToken))
    }
    
    func spotifyWebAuthorize(_ urlPath: URLComponents) -> Promise<AuthToken> {
        //spotifyAuthorizationInProgress = true
        
        return HttpMethod.Fetch.get(url: urlPath,
                                    dataType: AuthToken.self,
                                    baseUrl: api.baseUrl.rawValue.http,
                                    urlSession: api.urlSession)
            .then(){ auth -> Promise<AuthToken> in
                //self.spotifyWebAuthorized = !auth.isExpired
                return Promise(auth)
            }
            .always() {
                //self.spotifyAuthorizationInProgress = false
            }
    }
    
    func resolveSpotifyRedirectUrl(_ url: URL) -> URL? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let scheme = components?.scheme,
              let basePath = components?.host,
              let codeQuery = components?.queryItems?.first(where: { $0.name == "code" }),
              [Strings.URL_SCHEME, "spotify-ios-quick-start"].contains(scheme),
              [Strings.SPOTIFY_URL_BASEPATH, "spotify-login-callback"].contains(basePath) else {
            return nil
        }
        
        var redirectUrl = URLComponents(string: "/spotify_callback")
        redirectUrl?.queryItems = [codeQuery,
                                   URLQueryItem(name: "redirect",
                                                value: (scheme == Strings.URL_SCHEME ?
                                                            "joli://\(Strings.SPOTIFY_URL_BASEPATH)"
                                                            : "https://localhost:8080/spotify_callback/"
                                                        //: "spotify-ios-quick-start://spotify-login-callback/"
                                                )),
                                   URLQueryItem(name: "platform", value: "ios")]
        
        return redirectUrl?.url(relativeTo: api.baseUrl.rawValue.http)
    }
    
    func onOpenUrl(url: URL){
        logger.info("[SceneDelegate] url: \(url)")
        
        if let redirectUrl = resolveSpotifyRedirectUrl(url), let urlComp = URLComponents(url: redirectUrl, resolvingAgainstBaseURL: false) {
            spotifyWebAuthorize(urlComp)
                .then() { auth in
                    //logger.info("[SceneDelegate] spotify auth recieved: \(auth)")
                    self.onLocalSpotifyAuth(auth, nil)
                }
                .catch() { error in
                    logger.error("[SceneDelegate] spotify auth error: \(String(describing: error))")
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
            logger.debug("Spotify error: \(error_description)")
        } else {
            self.coordinator.currentLocation = AppLocation(url) ?? self.coordinator.currentLocation
        }
    }
    
}
