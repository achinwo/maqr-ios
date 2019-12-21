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

struct PlayQueueView: View {
    
    @EnvironmentObject var appState: AppState
    @State var queuedTracks: [QueuedTrack] = []
    var room: Musicroom
    
    var tracks: [QueuedTrack] {
        return appState.queuedTracksByMusicrooms[room.id] ?? []
    }
    
    var body: some View {
        let track = self.appState.currentlyPlayingTrack
        let title = track?.name
        
        return VStack(alignment: .leading) {
            
            VStack(alignment: .leading){
                Text(title != nil ? "Now Playing...\(title!)" : "")
                    .font(.title)
                    .padding()
                Slider(value: self.$appState.currentlyPlayingProgressPct, in: 0...100, step: 1)
                    .disabled(self.appState.currentlyPlayingTrack == nil)
                    .allowsHitTesting(false)
                
            }
            .onAppear(perform: self.onAppear)
            .padding()
                //.background(Color.blue)
            .frame(width: UIScreen.main.bounds.width, height: 100, alignment: .top)
            .background(self.appState.currentlyPlayingAlbumImage?.resizable()
            .aspectRatio(contentMode: ContentMode.fill).clipped())

            
//            VStack(alignment: .leading) {
//                List {
//                    ForEach(self.tracks) { track in
//                        TrackView(track: track, allowDelete: true)//.background(Color.pink)
//                    }
//                }
//            }.background(Color.pink)
        }//.background(Color.green)
    }
    @State var showPopover = false
    func onDisappear(){
        logger.debug("Disappeared!!")
        //self.appState.api.unsubscribe(subject: "PLAYER_STATE_NOW_PLAYING")
    }
    
    func onAppear() {
        logger.debug("Appeared - 2!!")
        
        appState.fetchSpotifyDevices()
    }
    
}
