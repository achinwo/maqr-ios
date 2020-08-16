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
    
    @State var heartLevel: HeartLevel = .full
    
    @AppStorage("selectedViewId") var selectedViewId: String = viewIds.notset
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var filterText = ""
    
    @Namespace var animation
    
    public init(){}
    
    @State var filteredTracks: [Track] = SEED_DATA.tracks
    
    @State var preview: AppPreview? = nil
    
    
    var body: some View {
        
        return GeometryReader() { geoProxy in
            ZStack(){
                ScrollViewReader() { (proxy: ScrollViewProxy) in
                    ScrollView(.horizontal, showsIndicators: false){
                        HStack(alignment: .top, spacing: .zero){
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
                            
                            
                            ListenView(geoProxy: geoProxy, tracks: self.$filteredTracks, tabbarExpaned: self.$isExpanded, preview: self.$preview, filterText: self.$filterText, animation: animation)
                                .frame(width: screenWidth)
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
                                .id(Self.viewIds.listen)
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
    }
}

@main
struct JoliApp: AppClip {
    
    @Namespace var namespace
    
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
            .onAppear() {
                logger.debug("[Joli] setting coordinator animation namespace to \(namespace)")
                coordinator.namespace = namespace
            }
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


