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

#if canImport(StoreKit)
import StoreKit
#endif

import Promises
import UIImageColors
import Combine

public struct PlayroomView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @Binding public var playroom: Playroom
    
    @State private var votes: [QueuedTrackVote] = []
    @State private var strip: PlayroomHeaderView.TrackStrip = (nil, nil, nil)
    @State private var tracks: [Playable] = []
    @State private var scrollProxy: ScrollViewProxy? = nil
    
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
            scrollProxy: $scrollProxy
        )
        
        return ZStack(alignment: .top) {
            
            ScrollViewReader(){ scrollProxy in
                ScrollView(){
                    TrackList(tracks: self.$tracks, votes: self.$votes, playroom: binding, addonView: self.addonView)
                        .padding(.top, safeAreaInsets.top)
                        .frame(width: screenWidth)
                }
                .onAppear(){
                    self.scrollProxy = scrollProxy
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
        .onReceive(playroom.$votes, assign: \.votes, target: self)
        .onReceive(playroom.$strip, assign: \.strip, target: self)
    }
    
    func addonView(track: Playable, playStates: [PlayState], colors: UIImageColors?) -> some View {
        var votesByTrack: [Int: [QueuedTrackVote]] = [:]
        
        for vote in votes {
            
            guard var existing = votesByTrack[vote.queuedTrackId] else {
                votesByTrack[vote.queuedTrackId] = []
                continue
            }
            
            existing.append(vote)
            votesByTrack[vote.queuedTrackId] = existing
        }
        
        return Group() {
            if let track = track as? QueuedTrack,
               let playlistUri = playroom.playlistUri,
               let playing = self.strip.playing as? QueuedTrack,
               playing.id == track.id,
               playing.isPlayable, track.isPlayable {
                
                Button() {
                    let state = playStates.first() { $0.email == playroom.createdByUser.email } ?? playStates.first
                    appCoordinator.play(track, positionMs: state?.progressMs, contextUri: playlistUri, device: appCoordinator.activeDeviceSubject.value)
                        .then() { state in
                            print("[ListenView] rejoining \(track.title) at \(String(describing: state?.progressMs)) - \(String(describing: state))")
                        }
                } label: {
                    Text("Rejoin").padding()
                }
                .buttonStyle(BlackWhiteButtonStyle(inverted: true))
                .font(.headline)
                .padding(.trailing, Sizing.medium)
                
            } else if let track = track as? QueuedTrack {
                
                let scaleX: CGFloat = 1 //self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                let scaleY: CGFloat = 1//self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                
                let heart: Binding<Hearts?> = Binding() { () -> Hearts? in
                    
                    guard let count: Int = votesByTrack[track.id]?.count else {
                        return Hearts(score: HeartLevel.empty.rawValue)
                    }
                    
                    return Hearts(score: CGFloat(count) * HeartLevel.quarter.rawValue)
                    
                } set: { (heart, trasacton) in
                    
                }
                
                JoyMeterView(heart, textStyle: UIFont.TextStyle.title2, backgroundColor: Color.systemRed.opacity(0.5))
                    .padding()
                    .padding(.trailing, Sizing.medium)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                    .onReceive(appCoordinator.voteCastSubject) { vote in
                        //self.voteCasted = vote
                    }
                    .onTapGesture {
                        guard self.appCoordinator.voteRequestedSubject.value == nil else {
                            return
                        }
                        
                        self.appCoordinator.voteTrack(track)
                            .then() { vote in
                                guard !self.votes.contains(vote) else { return }
                                self.votes.append(vote)
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
            }
        }
    }
    
}


struct ContentView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    @State var showRecommended = false
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Binding var playroom: Playroom?
    @Binding var currentUser: User?
    
    @State var errorMessage: String? = nil
    @State var playroomId: String? = nil
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
    
    @State var tracks: [Playable] = []
    
    @State var tracksFiltered: [Playable] = []
    public var localPlaybackController: PlaybackControllerType
    
    public init(playroom: Binding<Playroom?>, currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType){
        self._playroom = playroom
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
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
                PlayroomView(playroom: .constant(playroom))
                    .background(Color.systemBackground)
                    .frame(width: screenWidth)
                    .id(playroom.name)
                
                #if canImport(StoreKit)
                Spacer()
                    .appStoreOverlay(isPresented: $showRecommended) {
                        SKOverlay.AppConfiguration(appIdentifier: Strings.appId, position: .bottom)
                    }
                #endif
            } else {
                Text(Self.GENERIC_ERROR_MESSAGE).font(Font.title.weight(.light)).padding()
                refreskButton//.padding(.top, UIScreen.main.bounds.height / 1.4)
            }
        }
        .edgesIgnoringSafeArea([.top, .bottom])
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
        .onAppear() {
            //self.scrollProxy = scrollProxy
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.showRecommended.toggle()
            }
        }
        .onReceive(appCoordinator.$currentLocation, assign: \.currentLocation, target: self)
        .onChange(of: currentLocation) { location in
            switch location {
            case .invited(let inviteId):
                self.playroomId = inviteId
                self.fetchPlayroomByInviteId(inviteId)
            case .error:
                self.errorMessage = Self.GENERIC_ERROR_MESSAGE
            default:
                break
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
