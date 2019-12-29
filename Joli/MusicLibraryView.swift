//
//  MusicLibraryView.swift
//  Joli
//
//  Created by Anthony Chinwo on 20/12/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

struct MusicLibraryView: MusicroomTabView {
    @EnvironmentObject var appState: AppState
    @State var albumArt: Image?
    @State var albumArtUrl: String?
        
    var room: Musicroom
    
    init(room: Musicroom) {
        self.room = room
    }
    
    var tracks: [RoomTrack] {
        return (appState.tracksByMusicrooms[room.id] ?? []).map() { $0 }
    }
    
    @State var nowPlayingPosition = 0.0
    @State var nowPlaying: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(self.tracks) { track in
                    TrackView(track: track)//.background(Color.pink)
                }
                //.keyboardType(.)
                //.onDelete(perform: self.delete)
            }
        }.padding(.bottom, 80)
    }
    
    func delete(at offsets: IndexSet) {
        logger.error("[PlayQueueView] Delete broken! offsets: \(offsets)")
//        for idx in offsets {
//            guard let track = appState.tracksByMusicrooms[room.id]?.remove(at: ) else {
//                continue
//            }
//            appState.api.delete(track)
//        }
    }
    
    func onDisappear(){
        logger.debug("Disappeared!!")
        //self.appState.api.unsubscribe(subject: "PLAYER_STATE_NOW_PLAYING")
    }
    
    func onAppear() {
        logger.debug("Appeared - 2!!")
        
        appState.fetchSpotifyDevices()
    }
}
