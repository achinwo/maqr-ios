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
    @State var queuedTracks: [QueuedTrack] = []
    var room: Musicroom
    
    var tracks: [QueuedTrack] {
        let tracks = appState.queuedTracksByMusicrooms[room.id] ?? []
        //logger.info("[returnung tracks] \(tracks)")
        return tracks.sorted(){ (track1, track2) -> Bool in
            let track1Votes = self.appState.votesByTrackId[track1.id]
            let track2Votes = self.appState.votesByTrackId[track2.id]
            
            if track1Votes != nil && track2Votes != nil && track1Votes!.count != track2Votes!.count {
                return track1Votes!.count > track2Votes!.count
            } else if track1Votes != nil && track2Votes != nil {
                return track1.title > track2.title
            } else if track1Votes != nil || track2Votes != nil {
                return track1Votes != nil
            } else {
                return track1.createdAt > track2.createdAt
            }
        }
    }
    
    init(room: Musicroom) {
        self.room = room
    }
    
    var body: some View {
        let track = self.appState.currentlyPlayingTrack
        let tracksViewHeight = CGFloat(80.0 * Double(self.tracks.count))
        
        let width: CGFloat
            
        if self.appState.currentlyPlayingProgressPct > 0 {
            width = CGFloat(self.appState.currentlyPlayingProgressPct / 100.0) * UIScreen.main.bounds.width
        }else{
            width = 0
        }
        
        //logger.info("[Progress.width] \(width)")
        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                
                Divider()
                VStack(alignment: .center){
                    self.appState.currentlyPlayingAlbumImage?.resizable()
                        .aspectRatio(contentMode: ContentMode.fill)
                        .clipped()
                    
                }
                .animation(.easeInOut)
                .onAppear(perform: self.onAppear)
                .onDisappear(perform: self.onDisappear)
                .background(Color.purple)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width, alignment: .top)
                   // .offset(x: 0, y: UIScreen.main.bounds.width)
                //.padding()
                //.background()

                ZStack(alignment: .leading){
                    Color.gray.frame(width: UIScreen.main.bounds.width, height: 4, alignment: .leading)
                        
                    Color.green.frame(width: width, height: 4, alignment: .leading)
                        .animation(.spring())
                        .shadow(radius: 12)
                }
            .clipped()
                .animation(.easeInOut)
                .frame(width: UIScreen.main.bounds.width, height: track == nil ? 0 : 4, alignment: .leading)
                
                if track != nil {
                    TrackView(track: track!).padding().padding([.top, .bottom], 4)
                    Divider()
                }
                
                VStack(alignment: .leading){

                    List {
                        ForEach(self.tracks, id: \.uri) { track in
                            TrackView(track: track)//.background(Color.pink)
                            //Text("\(track.title)")//.tag(track.url)
                        }
                    }
                    .background(Color.pink)
                    .frame(width: UIScreen.main.bounds.width, height: tracksViewHeight, alignment: .center)
                }
            }
        }//.content.offset(x: 0, y: UIScreen.main.bounds.width)
        
    }
    
    @State var showPopover = false
    
    func onDisappear(){
        logger.debug("Disappeared!! Art is not  visible")
        //self.appState.api.unsubscribe(subject: "PLAYER_STATE_NOW_PLAYING")
    }
    
    func onAppear() {
        logger.debug("Appeared - 2!! Art is visible")
        
        appState.fetchQueuedTracks(room)
    }
    
}
