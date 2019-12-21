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
    
    
    var body: some View {
        let track = self.appState.currentlyPlayingTrack
        let title = track?.name
        
        return GeometryReader() { geometry in
            VStack(alignment: .leading) {
                
                VStack(alignment: .leading){
                    Text(title != nil ? "Now Playing...\(title!)" : "")
                        .font(.title)
                        .padding()
                    Slider(value: self.$appState.currentlyPlayingProgressPct, in: 0...100, step: 1)
                        .disabled(self.appState.currentlyPlayingTrack == nil)
                        .allowsHitTesting(false)
                        //.padding().background(Color.pink)
                    
                    Picker(selection: self.$appState.selectedSpotifyDeviceIdx, label: Text("Devices")) {
                        ForEach(self.appState.spotifyDevices) { device in
                            Text(device.name).tag(self.appState.spotifyDevices.firstIndex(of: device))
                            //.font(self.albumArtUrl == nil ? Color.black : Color.white)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                        .onAppear(perform: self.onAppear)
                        .onDisappear(perform: self.onDisappear)
                    }.padding()
                    .frame(minWidth: geometry.size.width, idealWidth: geometry.size.width, maxWidth: geometry.size.width, minHeight: geometry.size.height / 6, idealHeight: geometry.size.height / 4, maxHeight: geometry.size.height / 4, alignment: .top)
                    
                    .background(self.appState.currentlyPlayingAlbumImage?.resizable().aspectRatio(contentMode: ContentMode.fill))
                
            }
        }
        
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
