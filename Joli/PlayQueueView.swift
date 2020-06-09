//
//  PlayQueueView.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

struct PlayQueueView: MusicroomTabView {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var currentlyPlaying: AppCurrentlyPlayingState
    @State var queuedTracks: [QueuedTrack] = []
    var room: Musicroom
    
    var tracks: [QueuedTrack] {
        let tracks = appState.queuedTracksByMusicrooms[room.id] ?? []
        
        return tracks.sorted(){ (track1, track2) -> Bool in
            let track1Votes = self.appState.votesByTrackId[track1.id]
            let track2Votes = self.appState.votesByTrackId[track2.id]
            
            if let votes1 = track1Votes, let votes2 = track2Votes, votes1.count != votes2.count {
                return votes1.count > votes2.count
            } else if track1Votes != nil && track2Votes != nil {
                return track1.title > track2.title
            } else if track1Votes != nil || track2Votes != nil {
                return track1Votes != nil
            } else {
                return track1.createdAt >= track2.createdAt
            }
        }
    }
    
    init(room: Musicroom) {
        self.room = room
    }
    
    var body: some View {
        let track = self.currentlyPlaying.track
        let tracksViewHeight = CGFloat(80.0 * Double(self.tracks.count))
        
        var width: CGFloat = .zero
            
        if self.currentlyPlaying.progressPct > 0 {
            width = CGFloat(self.currentlyPlaying.progressPct / 100.0) * UIScreen.main.bounds.width
        }
        
        return VStack(alignment: .center, spacing: 0){
            Divider()
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    VStack(alignment: .center){
                        self.currentlyPlaying.albumImage?.resizable()
                            .aspectRatio(contentMode: ContentMode.fill)
                            .clipped()
                        
                    }
                    .animation(.spring())
                    .onAppear(perform: self.onAppear)
                    .onDisappear(perform: self.onDisappear)
                    .background(Color.purple)
                    .frame(width: UIScreen.main.bounds.width,
                           height: self.currentlyPlaying.albumImage != nil ? UIScreen.main.bounds.width : 2,
                           alignment: .top)
                    //.offset(x: 0, y: )
                    //.padding()
                    //.background()

                    ZStack(alignment: .leading){
                        Color.gray.frame(width: UIScreen.main.bounds.width, height: 4, alignment: .leading)
                            
                        Color.green.frame(width: width, height: 4, alignment: .leading)
                            .cornerRadius(1)
                            .animation(.spring())
                            .shadow(radius: 12)
                    }
                .clipped()
                    .animation(.easeInOut)
                    .frame(width: UIScreen.main.bounds.width, height: track == nil ? 0 : 4, alignment: .leading)
                    
                    self.controlsView
                    Divider()
                    
                    VStack(alignment: .leading){

                        List {
                            ForEach(self.tracks, id: \.uri) { track in
                                TrackView(track: track).tag(track.uri)
                            }
                        }
                        .background(Color.pink)
                        .frame(width: UIScreen.main.bounds.width, height: tracksViewHeight, alignment: .center)
                    }
                }
            }
        }
        
    }
    
    @State var showPopover = false
    @State var isRequestingPlay = false
    @State var isPlaying = false
    
    var controlsView: some View {
        return HStack(alignment: .center, spacing: 4) {
//            NetworkImage(imageURL: URL(string: "https://i.scdn.co/image/ab67616d0000485155375ff19ae4e7ab60da3cac")!,
//                         placeholderImage: UIImage(systemName: "bookmark")!)
            
            Spacer()
            
            Image(systemName: self.isPlaying ? "pause.circle" : "play.circle")
            .resizable().padding(.trailing, 10).padding(.bottom, 10)
            .foregroundColor(self.isRequestingPlay ? Color.gray : Color.primary)
            .frame(width: 64, height: 64, alignment: .bottomLeading)
            .onTapGesture() {
                logger.debug("Play room \(self.room.id)")
                
            }
        }.padding(6)
    }
    
    func onDisappear(){
        logger.debug("Disappeared!! Art is not  visible")
        //self.appState.api.unsubscribe(subject: "PLAYER_STATE_NOW_PLAYING")
    }
    
    func onAppear() {
        logger.debug("Appeared - 2!! Art is visible")
        
        appState.fetchQueuedTracks(room)
        appState.fetchSpotifyDevices()
    }
    
}
