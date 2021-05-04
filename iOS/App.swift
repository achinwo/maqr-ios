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
import KeychainAccess
import os
import MessageUI

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
    
    let keychain: Keychain = Keychain(service: "live.joli.session-token")
    
    @State var serverVersion: Version? = nil
    @State var alertInfo: Alert? = nil
    
    @AppStorage("spotify.devices.active") var activeDeviceId: String = .empty
    
    @Namespace var namespace
    
    @AppStorage(key: AppStorageKey.authToken, store: UserDefaults.groupContainer)
    var activeSessionIdFromAppclip: String = .empty
    
    @AppStorage(key: AppStorageKey.location, store: UserDefaults.groupContainer)
    var activeLocationFromAppclip: AppLocation = .unset
    
    @AppStorage(key: AppStorageKey.location, store: .standard)
    var currentLocation: AppLocation = .unset {
        didSet {
            print("[\(Self.self)] Setting current location: \(currentLocation)")
        }
    }
    
    @AppStorage("active-session-id") var activeSessionId: String = .empty
    
    @State var activeSessionToken: String? {
        willSet {
            guard let activeSessionToken = newValue else {
                logger.info("[App#activeSessionToken] activeSessionToken is empty!")
                activeSessionId = .empty
                return
            }
            
            activeSessionId = activeSessionToken
            logger.info("[App#activeSessionToken] setting activeSessionToken: \(activeSessionId)")
        }
        
        didSet {
            logger.info("[App#activeSessionToken] auth field: \(String(describing: activeSessionToken))")
            
            self.devices = []
            //self.currentPlayroom = nil
            self.activeDeviceId = .empty
            
            let auth = self.auths.first() { $0.session.token == activeSessionToken }
            
            var newReq = Self.wssUrlRequest
            newReq.addValue(activeSessionToken ?? "", forHTTPHeaderField: "X-SESSION-ID")
            self.websocket.request = newReq
            
            self.coordinator.activeSessionToken = activeSessionToken
            self.currentUser = auth?.user
            
            guard let user = auth?.user else {
                self.coordinator.userHeartsSubject.send(nil)
                return
            }
            
            let points = CGFloat(user.heartPoints ?? 375)
            self.coordinator.userHeartsSubject.send(Hearts(score: points <= HeartLevel.empty.rawValue ? HeartLevel.quarter.rawValue : points))
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
    
    let spotify: SpotifyDelegate
    var websocket: Socket
    var cancellables: Set<AnyCancellable> = []
    
    @State var devices: [Spotify.Device] = []
    
    var api: JoliApi
    
    static let jsonDecoder = Musicroom.jsonDecoder()
    static let jsonEncoder = Musicroom.jsonEncoder()
    
    @State var authPublishCancel: AnyCancellable? = nil
    
    @Environment(\.scenePhase) var scenePhase
    @State var isSheetPresented: Bool = false
    @State var modalView: AppPreview? = nil
    @State var window: UIWindow?
    @State var appleSignInDelegates: SignInWithAppleDelegates? = nil
    @State var safeAreaInsets: EdgeInsets = EdgeInsets()
    
    let apnTokenPublisher: NotificationCenter.Publisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
    
    
    init() {
        
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        UITableView.appearance().separatorStyle = .none
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let baseUrls = JoliApi.Environment.current.baseUrl
         
        self.spotify = SpotifyDelegate(authCallbackUrl: baseUrls.http.appendingPathComponent("spotify_callback/"),
                                       authRefreshUrl: baseUrls.http.appendingPathComponent("spotify_refresh/"))
        
        
        var request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        
        self.api = JoliApi(baseUrl: baseUrls, headers: request.allHTTPHeaderFields ?? [:])
        
        let appclipsSessionId = self.activeSessionIdFromAppclip.isEmpty ? nil : self.activeSessionIdFromAppclip
        let location = self.activeLocationFromAppclip
        let currentLocation = self.currentLocation
        
        logger.debug("[\(Self.self)] initializing: appclipsSessionId=\(String(describing: appclipsSessionId)), appclipsLocation=\(location), currentLocation=\(currentLocation)")
        
        if self.currentLocation == .unset, location != .unset {
            self._currentLocation = AppStorage(wrappedValue: location, key: AppStorageKey.location, store: .standard)
        }
        
        self._auths = State(initialValue: Self.resolveAuths(keychain))
        
        let sessionId = self.activeSessionId.isEmpty ? nil : self.activeSessionId
        
        self._activeSessionToken = State(initialValue: sessionId ?? appclipsSessionId)
        
        api.urlSessionConfiguration = api.urlSessionConfiguration.withAuthHeader(self.activeSessionToken)
        
        coordinator.api = self.api
        
        if let token = self.activeSessionToken {
            request.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
        }
        
        self.websocket.request = request
        
        self.websocket.onConnect = { (socket, connected) in
            coordinator.onConnectionStateChange(connected ? .connected : .stopped)
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
    
    func onLocalSpotifyAuth(_ auth: AuthToken?, _ error: Error?){
        logger.info("[AppView#onLocalSpotifyAuth] auth: \(String(describing: auth)), error: \(String(describing: error))")
        coordinator.authorizedSpotify = auth
        
        guard let auth = auth else {
            return
        }
        
        self.authenticate(.spotifyRefreshToken(auth.refreshToken))
    }
    
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
    
    var auth: Auth? {
        return auths.first() { $0.session.token == activeSessionToken }
    }
    
    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State var mailOptions: MailView.Options? = nil
    @State var isActionSheetPresented: Bool = false
    
    func signOut(_ auth: Auth) -> Void {
        let newAuths = self.auths.filter() { $0.session.token != auth.session.token}
        self.auths = newAuths
        
        self.activeSessionToken = nil
        try? keychain.remove(auth.user.email)
        
        storeToKeychain(newAuths)
        
        self.coordinator.serverLogDestination?.send(.info, msg: "signedout: \(auth)", thread: Thread.current.description, file: #file, function: #function, line: #line)
        
        if auth.session.token == activeSessionIdFromAppclip {
            self.activeSessionIdFromAppclip = .empty
        }
        
        logger.info("signedout: \(auth.user.name)")
    }
    
    public func pushLocationTo(_ room: Room) {
        guard let url = room.inviteUrl(for: currentUser, fallback: room.inviteUrl),
              let location = AppLocation.init(url),
              location != currentLocation
              else {
            return
        }
        
        self.currentLocation = location
    }
    
    var contentView: some View {

        AppView2(playroom: self.$currentPlayroom, currentUser: self.$currentUser, websocket: websocket, localPlaybackController: spotify)
            .background(
                Group(){
                    if let playroom = currentPlayroom {
                        Spacer()
                            .onReceive(playroom.$entitlements){ entitlements in
                                pushLocationTo(playroom)
                            }
                    }
                }
                .opacity(.zero)
            )
            .sheet(isPresented: $isSheetPresented){
                self.modalView = nil
                self.mailOptions = nil
            } content: {
                
                if let opts = self.mailOptions {
                    MailView(result: $result, subject: opts.subject, recipients: opts.recipients, body: opts.body)
                } else {
                    GeometryReader() { proxy in
                        AppPreviewView(preview: self.$modalView, currentUser: self.$currentUser, animation: namespace)
                            .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom)
                            .animation(.spring())
                            .edgesIgnoringSafeArea([.bottom])
                        //.background(Color.yellow)
                    }
                    .environmentObject(coordinator)
                }
            }
            .alert(isPresented: self.$isActionSheetPresented) {
                guard let alert = self.alertInfo else {
                    return Alert(title: Text("Oops - Something is quite right"),
                                 message: Text("An internal error was detected. Restart the application if issue persists"),
                                 dismissButton: .default(Text("Dismiss")))
                }
                
                return alert
            }
            .onChange(of: self.modalView) { modal in
                isSheetPresented = self.modalView != nil
            }
            .onChange(of: self.currentPlayroom) { room in
                guard room == nil else {
                    return
                }
                
                self.currentLocation = currentLocation == .unset ? activeLocationFromAppclip : .home
            }
            .onChange(of: self.mailOptions) { opts in
                isSheetPresented = self.mailOptions != nil
            }
            .onReceive(coordinator.internalErrorSubject, perform: self.onInternalError)
            .onReceive(coordinator.signoutSubject, perform: self.signOut)
            .onReceive(spotify.authPublisher) { authRecord in
                logger.info("[\(#function)] local spotify auth: \(String(describing: authRecord))")
                authRecord?.save()
                    .then(){ auth in
                        self.onLocalSpotifyAuth(auth, nil)
                    }
                    .catch() { error in
                        self.onLocalSpotifyAuth(nil, error)
                    }
                
            }
            .onReceive(coordinator.$localPlaybackConnectRequest) { promise in
                logger.info("[\(#function)] localPlaybackConnectRequest: \(String(describing: promise))")
                
                guard promise != nil else { return }
                spotify.requestSpotifyAccess()
            }
            .onReceive(coordinator.$spotifyAuthRequestedAt) { requestedAt in
                
                guard requestedAt != nil else {
                    return
                }
                
                self.spotify.requestSpotifyAccess()
            }
            .onReceive(coordinator.globalModalSubject) { view in
                self.modalView = view
            }
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
            .onReceive(coordinator.$mailOptions) { opts in
                
                guard let opts = opts else {
                    self.mailOptions = nil
                    return
                }
                
                guard MFMailComposeViewController.canSendMail() else {
                    
                    if let encoded = opts.subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                        let validUrl = URL(string: "mailto:\(Strings.appSupportEmail)?subject=\(encoded)") {
                        UIApplication.shared.open(validUrl)
                    } else {
                        coordinator.serverLogDestination?.send(.error, msg: "[\(Self.self)] unable to send mail: subject=\(opts.subject)",
                                                               thread: Thread.current.debugDescription, file: #file, function: #function, line: #line)
                    }
                    
                    return
                }
                
                self.mailOptions = opts
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
                
                guard token != activeSessionToken else {
                    print("[AppView] token unchanged: \(token)")
                    return
                }
                
                self.activeSessionToken = token
                api.auth = self.auth
                
                DispatchQueue.main.async {
                    self.fetchSpotifyAuthToken()
                        .then() { authToken in
                            self.coordinator.authorizedSpotify = authToken
                        }
                        .catch(self.coordinator.globalErrorHandler())
                }
            }
            .onReceive(self.coordinator.$authorizedSpotify) { authToken in
                
                guard let authToken = authToken else { return }
                
                self.spotify.accessToken = authToken.accessToken
                print("[AppView] requesting spotify remote connect: \(authToken.accessToken)")
                self.spotify.remoteConnect(token: authToken.accessToken)
                
                DispatchQueue.main.async {
                    coordinator.refreshDevices()
                }
            }
            //.onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onAppear() {
                self.currentLocation = currentLocation != .unset ? currentLocation : .home
                
                self.coordinator.currentLocation = currentLocation
                self.coordinator.namespace = namespace
                self.coordinator.initialActiveDeviceId = activeDeviceId == .empty ? nil : activeDeviceId
                
                self.coordinator.serverLogDestination = ServerDestination(url: api.baseUrlHttp, urlSession: api.urlSession)
                
                
                guard let token = TOKEN ?? activeSessionToken ?? self.auths.first?.session.token else {
                    return
                }
                
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
        
    
    
}

extension JoliApp {
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active2 - \(String(describing: shortcutItemToProcess))")
                
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
                    
                    window?.rootViewController?.present(alertController, animated: true, completion: nil)
                    
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
        } else {
            self.coordinator.currentLocation = AppLocation(url) ?? self.coordinator.currentLocation
        }
    }
    
}
