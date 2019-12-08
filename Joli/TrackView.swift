//
//  TrackView.swift
//  Joli
//
//  Created by Anthony Chinwo on 10/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi


struct TrackView: View {
    
    @EnvironmentObject var appState: AppState
    var track: Track
    var allowDelete = false
    
    @State var image: Image?
    var spotifyDevice: JoliApi.SpotifyDevice? {
        return self.appState.spotifyDevice
    }
    
    init(track: Track, allowDelete: Bool = false){
        self.track = track
        self.allowDelete = allowDelete
    }
    
    var explicitLabel: some View {
        if let explicit = track.explicit, explicit {
            return Text("Explicit").padding(2)
            .font(.footnote)
                .foregroundColor(Color.red)
            .cornerRadius(2)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1.2))
               // .font(.subheadline)
                //.border(.red)
        } else {
            return Text("").padding(2)
            .font(.footnote)
            .foregroundColor(Color.clear)
            .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.clear, lineWidth: 1))
        }
    }
    
    var body: some View {
        HStack(alignment: .center) {
            
            CircleImage(image: image)//.background(Color.blue)
            
            VStack(alignment: .leading) {
                Text(track.title ?? track.name!)
                    .font(.headline).lineLimit(2)
                
                HStack {
                    
                    Text("By \(track.artistName ?? "None")")
                        .font(.subheadline)
                    Spacer()
                    
                    self.explicitLabel
                }
            }
        }.contextMenu {
            
            Button(action: {
                guard let room = self.appState.activeRoom else { return }
                room.addTrack(self.track)
                    .always {
                        self.appState.fetchTracks(room)
                }
            }) {
                Text("Add to Queue")
                Image(systemName: "plus")
            }
            
            if self.allowDelete {

                Button(action: {
                    self.appState.api.delete(self.track)
                        .catch() { error in
                            logger.error("[TrackView] delete error: \(error)")
                        }
                        .always() {
                            guard let room = self.appState.activeRoom else { return }
                            
                            self.appState.fetchTracks(room)
                        }
                }) {
                    Text("Delete").foregroundColor(.red)
                    Image(systemName: "minus.circle")
                }
            }
        }
        .onTapGesture {
            logger.debug("currect device: \(String(describing: self.spotifyDevice))\nuri: \(String(describing: self.track.uri))")
            
            if let uri = self.track.uri {

                guard self.appState.spotifyRemote.isConnected else {
                    logger.debug("[Track#play] spotify not connected")
                    self.appState.spotifyRemote.authorizeAndPlayURI(uri)
                    return
                }
                
                self.appState.spotifyRemote.playerAPI?.play(uri){ info, error in
                    
                    logger.debug("[Track#play] \(String(describing: info)) - \(String(describing: error))")
                }//authorizeAndPlayURI(uri)
                
                self.appState.spotifyRemote.playerAPI?.subscribe() { (info, error) in
                    logger.debug("[Track#subscribe] \(String(describing: info)) - \(String(describing: error))")
                }
            }else{

                self.track.play(deviceId: self.spotifyDevice?.id, urlSession: self.appState.api.urlSession)
            }
            
        }
        .onAppear(){
            
            self.appState.fetchedImage(url: self.track.thumbnailUrl!)
                .then() { (image: Image?) in
                    self.image = image
            }
        }
    }
}
