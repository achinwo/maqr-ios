//
//  TrackView.swift
//  Joli
//
//  Created by Anthony Chinwo on 10/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

struct TrackView: View {
    
    @EnvironmentObject var appState: AppState
    var track: Playable
    
    var isVoteable: Bool {
        return track is QueuedTrack
    }
    
    @State var image: Image?
    var spotifyDevice: Spotify.Device? {
        return self.appState.spotifyDevice
    }
    
    var isQueueable: Bool {
        return !(track is QueuedTrack)
    }
    
    var isDeleteable: Bool {
        return track is QueuedTrack || track is RoomTrack
    }
    
    init(track: Playable){
        self.track = track
    }
    
    var explicitLabel: some View {
        return Text(track.explicit == nil ? "" : "E")
        .padding(2)
        .background(Color.red)
        .font(.footnote)
        .foregroundColor(Color.white)
        .cornerRadius(3)
        .opacity(track.explicit == nil ? 0.0 : 100)
        //.overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1.2))
    }
    
    var body: some View {
        HStack(alignment: VerticalAlignment.center) {
            
            CircleImage(url: track.thumbnailUrl) //.background(Color.blue)
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.headline).lineLimit(2)
                
                HStack {
                    
                    Text("By \(track.artistName)")
                        .font(.subheadline)
                    Spacer()
                    
                    self.explicitLabel
                }
            }
            
            if self.isQueueable {
                Button(action: {
                    logger.debug("[TrackView] \(self.track.title)")
                }) {
                    Image(systemName: "plus").font(.subheadline)
                }.padding()
            }
            
            if self.track is QueuedTrack {
                Button(action: {
                    logger.debug("[TrackView] \(self.track.title)")
                }) {
                    HStack(){
                        
                        Image(systemName: "hand.thumbsup").font(.subheadline)
                        //Text((self.track as? QueuedTrack)?.votes?.count ?? "")
                    }
                }.padding()
            }
        }.contextMenu {
            
            if self.isQueueable {
                Button(action: {
                    guard let room = self.appState.activeRoom, let track = self.track as? Spotify.Track else { return }
                    self.appState.api.addTrackToRoom(room, track)
                        .then(){ track in
                            return
                        }
                        .catch() { error in
                            logger.error("[TrackView] addTrack error: \(error)")
                        }
                        .always {
                            self.appState.fetchTracks(room)
                            self.appState.fetchQueuedTracks(room)
                    }
                }) {
                    Text("Add to Queue")
                    Image(systemName: "plus")
                }
            }
//            if self.track is Persisted {
//
//                Button(action: {
//                    self.appState.api.delete(self.track)
//                        .catch() { error in
//                            logger.error("[TrackView] delete error: \(error)")
//                        }
//                        .always() {
//                            guard let room = self.appState.activeRoom else { return }
//
//                            self.appState.fetchTracks(room)
//                        }
//                }) {
//                    Text("Delete").foregroundColor(.red)
//                    Image(systemName: "minus.circle")
//                }
//            }
        }
        .onTapGesture {
            self.appState.playTrack(self.track)
        }
        .onAppear(){
            
            self.appState.fetchedImage(url: self.track.thumbnailUrl)
                .then() { (image: Image?) in
                    self.image = image
            }
        }
    }
}
