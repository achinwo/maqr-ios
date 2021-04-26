//
//  ContentView.swift
//  JoliClip
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import JoliCore

//#if canImport(StoreKit)
//import StoreKit
//#endif

import Promises
import UIImageColors
import Combine

public struct PlayroomView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @Binding public var playroom: Playroom
    @Binding public var showRecommended: Bool
    @State public var authcallback: () -> Void
    
    @State private var votesByQueuedTrackId: [Int: Int] = [:]
    @State private var strip: PlayroomHeaderView.TrackStrip = (nil, nil, nil)
    @State private var tracks: [Playable] = []
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @State private var pendingAction: (() -> Void)? = nil
    
    public var contentView: some View {
        
        let binding = Binding<Playroom?>(){
            return self.playroom
        } set: { value in
            guard let value = value else { return }
            
            self.playroom = value
        }
                
        let header: PlayroomHeaderView = PlayroomHeaderView(
            playroom: binding,
            strip: $strip,
            preview: .constant(nil),
            tracks: $tracks,
            scrollProxy: $scrollProxy,
            isCloseable: .constant(false)
        )
        
        let installMessage = "Install the full experience for the ability to create your own playrooms and more"
        
        return ZStack(alignment: .top) {
            
            ScrollViewReader(){ scrollProxy in
                ScrollView(){
                    VStack(){
                        
                        HStack(){
                            Text(installMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondaryLabel)
                                .lineLimit(5)
                            Spacer()
                            Button(){
                                self.showRecommended.toggle()
                            } label: {
                                Text("Get ") + Text("\(Strings.appSymbol.stringValue)oli").fontWeight(.semibold)
                            }
                        }
                        .padding()
                        
                        TrackList(tracks: self.$tracks, playroom: binding, addonView: self.addonView)
                            .padding(.top, safeAreaInsets.top + Sizing.xxxLarge * 2)
                            .frame(width: screenWidth)
                            .id("tracks-list")
                        
                        Divider().padding(.vertical)
                        
                        HStack(){
                            Text(installMessage)
                                .lineLimit(5)
                                .font(.subheadline)
                                .foregroundColor(.secondaryLabel)
                            Spacer()
                            Button(){
                                self.showRecommended.toggle()
                            } label: {
                                Text("Get ") + Text("\(Strings.appSymbol.stringValue)oli").fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .padding(.bottom, safeAreaInsets.bottom)
                    }
                    .padding(.top, safeAreaInsets.top + Sizing.xxxLarge * 2)
                    .padding(.bottom, safeAreaInsets.bottom)
                }
                .onReceive(playroom.$votesByQueuedTrackId, assign: \.votesByQueuedTrackId, target: self)
                .onAppear(){
                    self.scrollProxy = scrollProxy
                    scrollProxy.scrollTo("tracks-list", anchor: .top)
                }
            }
            
            VStack(spacing: .zero){
                header
                    .padding(.horizontal, Sizing.small * 0.6)
                    .padding([.horizontal, .bottom], Sizing.small * 0.5)
                    .padding(.top, safeAreaInsets.top)
                    .background(Color.systemBackground.opacity(0.9))
                Spacer()
            }
            .frame(width: screenWidth)
        }
        .onReceive(playroom.$queue){ tracks in
            self.tracks = tracks
        }
        .onReceive(appCoordinator.$activeSessionToken) { token in
            guard let pending = self.pendingAction, token != nil else { return }
            pending()
        }
        .onReceive(appCoordinator.voteRequestedSubject) { requested in
            self.requestingVoteTrackId = requested
        }
        .onReceive(appCoordinator.voteCastSubject) { vote in
            self.voteCasted = vote
        }
        .onReceive(playroom.$strip, assign: \.strip, target: self)
    }
    
    @State var requestingVoteTrackId: Int? = nil
    @State var voteCasted: QueuedTrackVote? = nil
    
    func addonView(track: Playable, playStates: [PlayState], colors: UIImageColors?) -> some View {
        
        return Group() {
            if let track = track as? QueuedTrack {
                
                let scaleX: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                let scaleY: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                
                let heart: Binding<Hearts?> = Binding() { () -> Hearts? in
                    
                    guard let count: Int = self.votesByQueuedTrackId[track.id] else {
                        return Hearts(score: HeartLevel.empty.rawValue)
                    }
                    
                    return Hearts(score: CGFloat(count) * HeartLevel.quarter.rawValue)
                    
                } set: { (heart, trasacton) in
                    
                }
                
                JoyMeterView(heart, textStyle: UIFont.TextStyle.title2, backgroundColor: Color.systemRed.opacity(0.5))
                    .padding()
                    .padding(.trailing, Sizing.medium)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .modifier(ShakeEffect(shakes: self.appCoordinator.insufficientPointsAttempt * 2))
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                    .onReceive(appCoordinator.voteCastSubject) { vote in
                        self.voteCasted = vote
                    }
                    .onTapGesture {
                        guard self.appCoordinator.voteRequestedSubject.value == nil else {
                            return
                        }
                        
                        let performVote = { () -> Void in
                            
                            self.appCoordinator.voteTrack(track)
                                .then() { vote in
                                    guard let currentCount = self.votesByQueuedTrackId[track.id] else { return }
                                    
                                    var votes = self.votesByQueuedTrackId
                                    votes[track.id] = currentCount + 1
                                    
                                    self.votesByQueuedTrackId = votes
                                }
                                .catch() { voteError in
                                    
                                    guard let error = voteError as? AppCoordinator.ActionError else {
                                        print("[ListenView] unrecognised error: \(voteError)")
                                        return
                                    }
                                    
                                    switch error {
                                        case .insufficientHeartPoints:
                                            self.appCoordinator.insufficientPointsAttempt += 1
                                    }
                                }
                        }
                        
                        guard appCoordinator.authorizedSpotify != nil else {
                            let message = "Voting requires a verified identity, sign in with Spotify?"
                            appCoordinator.withAlert("Sign-In Required", message: message, label: "Sign In") {
                                self.pendingAction = {
                                    performVote()
                                    self.pendingAction = nil
                                }
                                authcallback()
                            }
                            return
                        }
                        
                        performVote()
                    }
            }
        }
    }
    
}


struct ContentView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Binding var playroom: Playroom?
    @Binding var currentUser: User?
    
    @State var errorMessage: String? = nil
    @State var scrollProxy: ScrollViewProxy? = nil
    
    let websocket: Socket
    
    @State var loadingView = false
    
    @State var filterText: String = ""
    @State var preview: AppPreview? = nil
    @State var tabbarExpaned = false
    
    @State var currentLocation: AppLocation = .home
    
    @State var strip: PlayroomHeaderView.TrackStrip = (nil, nil, nil)
    @State var requestingVoteTrackId: Int? = nil
    @State var votesByTrack: [Int: [QueuedTrackVote]] = [:]
    @State var voteCasted: QueuedTrackVote? = nil
    @State var votes: [QueuedTrackVote] = []
    @Binding var showRecommended: Bool
    
    @State var tracks: [Playable] = []
    
    @State var tracksFiltered: [Playable] = []
    public var localPlaybackController: PlaybackControllerType
    
    public init(playroom: Binding<Playroom?>, currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType, showRecommended: Binding<Bool>){
        self._playroom = playroom
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
        self._showRecommended = showRecommended
    }
    
    var refreskButton: some View {
        Button() {
            
            guard case let .invited(inviteId) = self.currentLocation else {
                return
            }
            
            self.fetchPlayroomByInviteId(inviteId)
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
    
    var contentView: some View {
        //        NavigationView() {
        //
        //                    ScrollViewReader() { scrollProxy in
        //                        ScrollView(.vertical, showsIndicators: true) {
        
        
        return VStack(alignment: .center, spacing: .zero){
            if loadingView {
                ProgressView("Loading Playroom").padding()
            } else if let error = errorMessage {
                Text(error).font(Font.title.weight(.light)).padding()
                refreskButton//.padding(.top, UIScreen.main.bounds.height / 1.4)
            } else if let playroom = playroom {
                PlayroomView(playroom: .constant(playroom), showRecommended: $showRecommended) {
                        localPlaybackController.authorize(token: nil)
                    }
                    .background(Color.systemBackground)
                    .frame(width: screenWidth)
                    .id(playroom.name)
            } else {
                Text(Self.GENERIC_ERROR_MESSAGE).font(Font.title.weight(.light)).padding()
                refreskButton//.padding(.top, UIScreen.main.bounds.height / 1.4)
            }
        }
        .edgesIgnoringSafeArea([.top, .bottom])
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
        .onAppear() {
            //self.scrollProxy = scrollProxy
            
            if appCoordinator.currentLocation == .home {
                self.fetchPlayroomByInviteId("mnsv9A")
            }
        }
        .onReceive(appCoordinator.$currentLocation, assign: \.currentLocation, target: self)
        .onChange(of: currentLocation) { location in
            print("LOACTION Changed: \(location)")
            switch location {
                case .invited(let inviteId):
                    self.fetchPlayroomByInviteId(inviteId)
                //case .error:
                 //   self.errorMessage = Self.GENERIC_ERROR_MESSAGE
                default:
                    self.fetchPlayroomByInviteId("mnsv9A") // Joli Live
            }
        }
    }
    
    static var GENERIC_ERROR_MESSAGE: String {
        return "An error occured while loading your Playroom invitation, please try again later."
    }
    
    @discardableResult
    func fetchPlayroomByInviteId(_ inviteId: String) -> Promise<Entitlement> {
        
        
        let url = "/i/\(inviteId)"
        self.loadingView = true
        return HttpMethod.Fetch.get(url: url, dataType: Entitlement.self, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            .then(){ entitlement -> Entitlement in
                
                self.errorMessage = nil
                guard let musicroom = entitlement.musicroom else {
                    return entitlement
                }
                
                let play = Playroom(musicroom: musicroom, socket: websocket, api: api)
                self.playroom = play
                play.updateQueuedTracks()
                    .then(){ _ in
                        play.fetchSpotifyTopArtists()
                            .then(){ artists in
                                let filtered = artists.filter() { $0.imageMedium != nil }
                                play.artists = filtered
                            }
                            .catch(self.appCoordinator.globalErrorHandler())
                    }
                
                return entitlement
            }
            .catch() { error in
                print("[fetchPlayroomByInviteId] error: \(error)")
                self.errorMessage = Self.GENERIC_ERROR_MESSAGE
            }
            .always {
                self.loadingView = false
            }
        
    }
    
    private func filterTracks(_ tracks: [Playable], _ q: String) -> [Playable] {
        
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !query.isEmpty else {
            return tracks
        }
        
        return self.tracks.filter() { track in
            
            for fld in [track.artistName, track.title,] {
                if fld.lowercased().contains(query) {
                    return true
                }
            }
            
            return false
        }
    }
}


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
