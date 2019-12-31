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
        var durationMs = 0.0
        
        for track in tracks {
            durationMs = durationMs + Double(track.duration ?? 29000)
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .brief
        formatter.maximumUnitCount = 1
        
        var playtime = ""
        if !tracks.isEmpty && durationMs == 0 {
            playtime = "..."
        } else if !tracks.isEmpty {
            playtime = "\(formatter.string(from: durationMs / 1000)!) playtime"
        }
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center){
                Image(systemName: "timer")
                Text(playtime)
                Spacer()
                Image(systemName: "music.note.list")
                Text(tracks.count.description)

                HStack(alignment: .center){
                    Text("•").font(.title)
                    
                    Image(systemName: "hifispeaker")
                    Text(appState.spotifyDevice?.name ?? "None")
                        .lineLimit(1)
                }.opacity(appState.spotifyDevice == nil ? 0.2 : 1)
            }
            .animation(.easeInOut)
            .font(.footnote)
            .foregroundColor(.gray)
            .padding([.leading, .trailing], 16)
            
            Divider()
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
