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
import SwiftyBeaver
import AuthenticationServices
import Version

let spotifyDelegateInstance: SpotifyDelegate = SpotifyDelegate()
var notificationCenterCancel: AnyCancellable? = nil

//eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6Imhhd2FAZ21haWwubmV0IiwiY3JlYXRlZEF0IjoiMjAyMC0xMS0xMlQxOTowMTozMC4xNzVaIiwiZXhwaXJlc0luIjoxNDQwMDAwfQ.DVEEwDmG0pW9EBQwcdJGJvpqLfrhNJmbyRlq30Aar0o
#if DEBUG
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGlAam9saW1jLmFwcCIsImNyZWF0ZWRBdCI6IjIwMjAtMTAtMjhUMTU6MTQ6MzIuODgwWiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.CdMbtPMDYMWvnkZyJthTA_-LbR8V1wIZu8GAgZaZ7zk"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkyQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTEwLTI5VDE0OjA1OjE3LjkxOFoiLCJleHBpcmVzSW4iOjE0NDAwMDB9.pUfqJ22dsM-hLlYJA424EJQiTCi9VwGWz8DLWX4Zq44"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImFudGhvbnkuY2hpbndvQGdtYWlsLmNvbSIsImNyZWF0ZWRBdCI6IjIwMjAtMTItMDRUMjE6MjE6MzguNTk2WiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.8yXdJnJGrVG4gj99n7iZKlO1kw8YBEAl-Sc0L-P8Dj4"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkzQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTExLTAxVDIxOjQxOjU3Ljk2MloiLCJleHBpcmVzSW4iOjE0NDAwMDB9.5FiYrRI9a_QaBp1a46bRV5fZo-pH-L5bUNozGb-_k80"
let TOKEN: String? = nil // "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImhhbWluYXRhLmNhbWFyYUBnbWFpbC5jb20iLCJjcmVhdGVkQXQiOiIyMDIwLTExLTE5VDE5OjM0OjM0LjU4OVoiLCJleHBpcmVzSW4iOjE0NDAwMDB9._N7o8ytCuQpx4RCk4o-mfY99UmqElSRSkZ2goeIm1BE"
#else
let TOKEN: String? = nil //"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImhhbWluYXRhLmNhbWFyYUBnbWFpbC5jb20iLCJjcmVhdGVkQXQiOiIyMDIwLTExLTE5VDE5OjM0OjM0LjU4OVoiLCJleHBpcmVzSW4iOjE0NDAwMDB9._N7o8ytCuQpx4RCk4o-mfY99UmqElSRSkZ2goeIm1BE"
//let TOKEN: String? = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGkyQGpvbGltYy5hcHAiLCJjcmVhdGVkQXQiOiIyMDIwLTEwLTI5VDE0OjA1OjE3LjkxOFoiLCJleHBpcmVzSW4iOjE0NDAwMDB9.pUfqJ22dsM-hLlYJA424EJQiTCi9VwGWz8DLWX4Zq44"
#endif

@main
struct JoliApp: AppClip {
    
    @State var serverVersion: Version? = nil
    
    @AppStorage("spotify.devices.active") var activeDeviceId: String = .empty
    
    @Namespace var namespace
    
    @State var auth: Auth? = nil {
        didSet {
            
            logger.info("[App#auth] auth: \(String(describing: auth))")
            
            self.devices = []
            //self.currentPlayroom = nil
            self.activeDeviceId = .empty
            
            var newReq = Self.wssUrlRequest
            newReq.addValue(auth?.session.token ?? "", forHTTPHeaderField: "X-SESSION-ID")
            self.websocket.request = newReq
            
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
    
    @State var currentPlayroom: Playroom? = nil//SEED_DATA.musicrooms.first
    
    let coordinator: AppCoordinator
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let spotify = spotifyDelegateInstance
    var websocket: Socket
    var cancellables: Set<AnyCancellable> = []
    
    @State var devices: [Spotify.Device] = []
    
    var api: JoliApi
    
    let jsonDecoder = Musicroom.jsonDecoder()
    let jsonEncoder = Musicroom.jsonEncoder()
    
    @State var authPublishCancel: AnyCancellable? = nil
    
    @AppStorage("pendingLocalPlayUri") var pendingLocalPlayUri: String = .empty
    @AppStorage("pendingLocalPlayPosition") var pendingLocalPlayPosition: Int = -1
    
    let apnTokenPublisher: NotificationCenter.Publisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
    
    static var wssUrlRequest: URLRequest {
        let url = JoliApi.Environment.current.baseUrl.ws
        var request = URLRequest(url: url.appendingPathComponent("/ws"), cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5)
        request.allHTTPHeaderFields = Self.defaultHeaders
        return request
    }
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        UITableView.appearance().separatorStyle = .none
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
         
        var request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        self.api = JoliApi(baseUrl: JoliApi.Environment.current.baseUrl, headers: request.allHTTPHeaderFields ?? [:])
        api.urlSessionConfiguration = api.urlSessionConfiguration.withAuthHeader(activeSessionId)
        
        coordinator.api = self.api
        
        request.addValue(activeSessionId, forHTTPHeaderField: "X-SESSION-ID")
        self.websocket.request = request
        
        self.websocket.onConnect = { (socket, connected) in
            coordinator.onConnectionStateChange(connected ? .connected : .stopped)
        }
        
        print("[AppView.init] active token: \(activeSessionId)")
        
        spotifyDelegateInstance.playStateCallback = self.onLocalSpotifyPlayStateChanged
        spotifyDelegateInstance.authCallback = self.onLocalSpotifyAuth
        
        DispatchQueue.main.async {
            spotifyDelegateInstance.remoteConnect()
        }
        
        self.authPublishCancel = self.websocket.deserialize(AuthToken.self)
            .autoconnect()
            .sink() { completion in
                logger.info("[AppView#AuthToken] completion: \(String(describing: completion))")
            } receiveValue: { auth in
                logger.info("[AppView#AuthToken] auth: \(String(describing: auth))")
            }
        
    }
    
    func onInternalError(_ errorInfo: AppCoordinator.ErrorInfo) {
        logger.error("[\(Self.self)#onInternalError] error raised: \(errorInfo.error as NSObject) - \(errorInfo.function)")
        
        self.coordinator.serverLogDestination?.send(SwiftyBeaver.Level.error,
                                        msg: String(describing: errorInfo.error),
                                        thread: Thread.current.debugDescription,
                                        file: errorInfo.file,
                                        function: errorInfo.function,
                                        line: errorInfo.line)
    }
    
    func onLocalSpotifyPlayStateChanged(localPlayState: SPTAppRemotePlayerState) {
        logger.info("[AppView#onLocalPlayStateChanged] localPlayState: \(localPlayState.track.name) - \(pendingLocalPlayUri) - \(pendingLocalPlayPosition)")
        coordinator.playRequestedSubject.send(localPlayState.track.uri)
        coordinator.playRequestedSubject.send(nil)
        
        let clearPending = {
            self.pendingLocalPlayUri = .empty
            self.pendingLocalPlayPosition = -1
            logger.info("[AppView#onLocalPlayStateChanged] cleared pending")
        }
        
        guard !pendingLocalPlayUri.isEmpty, pendingLocalPlayUri == localPlayState.track.uri, pendingLocalPlayPosition >= 0 else {
            clearPending()
            return
        }
        
        print("[App#onLocalSpotifyPlayStateChanged] seek to \(pendingLocalPlayPosition)...")
        
        self.spotifyRemote?.playerAPI?.seek(toPosition: pendingLocalPlayPosition) { (res, error) in
            print("[App#onLocalSpotifyPlayStateChanged] seek to \(pendingLocalPlayPosition): \(String(describing: res)) - \(String(describing: error))")
        }
        
        clearPending()
    }
    
    func onLocalSpotifyAuth(_ auth: AuthToken?, _ error: Error?){
        logger.info("[AppView#onLocalSpotifyAuth] auth: \(String(describing: auth)), error: \(String(describing: error))")
        coordinator.authorizedSpotify = auth
        
        guard let auth = auth else {
            return
        }
        
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
        let mgr = spotifyDelegateInstance.requestSpotifyAccess(trackUri: uri)
        
        logger.debug("[authorizeSpotify] spotify authresult: \(mgr)")
    }
    
    // MARK: - authenticate
    func authenticate(_ credentials: JoliApi.AuthCredentials){
        
        if case let .sessionToken(token) = credentials, token.isEmpty {
            logger.error("[App#authentication] call aborted, empty token")
            return
        }
        
        api.authenticate(credentials)
            .then() { auth in
                
                guard let auth = auth else {
                    return
                }
                
                logger.debug("[App#authentication] creds: \(String(describing: credentials)), auth: \(String(describing: auth))")
                
                var newAuths = self.auths.filter() { $0.session.userId != auth.session.userId}
                newAuths.append(auth)
                
                let serialized = SerializedAuths(auths: newAuths.sorted(by: { $0.user.name < $1.user.name }),
                                                 createdBy: self.auth?.user.createdById,
                                                 updatedBy: self.auth?.user.updatedById)
                self.authsData = (try? jsonEncoder.encode(serialized)) ?? Data()
                
                api.auth = auth
                self.auth = auth
            }
            .catch() { error in
                logger.error("[App#authentication] creds: \(String(describing: credentials)), error: \(String(describing: error))")
                
                guard case let .sessionToken(token) = credentials, let error = error as? SpotifyError, error != SpotifyError.unathorized else { return }
                
                let serialized = SerializedAuths(auths: self.auths.filter() { $0.session.token != token}.sorted(by: { $0.user.name < $1.user.name }),
                                                 createdBy: self.auth?.user.createdById,
                                                 updatedBy: self.auth?.user.updatedById)
                
                self.authsData = (try? jsonEncoder.encode(serialized)) ?? Data()
            }
            .always {
                
                defer {
                    websocket.connect()
                }
                
                guard let token = self.auth?.session.token, !self.websocket.isConnected else { return }
                
                var req = Self.wssUrlRequest
                req.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
                websocket.request = req
            }
    }
    
    @Environment(\.scenePhase) var scenePhase
    @State var isSheetPresented: Bool = false
    @State var modalView: AppPreview? = nil
    @Environment(\.window) var window: UIWindow?
    
    
    private func checkAppleSignedIn() {
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: "currentUserIdentifier") { state, error in
            switch state {
                case .authorized:
                    logger.info("Credentials are valid.")
                    break
                case .revoked:
                    logger.info("Credential revoked, log them out")
                    break
                case .notFound:
                    logger.info("Credentials not found, show login UI")
                    break
                case .transferred:
                    logger.info("Credentials transferred")
                    break
                
                @unknown default:
                    logger.info("CredentialsL: unknown case \"\(String(describing: state))\"")
            }
        }
    }
    
    @State var appleSignInDelegates: SignInWithAppleDelegates? = nil
    
    var contentView: some View {

        AppView2(playroom: self.$currentPlayroom, currentUser: self.$currentUser, websocket: websocket)
//            .onReceive(appDelegate.$shortcutItemToProcess) { _ in
//                //print(appDelegate.shortcutItemType)
//                //Do something here
//                logger.debug("[Joli] shortcutItem change: \(String(describing: appDelegate.shortcutItemToProcess))")
//            }
//            .overlay(
//                GeometryReader() { proxy in
//                    VStack(){
//                        Spacer()
//                        HStack(){
//                            Spacer()
//                            SignInWithApple()
//                                .onTapGesture(perform: showAppleLogin)
//                                .padding()
//                                .frame(width: 280, height: 80)
//                            Spacer()
//                        }
//                        .padding()
//                        .background(Color.white)
//                    }
//                    .padding(.bottom, proxy.safeAreaInsets.bottom)
//                }
//                .ignoresSafeArea(.all, edges: .bottom)
//            )
            .sheet(isPresented: $isSheetPresented){
                print("[App] sheet dismissed")
                self.modalView = nil
            } content: {
                GeometryReader() { proxy in
                    AppPreviewView(preview: self.$modalView, currentUser: self.$currentUser, animation: namespace)
                        .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom)
                        .animation(.spring())
                        .edgesIgnoringSafeArea([.bottom])
                        //.background(Color.yellow)
                }
                .environmentObject(coordinator)
            }
            .onChange(of: self.modalView) { modal in
                isSheetPresented = modalView != nil
            }
            .onReceive(coordinator.internalErrorSubject, perform: self.onInternalError)
            .onReceive(coordinator.$spotifyAuthCallback) { callback in
                
                guard let callback = callback else {
                    return
                }
                
                self.authorizeSpotify()
                callback(nil)
            }
            .onReceive(coordinator.$spotifyAuthRequestedAt) { requestedAt in
                
                guard requestedAt != nil else {
                    return
                }
                
                spotifyDelegateInstance.requestSpotifyAccess()
            }
            .onReceive(coordinator.$localPlayRequested) { localRequest in
                logger.debug("[App#$localPlayRequested] FIRST - local play: \(String(describing: localRequest))")
                
                guard let localRequest = localRequest, let spotifyRemote = self.spotifyRemote else {
                    return
                }
                
                guard spotifyRemote.isConnected else {
                    
                    self.pendingLocalPlayUri = localRequest.track.uri
                    self.pendingLocalPlayPosition = localRequest.positionMs ?? -1
                    
                    print("[App#$localPlayRequested] set pending: \(self.pendingLocalPlayUri) - \(self.pendingLocalPlayPosition)")
                    
                    authorizeSpotify(uri: localRequest.track.uri)
                    return
                }
                
                let callback: SPTAppRemoteCallback = { (res, error) in
                    print("[App#$localPlayRequested] play: \(String(describing: res)) - \(String(describing: error))")
                    
                    guard let positionMs = localRequest.positionMs else {
                        return
                    }
                    
                    spotifyRemote.playerAPI?.seek(toPosition: positionMs) { (res, error) in
                        print("[App#$localPlayRequested] seek to \(positionMs): \(String(describing: res)) - \(String(describing: error))")
                    }
                }
                
                
                print("[App#$localPlayRequested] local play: \(localRequest)")
                if let contextUri = localRequest.contextUri {
                    spotifyRemote.contentAPI?.fetchContentItem(forURI: contextUri) { item, error in
                        print("[App#$localPlayRequested] local play playlsit: \(localRequest) --- \(String(describing: item)) --- \(String(describing: error))")
                    }
                    //playerApi.play(<#T##contentItem: SPTAppRemoteContentItem##SPTAppRemoteContentItem#>, skipToTrackIndex: <#T##Int#>, callback: <#T##SPTAppRemoteCallback?##SPTAppRemoteCallback?##(Any?, Error?) -> Void#>)
                    //playerApi.play(<#T##contentItem: SPTAppRemoteContentItem##SPTAppRemoteContentItem#>, callback: callback)
                } else {
                    spotifyRemote.playerAPI?.play(localRequest.track.uri, asRadio: true, callback: callback)
                }
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
            .onReceive(coordinator.$activeSessionToken) { token in // MARK: - $activeSessionToken
                
                guard let token = token else {
                    return
                }
                
                print("[AppView] received new session token: \(token)")
                
                guard token != activeSessionId else {
                    return
                }
                
                self.activeSessionId = token
                let auth = auths.first() { $0.session.token == token }
                
                api.auth = auth
                self.auth = auth
                
                DispatchQueue.main.async {
                    self.fetchSpotifyAuthToken()
                        .then() { authToken in
                            self.coordinator.authorizedSpotify = authToken
                        }
                }
            }
            .onReceive(self.coordinator.$authorizedSpotify) { authToken in
                spotifyDelegateInstance.accessToken = authToken?.accessToken
                spotifyDelegateInstance.remoteConnect(token: authToken?.accessToken)
                
                DispatchQueue.main.async {
                    coordinator.refreshDevices()
                }
            }
            .onAppear() {
                logger.debug("[Joli] setting coordinator animation namespace to \(String(describing: namespace)) - activeSessionId: \(activeSessionId)")
                
                self.coordinator.namespace = namespace
                self.coordinator.initialActiveDeviceId = activeDeviceId == .empty ? nil : activeDeviceId
                
                self.coordinator.serverLogDestination = ServerDestination(url: api.baseUrlHttp, urlSession: api.urlSession)
                
//                if let authsSerialized = try? jsonDecoder.decode(SerializedAuths.self, from: authsData) {
//                    print("[AUTHS] existing: \(authsSerialized)")
//                } else {
//                    print("[AUTHS] nothing to set!")
//                }
                let token = TOKEN ?? activeSessionId
                
                guard token != .empty else {
                    return
                }
                
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
        }
    }
    
}
