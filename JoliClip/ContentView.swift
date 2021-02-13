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
import StoreKit
import Promises
import UIImageColors

struct ContentView: JoliView {
    
    @State var showRecommended = false
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @State var playroom: Playroom? = nil
    @State var errorMessage: String? = nil
    @State var playroomId: String? = nil
    @State var scrollProxy: ScrollViewProxy? = nil
    
    let websocket: Socket
    
    @State var loadingView = false
    
    var body: some View {
        return NavigationView(){
            GeometryReader() { geoProxy in
                ZStack(){
                    ScrollViewReader() { scrollProxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            
                            if loadingView {
                                ProgressView("Loading Playroom").padding()
                            } else if let error = errorMessage {
                                Text(error).padding()
                            } else if let playroom = playroom {
                                tracksView(playroom, geoProxy)
                            } else {
                                Text(Self.GENERIC_ERROR_MESSAGE).padding()
                            }
                            
                            
                            //            #if APPCLIP
                            //            Button("Show Recommended App") {
                            //                self.showRecommended.toggle()
                            //            }
                            //            .appStoreOverlay(isPresented: $showRecommended) {
                            //                SKOverlay.AppConfiguration(appIdentifier: "1491605469", position: .bottom)
                            //            }
                            //            #endif
                            
                            
                        }
                        .onAppear() {
                            self.scrollProxy = scrollProxy
                        }
                    }
                    
                    //            PlayroomHeaderView(playroom: self.$playroom,
                    //                               strip: self.$strip,
                    //                               preview: self.$preview,
                    //                               tracks: self.$tracks,
                    //                               scrollProxy: self.$scrollProxy
                    //            )
                    //            .padding(.horizontal, Sizing.small * 0.6)
                    //            .padding([.horizontal, .bottom], Sizing.small * 0.5)
                    //            //.frame(maxWidth: screenWidth)
                    //
                    //            Divider().opacity(self.playroom == nil ? 0 : 1).animation(.easeInOut)
                    
                    //            AppPreviewView(preview: self.$preview, currentUser: self.$currentUser, animation: animation)
                    //                .frame(maxWidth: screenWidth)
                    //                .frame(minWidth: screenWidth, maxHeight: screenHeight)
                    //                .background(BlurView(.extraLight))
                    //                .padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                    //                .offset(x: 0, y: self.preview == nil ? screenHeight : 0)
                    //                .animation(.spring())
                    
                }
            }
            .navigationTitle(playroom?.name ?? "")
            //.ignoresSafeArea()
        }
        .onReceive(appCoordinator.$currentLocation) { location in
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
    
    @State var strip: (playing: Playable?, next: Playable?, runnerup: Playable?) = (nil, nil, nil)
    @State var requestingVoteTrackId: Int? = nil
    @State var votesByTrack: [Int: [QueuedTrackVote]] = [:]
    @State var voteCasted: QueuedTrackVote? = nil
    @State var votes: [QueuedTrackVote] = []
    
    @State var tracks: [Playable] = []
    
    @Binding var tabbarExpaned: Bool
    @Binding var preview: AppPreview?
    @Binding var filterText: String
    
    @State var tracksFiltered: [Playable] = []
    
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
    
    func tracksView(_ playroom: Playroom, _ geoProxy: GeometryProxy) -> some View {
        return TrackList(tracks: self.$tracksFiltered, votes: self.$votes, preview: $preview, playroom: self.$playroom, addonView: self.addonView)
            //.padding(.top, geoProxy.safeAreaInsets.top)
            //.padding(.top, roomControlViewBounds == nil ? geoProxy.safeAreaInsets.top : roomControlViewBounds?.height)
            //.padding(.top, 100)
            //.padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds?.height)
            .background(Color.white)
            .onReceive(playroom.$queue) { tracks in
                var tracksByMusicrooms: [Int: [QueuedTrack]] = [:]
                var allVotes: [QueuedTrackVote] = []
                
                for track in tracks.filter({ $0.isPlayable }) {
                    var roomTracks = tracksByMusicrooms[track.roomId] ?? []
                    
                    guard !roomTracks.contains(track) else {
                        continue
                    }
                    
                    roomTracks.append(track)
                    tracksByMusicrooms[track.roomId] = roomTracks
                    
                    guard let votes = track.votes, track.roomId == playroom.musicroom.id else {
                        continue
                    }
                    
                    allVotes.append(contentsOf: votes)
                }
                
                self.votes = allVotes
                self.tracks = tracksByMusicrooms[playroom.musicroom.id] ?? []
                self.tracksFiltered = self.filterTracks(self.tracks, self.filterText)
                
                self.strip = (
                    playing: tracks.first,
                    next: tracks.count > 1 ? tracks[1] : nil,
                    runnerup: tracks.count > 2 ? tracks[2] : nil
                )
            }
            .onChange(of: self.votes) { votes in
                var mapping: [Int: [QueuedTrackVote]] = [:]
                
                for vote in votes {
                    
                    guard var existing = mapping[vote.queuedTrackId] else {
                        mapping[vote.queuedTrackId] = []
                        continue
                    }
                    
                    existing.append(vote)
                    mapping[vote.queuedTrackId] = existing
                }
                
                self.votesByTrack = mapping
            }
    }
    
    func addonView(track: Playable, playStates: [PlayState], colors: UIImageColors?) -> some View {
        
        
        return Group() {
            if let track = track as? QueuedTrack,
               let room = playroom,
               let playlistUri = room.playlistUri,
               let playing = self.strip.playing as? QueuedTrack,
               playing.id == track.id,
               playing.isPlayable, track.isPlayable {
                
                Button() {
                    let state = playStates.first() { $0.email == room.createdByUser.email } ?? playStates.first
                    appCoordinator.play(track, positionMs: state?.progressMs, contextUri: playlistUri, device: appCoordinator.activeDeviceSubject.value)
                        .then() { state in
                            print("[ListenView] rejoining \(track.title) at \(String(describing: state?.progressMs)) - \(String(describing: state))")
                        }
                } label: {
                    Text("Rejoin").padding()
                }
                .font(.headline)
                .padding(.trailing, Sizing.medium)
                
            } else if let track = track as? QueuedTrack {
                
                let scaleX: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                let scaleY: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                
                let heart: Binding<Hearts?> = Binding() { () -> Hearts? in
                    
                    guard playroom != nil else {
                        return nil
                    }
                    
                    guard let count: Int = self.votesByTrack[track.id]?.count else {
                        return Hearts(score: HeartLevel.empty.rawValue)
                    }
                    
                    return Hearts(score: CGFloat(count) * HeartLevel.quarter.rawValue)
                    
                } set: { (heart, trasacton) in
                    
                }
                
                JoyMeterView(heart, textStyle: UIFont.TextStyle.title2, backgroundColor: Color.red.opacity(0.5))
                    .padding()
                    .padding(.trailing, Sizing.medium)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                    .onReceive(appCoordinator.voteCastSubject) { vote in
                        self.voteCasted = vote
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


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
