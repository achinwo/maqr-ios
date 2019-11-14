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
    
    @State var image: Image?
    var spotifyDevice: JoliApi.SpotifyDevice? {
        return self.appState.spotifyDevice
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
            
            CircleImage(image: image).padding()
            
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

//            Button(action: {
//                // enable geolocation
//            }) {
//                Text("Detect Location")
//                Image(systemName: "location.circle")
//            }
        }
        //.background(Color.yellow)
        .onTapGesture {
            print("currect device: \(String(describing: self.spotifyDevice))")
            self.track.play(deviceId: self.spotifyDevice?.id)
        }
        .onAppear(){
            
            self.appState.fetchedImage(url: self.track.thumbnailUrl!)
                .then() { (image: Image?) in
                    self.image = image
            }
        }
    }
}
