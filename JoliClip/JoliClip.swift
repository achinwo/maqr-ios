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
import Combine
import JoliApi
import SpotifyiOS
//import os
import Version
import KeychainAccess
import MessageUI

#if canImport(StoreKit)
import StoreKit
#endif

//internal let logger = Logger(subsystem: "com.jolimc.JoliClip", category: "global.invite.room")


struct LoadingView<Content>: View where Content: View {

    @Binding var isShowing: Bool
    var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {

                self.content()
                    .disabled(self.isShowing)
                    .blur(radius: self.isShowing ? 3 : 0)

                VStack {
                    Text("Loading...")
                    ProgressView().font(.largeTitle)
                }
                .frame(width: geometry.size.width / 2,
                       height: geometry.size.height / 5)
                .background(Color.secondary.colorInvert())
                .foregroundColor(Color.primary)
                .cornerRadius(20)
                .opacity(self.isShowing ? 1 : 0)

            }
        }
    }

}

@main
struct JoliClip: AppClip {
    
    @State var safeAreaInsets: EdgeInsets = EdgeInsets()
    
    @AppStorage(key: AppStorageKey.location, store: UserDefaults.groupContainer)
    var activeLocation: AppLocation = .home
    
    @AppStorage(key: AppStorageKey.authToken, store: UserDefaults.groupContainer)
    var activeSessionId: String = .empty
    
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
        }
    }
    
    @State var auths: [Auth] = []
    
    let keychain: Keychain = Keychain(service: "live.joli.session-token")
    
    @State var serverInfo: ServerInfo? = nil
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
    
    @AppStorage(key: .location, store: .groupContainer) var currentLocation: AppLocation = .home {
        didSet {
            logger.debug("[\(Self.self)] \(currentLocation)")
        }
    }
    
    @State var alertInfo: Alert? = nil
    @State var playroom: Playroom? = nil
    @State var currentUser: User? = nil
    let spotify: SpotifyDelegate
    
    @State var showRecommended = false
    
    var contentView: some View {
        ContentView(playroom: self.$playroom, currentUser: self.$currentUser, websocket: websocket, localPlaybackController: spotify, showRecommended: $showRecommended)
            .background(
                Group(){
                    #if canImport(StoreKit)
                    Spacer()
                        .appStoreOverlay(isPresented: $showRecommended) {
                            SKOverlay.AppConfiguration(appIdentifier: Strings.appId, position: .bottom)
                        }
                    #else
                    Spacer()
                    #endif
                }
            )
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
            .sheet(isPresented: self.$isPresentingSheet){
                print("[\(Self.self)] webview dismissed")
            } content: {
                NavigationView(){
                    
                    
                    LoadingView(isShowing: .constant(webViewStateModel.loading)) {
                        WebView(request: spotifyAuthUrl,
                                webViewStateModel: self.webViewStateModel,
                                onNavigationAction: self.onWebViewNavigation(_:))
                    }
                    .navigationTitle(webViewStateModel.pageTitle)
                }
                .edgesIgnoringSafeArea(.all)
            }
//            .onReceive(coordinator.$authorizedSpotify) { auth in
//                guard let auth = auth else { return }
//
//                self.spotify.accessToken = auth.accessToken
//                self.spotify.requestSpotifyAccess(trackUri: nil, token: auth.accessToken, alwaysShowAuthorizationDialog: false)
//            }
            .onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onReceive(coordinator.$activeSessionToken) { token in // MARK: - $activeSessionToken
                
                guard let token = token else {
                    return
                }
                
                print("[\(Self.self)] received new session token: \(token)")
                
                guard token != activeSessionToken else {
                    print("[\(Self.self)] token unchanged: \(token)")
                    return
                }
                
                self.activeSessionToken = token
                api.auth = self.auth
                    
                DispatchQueue.main.async {
                    Task() {
                        do {
                            let authToken = try await self.fetchSpotifyAuthToken()
                            self.coordinator.authorizedSpotify = authToken
                        } catch {
                            self.coordinator.globalErrorHandler()(error)
                        }
                    }
                }
            }
            .onReceive(coordinator.$localPlayRequested) { localRequest in
                
                guard let localRequest = localRequest else {
                    return
                }
                
//                guard spotify.appRemote.isConnected else {
//
//                }
                
                spotify.play(localRequest.track,
                                             positionMs: localRequest.positionMs,
                                             contentOffset: localRequest.contentOffset) {
                    logger.info("[\(Self.self)] local playback completed")
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
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
            .onReceive(coordinator.$spotifyAuthRequestedAt) { requestedAt in
                
                guard requestedAt != nil else {
                    return
                }
                
                self.spotify.authorize(token: coordinator.authorizedSpotify?.accessToken)
            }
            .onAppear() {
                
                self.websocket.connect()
                
                let auths = Self.resolveAuths(keychain)
                self.coordinator.authsSubject.send(auths)
                self.auths = auths
                
                let activeSession = self.activeSessionToken ?? auths.first?.session.token
                coordinator.activeSessionToken = activeSession
                
                self.coordinator.serverLogDestination = ServerDestination(url: api.baseUrlHttp, urlSession: api.urlSession)
                
                self.spotify.authorizationHandler = {
                    self.spotifyAuthHandler()
                }
                
                guard let session = activeSession else {
                    return
                }
                
                Task() { await authenticate(.sessionToken(session)) }
            }
    }
    
    @State var mailComposeResult: Result<MFMailComposeResult, Error>? = nil
    
    @State var modalItem: ModalCoordinator.Item? = nil
    @State var modalItemOnClose: ModalCoordinator.CloseCallback? = nil
    
    var modalItemBinding: Binding<ModalCoordinator.Item?> { $modalItem }
    
    @State var isActionSheetPresented = false
    
    var auth: Auth? {
        return auths.first() { $0.session.token == activeSessionToken }
    }
    
    public func fetchSpotifyAuthToken() async throws -> AuthToken {
        
        guard self.auth != nil else {
            throw SpotifyError.unathorized
        }
        
        return try await HttpMethod.Fetch.post(url: "/api/spotify/auth", dataType: AuthToken.self,
                                     baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
    }
    
    func modalView(_ item: ModalCoordinator.Item) -> some View {
        Group(){
            if case let .mailOptions(opts) = modalItem {
                MailView(result: self.$mailComposeResult, subject: opts.subject, recipients: opts.recipients, body: opts.body)
            } else if case let .view(view) = modalItem {
                GeometryReader() { proxy in
                    AppPreviewView(preview: .constant(view), currentUser: self.$currentUser, animation: namespace)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .animation(.spring())
                        //.background(Color.yellow)
                }
                .edgesIgnoringSafeArea(.all)
                .environmentObject(coordinator)
            }
        }
    }
    
    func onWebViewNavigation(_ navigationAction: WebView.NavigationAction) -> Void {
        switch navigationAction {
        case .decidePolicy(let action, let completionHandler):
            
            let redirect = api.baseUrlHttp.appendingPathComponent("spotify_callback/").absoluteString
            
            guard let url = action.request.url,
                  let redirectUrl = self.resolveSpotifyRedirectUrl(url, redirect: redirect, allowSchemes: ["https"]),
                  let urlComp = URLComponents(url: redirectUrl, resolvingAgainstBaseURL: false)
            else {
                completionHandler(.allow)
                return
            }
            
            Task() {
                do {
                    let auth = try await self.spotifyWebAuthorize(urlComp)
                    self.onLocalSpotifyAuth(auth, nil)
                } catch {
                    logger.error("[SceneDelegate] spotify auth error: \(String(describing: error))")
                    self.onLocalSpotifyAuth(nil, error)
                }
            }
        
            self.isPresentingSheet = false
            completionHandler(.cancel)
        case .didRecieveAuthChallange(let challenge, let completionHandler):
            #if DEBUG
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
            #else
            completionHandler(.performDefaultHandling, nil)
            #endif
            
        default:
            break
        }
    }
    
    @StateObject var webViewStateModel: WebViewStateModel = WebViewStateModel()
    var api: JoliApi
    @State var isPresentingSheet = false
    
    func spotifyAuthHandler() -> Void {
        
        guard activeSessionToken == nil else {
            let message = """
            Unable to connect with your local \(spotify.name).
            This could be an issue with this App Clip, try installing the full experience?
            """
            coordinator.withAlert("Something went wrong", message: message, label:  "Get \(Strings.appSymbol)oli") {
                showRecommended.toggle()
            }
            return
        }
        
        self.isPresentingSheet = true
        print("[\(Self.self)] authorizing Spotify: \(self.isPresentingSheet)")
    }
    
    var spotifyAuthUrl: URLRequest {
        let components = URLComponents(string: "/spotify_login")!
        let url = components.url(relativeTo: self.coordinator.api.baseUrlHttp)!
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        
        request.allHTTPHeaderFields = Self.defaultHeaders
        return request
    }
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        var request = Self.wssUrlRequest
        let baseUrls = JoliApi.Environment.current.baseUrl
         
        self.spotify = SpotifyDelegate(authCallbackUrl: baseUrls.http.appendingPathComponent("spotify_callback/"),
                                       authRefreshUrl: baseUrls.http.appendingPathComponent("spotify_refresh/"))
        
        api = JoliApi(baseUrl: JoliApi.Environment.current.baseUrl, headers: Self.defaultHeaders)
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        self.coordinator.api = api
        
        self.websocket = Socket(request: request)
        
        self.websocket.onConnect = { (socket, connected) in
            coordinator.onConnectionStateChange(connected ? .connected : .stopped)
        }
        
        let sessionId = self.activeSessionId.isEmpty ? nil : self.activeSessionId
        
        self._activeSessionToken = State(initialValue: sessionId)
        
        if let token = self.activeSessionToken {
            request.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
        }
        
    }
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active")
                websocket.connect()
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
        
        Task() { await self.authenticate(.spotifyRefreshToken(auth.refreshToken)) }
    }
    
    func spotifyWebAuthorize(_ urlPath: URLComponents) async throws -> AuthToken {
        //spotifyAuthorizationInProgress = true
        
        return try await HttpMethod.Fetch.get(url: urlPath,
                                    dataType: AuthToken.self,
                                    baseUrl: api.baseUrl.rawValue.http,
                                    urlSession: api.urlSession)
    }
    
    func resolveSpotifyRedirectUrl(_ url: URL, redirect: String? = nil, allowSchemes: [String] = []) -> URL? {
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let scheme = components?.scheme,
              let basePath = components?.host == api.baseUrlHttp.host ? components?.path : components?.host,
              let codeQuery = components?.queryItems?.first(where: { $0.name == "code" }),
              ([Strings.URL_SCHEME, "spotify-ios-quick-start"] + allowSchemes).contains(scheme),
              [Strings.SPOTIFY_URL_BASEPATH, "spotify-login-callback", "/spotify_callback/"].contains(basePath) else {
            return nil
        }
        
        var redirectUrl = URLComponents(string: "/spotify_callback")
        let redirectString: String
        
        if let redirect = redirect {
            redirectString = redirect
        } else {
            redirectString = scheme == Strings.URL_SCHEME ?
                "joli://\(Strings.SPOTIFY_URL_BASEPATH)"
                : "https://localhost:8080/spotify_callback/"
        }
        
        
        redirectUrl?.queryItems = [codeQuery,
                                   URLQueryItem(name: "redirect", value: redirectString),
                                   URLQueryItem(name: "platform", value: "ios")]
        
        #if APPCLIP
        redirectUrl?.queryItems?.append(URLQueryItem(name: "sku", value: "appclip"))
        #endif
        
        return redirectUrl?.url(relativeTo: api.baseUrl.rawValue.http)
    }
    
    func onOpenUrl(url: URL){
        logger.info("[SceneDelegate] url: \(url)")
        
        if let redirectUrl = resolveSpotifyRedirectUrl(url), let urlComp = URLComponents(url: redirectUrl, resolvingAgainstBaseURL: false) {
            
            Task() {
                do {
                    let auth = try await spotifyWebAuthorize(urlComp)
                    self.onLocalSpotifyAuth(auth, nil)
                } catch {
                    logger.error("[SceneDelegate] spotify auth error: \(String(describing: error))")
                    self.onLocalSpotifyAuth(nil, error)
                }
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
