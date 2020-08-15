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

let spotifyDelegateInstance: SpotifyDelegate = SpotifyDelegate()

//struct Showerdoor<Content> : View where Content : View {
//    /// A kind of mobile view that can go into fullscreen by expanding sideways
//    let scrollProxy: ScrollViewProxy
//    let contentView: Content
//
//    init(_ proxy: ScrollViewProxy, @ViewBuilder content: () -> Content){
//        scrollProxy = proxy
//        contentView = content()
//    }
//
//    var body: some View {
//        return contentView
//    }
//}



struct AppView2: View {
    
    enum ScrollPosition: Equatable {
        case leadingEdge
        case trailingEdge
        case point(CGPoint)
    }
    
    static let viewIds: (explore: String, listen: String, notset: String) = ("views.explore", "views.listen", "views.none")
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var scrollPosition: ScrollPosition = .leadingEdge
    
    @State var isExpanded = false
    
    @State var heartLevel: JoyMeterView.HeartLevel = .full
    
    @AppStorage("selectedViewId") var selectedViewId: String = viewIds.notset
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var filterText = ""
    
    @Namespace var animation
    
    public init(){}
    
    var roomsView: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem()], spacing: 8, pinnedViews: [.sectionHeaders]) {
                Section(header: Text("Recent")) {
                    ForEach(0..<10) { i in
                        Text("Grid: \(i)").frame(width: 100, height: 100, alignment: .center).background(Color.gray).cornerRadius(10.0)
                    }
                }
                Section(header: Text("Trending")) {
                    ForEach(10..<20) { i in
                        Text("Grid: \(i)")
                            .frame(width: 100, height: 100, alignment: .center)
                            .background(Color.gray)
                            .cornerRadius(10.0)
                    }
                }
            }
        }
    }
    
    func exploreView(geoProxy: GeometryProxy) -> some View {
        ExploreView()
        .padding(.top, geoProxy.safeAreaInsets.top)
        .frame(maxWidth: screenWidth)
        .onChange(of: self.scrollPosition) { value in
            print("Scroll position: \(value), safeArea: \(geoProxy.safeAreaInsets.top)")
            switch value {
                case .leadingEdge:
                    self.selectedViewId = Self.viewIds.explore
                case .trailingEdge:
                    self.selectedViewId = Self.viewIds.listen
                default:
                    break
            }
        }
        .id(Self.viewIds.explore)
    }
    
    @State var filteredTracks: [Track] = SEED_DATA.tracks
    
    func listenView(geoProxy: GeometryProxy, scrollProxy: ScrollViewProxy) -> some View {
        
        
        return ZStack(){
            ScrollView(.vertical, showsIndicators: true) {
                TrackList(tracks: self.$filteredTracks)
                    .padding(.top, geoProxy.safeAreaInsets.top)
                    //.padding(.top, navbarViewBounds == nil ? .zero : navbarViewBounds!.height)
                    .padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds!.height)
            }
            .onChange(of: self.filterText) { term in
                let term = self.filterText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !self.filterText.isEmpty else {
                    self.filteredTracks = SEED_DATA.tracks
                    return
                }
                
                self.filteredTracks = SEED_DATA.tracks.filter() { track in
                    return track.artistName.lowercased().contains(term) || track.title.lowercased().contains(term)
                }
            }
            //
            .frame(maxWidth: screenWidth)
            
            VStack(spacing: .zero) {
                Spacer()
                Divider()
                PeopleGridView(SEED_DATA.users, isExpanded: $isExpanded, searchText: self.$filterText, preview: self.$preview)
                    .padding(.bottom, geoProxy.safeAreaInsets.bottom)
                    .frame(width: screenWidth)
                    .onFrameChange() { rect in
                        DispatchQueue.main.async {
                            self.peopleViewBounds = rect
                        }
                    }
                    .background(BlurView(.systemUltraThinMaterialLight))
                //Color.white.blur(radius: 20).opacity(0.9))
                //.anchorPreference(key: MyAnchorPreferenceKey.self, value: .bounds) { [MyAnchorPreferenceData(bounds: $0)] }
            }
            
            VStack(spacing: .zero) {
                HStack(spacing: .zero){
                    Spacer()
                    
//                    Button("Search") {
//                        withAnimation(){
//                            self.selectedViewId = Self.viewIds.explore
//                            scrollProxy.scrollTo(Self.viewIds.explore)
//                        }
//                    }
//                    .font(.title2)
//                    .padding()
                }
                .frame(width: screenWidth, height: geoProxy.safeAreaInsets.top)
                //.padding(.top, geoProxy.safeAreaInsets.top)
                .background(Color.white.opacity(0.70))
                .onFrameChange() { rect in
                    DispatchQueue.main.async {
                        self.navbarViewBounds = rect
                    }
                }
                //.offset(x: 0, y: -200)
                Divider()
                
                if let preview = self.preview {
                    
                    ZStack(){
                        
                        VStack(spacing: .zero){
                            Divider()
                            Spacer(minLength: .zero)
                            switch preview {
                            case .userProfile(let user):
                                UserProfileView2(user: user)
                                    .background(Color.clear)
                            case .view(let scrollAxis, let viewFunc):
                                ScrollView(scrollAxis ?? .vertical){
                                    viewFunc().clipped()
                                }
                            }
                            Spacer(minLength: .zero)
                            Divider()
                        }
                        
                        let largeTitleSize = UIFont.preferredFont(forTextStyle: .title1).pointSize
                        VStack(alignment: .trailing){
                            HStack(){
                                Spacer()
                                Image(systemName: "xmark")
                                    .font(Font.title.weight(.light))
                                    .foregroundColor(.gray)
                                    .opacity(0.9)
                                    .background(Circle()
                                                    .frame(width: largeTitleSize * 1.4, height: largeTitleSize * 1.6)
                                                    .foregroundColor(Colors.lightGray.opacity(0.8)))
                                    
                                    .padding([.top, .trailing], Sizing.medium)
                            }
                            .padding()
                            .onTapGesture() {
                                self.preview = nil
                            }
                            //.frame(maxWidth: Sizing.large, maxHeight: Sizing.large)
                            Spacer()
                        }
                    }
                    .matchedGeometryEffect(id: "peoplegrid", in: animation)
                    .frame(maxWidth: screenWidth)
                    .frame(minWidth: screenWidth, maxHeight: screenHeight)
                    .background(BlurView(.extraLight))
                    .padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                    .padding(.top, 1)
                    .animation(.spring())
                } else {
                    Spacer()
                }
            }
        }
        .id(Self.viewIds.listen)
    }
    
    @State var preview: AppPreview? = nil
    
    
    var body: some View {
        
        return GeometryReader() { geoProxy in
            ZStack(){
                ScrollViewReader() { (proxy: ScrollViewProxy) in
                    ScrollView(.horizontal, showsIndicators: false){
                        HStack(alignment: .top, spacing: .zero){
                            self.exploreView(geoProxy: geoProxy)
                            self.listenView(geoProxy: geoProxy, scrollProxy: proxy)
                        }
                        //.background(Images.joliIconRounded.image.blur(radius: screenWidth, opaque: true))
                        .onFrameChange(){ frame in
                            DispatchQueue.main.async {
                                switch (frame.origin.x, frame.origin.y) {
                                    case (0, _):
                                        self.scrollPosition = .leadingEdge
                                    case (self.screenWidth * -1 , _):
                                        self.scrollPosition = .trailingEdge
                                    default:
                                        self.scrollPosition = .point(frame.origin)
                                }
                            }
                        }
                    }
                    .onChange(of: self.selectedViewId) { value in
                        withAnimation(){
                            print("[AppView2] scrolling to: \(value)")
                            proxy.scrollTo(value)
                        }
                    }
                    .onAppear() {
                        
                        guard self.selectedViewId != Self.viewIds.notset else {
                            self.selectedViewId = Self.viewIds.listen
                            return
                        }
                        
                        withAnimation(){
                            proxy.scrollTo(self.selectedViewId)
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea([.top, .bottom])
        }
        .frame(minWidth: screenWidth)
        
        //.frame(width: screenWidth, height: screenHeight)
        //.background(Color.clear.blur(radius: 50, opaque: true))
    }
}

@main
struct JoliApp: AppClip {
    
    @Namespace var namespace {
        didSet {
            logger.debug("[Joli] setting coordinator animation namespace to \(namespace)")
            coordinator.namespace = namespace
        }
    }
    
    var coordinator: AppCoordinator = AppCoordinator()
    
    //AppClip
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    let spotify = spotifyDelegateInstance
    
    let sheetManager: PartialSheetManager = PartialSheetManager()
    
    var appState: AppState {
        return appDelegate.appState
    }
    
    init() {
        UITableView.appearance().separatorStyle = .none
    }
    
    var contentView: some View {
        AppView2()
            .environmentObject(self.sheetManager)
            .environmentObject(appState)
            .environmentObject(appState.currentlyPlaying)
            .environmentObject(appState.keyboardState)
            .environmentObject(appState.serverReconnectState)
    }
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active")
                appState.api.wsClient.connect() { connectionState in
                    self.appState.onServerConnectionStateChanged(connectionState)
                }
                
                if let _ = self.spotify.appRemote.connectionParameters.accessToken {
                    logger.debug("[SceneDelegate#sceneDidBecomeActive] connecting Spotify remote")
                    self.spotify.appRemote.connect()
                } else {
                    logger.debug("[SceneDelegate#sceneDidBecomeActive] connecting Spotify remote aborted...")
                }
            case .inactive:
                print("App became inactive")
                if self.spotify.appRemote.isConnected {
                    self.spotify.appRemote.disconnect()
                }
                appState.api.wsClient.disconnect()
                appDelegate.stopObservingVolumeChanges()
            case .background:
                print("App is running in the background")
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


class SpotifyDelegate: NSObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate, SPTSessionManagerDelegate {
    
    let SpotifyClientID = "e3966e30011d4895997ce89c797de5a5"
    let SpotifyRedirectURL = URL(string: "joli://spotify-callback/")!
    //URL(string: "spotify-ios-quick-start://spotify-login-callback")!
    
    lazy var configuration = SPTConfiguration(clientID: SpotifyClientID, redirectURL: SpotifyRedirectURL)
    
    let playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
    
    lazy var appRemote: SPTAppRemote = {
        
        self.configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        self.configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!
        
        let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    static private let kAccessTokenKey = "access-token-key"
    
    var accessToken = UserDefaults.standard.string(forKey: kAccessTokenKey) {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(accessToken, forKey: Self.kAccessTokenKey)
        }
    }
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        logger.debug("Spotify: created session \(session)")
        
        self.appRemote.connectionParameters.accessToken = session.accessToken
        self.appRemote.connect()
        
        let builder = Builder<AuthToken>.init(properties: [
            AuthToken.CodingKeys.accessToken: session.accessToken as AnyObject,
            AuthToken.CodingKeys.refreshToken: session.refreshToken as AnyObject,
            AuthToken.CodingKeys.scope: session.scope as AnyObject,
            AuthToken.CodingKeys.expiresIn: 3016 as AnyObject,
            AuthToken.CodingKeys.tokenType: "Bearer" as AnyObject,
        ])
        
        builder.save()
            .then(){ auth in
                logger.info("[\(#function)] AUth: \(auth)")
            }//.catch(appState.errorHandler())
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        logger.debug("Spotify: session failure \(error)")
    }
    
    func connect() {
        self.appRemote.authorizeAndPlayURI(self.playURI)
    }
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        logger.debug("Spotify connected!")
        //let playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
        //self.appRemote.authorizeAndPlayURI(playURI)
        
        self.appRemote.playerAPI?.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                logger.debug("Spotify: playstae subsrcibe error: \(error)")
                logger.debug(error.localizedDescription)
                return
            }
            
            logger.info("[PlayerState] \(String(describing: result))")
        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        logger.debug("Spotify: disconnected \(String(describing: error))")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        logger.debug("Spotify: failed: \(String(describing: error))")
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        logger.debug("player state changed")
        
        logger.debug("Track name: \(playerState.track.name) - \(playerState.contextTitle), \(playerState)")
    }
    
    lazy var spotifySessionManager: SPTSessionManager = {
        
        var configuration = SPTConfiguration(
            clientID: SpotifyClientID,
            redirectURL: SpotifyRedirectURL //URL(string: "joli://spotify-callback/")!
        )
        
        configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        //https://localhost:8080/spotify_callback/
        configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!
        
        configuration.playURI = nil
        
        return SPTSessionManager(configuration: configuration, delegate: self)
    }()
    
    lazy var isSpotifyAppInstalled = {
        return spotifySessionManager.isSpotifyAppInstalled
    }()
    
    func requestSpotifyAccess() {
        //"app-remote-control streaming user-modify-playback-state user-read-playback-state user-read-currently-playing user-read-birthdate user-read-email user-read-private"
        let requestedScopes: SPTScope = [
            .appRemoteControl,
            .streaming,
            .userModifyPlaybackState,
            .userReadPlaybackState,
            .userReadCurrentlyPlaying,
            .userReadBirthDate,
            .userReadEmail,
            .userReadRecentlyPlayed,
            .userReadPrivate,
            .playlistModifyPrivate,
            .playlistModifyPublic,
            .playlistReadPrivate
            
        ]
        self.spotifySessionManager.alwaysShowAuthorizationDialog = true
        //self.spotifySessionManager.
        self.spotifySessionManager.initiateSession(with: requestedScopes, options: .default)
    }
    
}
