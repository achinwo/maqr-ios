//
//  PlayQueueView.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

struct PlayQueueView: View {
    
    @State var albumArt: Image?
    @State var albumArtUrl: String?
    
    var body: some View {
        GeometryReader() { geometry in
            VStack(alignment: .leading) {
                
                VStack(alignment: .leading){
                    Text(self.nowPlaying != nil ? "Now Playing...\(self.nowPlaying!)" : "")
                        .font(.title)
                    
                        //.font(self.albumArtUrl == nil ? Color.black : Color.white)
                        .padding()
                    Slider(value: self.$nowPlayingPosition, in: 0...100, step: 1)
                        .disabled(self.nowPlaying == nil)
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
                    
                .background(self.albumArt?.resizable().aspectRatio(contentMode: ContentMode.fill))
                
                //Text("Value: \(self.selectedSpotifyDeviceId ?? "None")")
                List {
                    ForEach(self.tracks) { track in
                        TrackView(track: track)//.background(Color.pink)
                    }
                    .onDelete(perform: self.delete)
                }
                
            }
        }
        
    }
    
    func delete(at offsets: IndexSet) {
        guard let id = room.id?.int else {
            return
        }
        print("[PlayQueueView] offsets: \(offsets)")
        for idx in offsets {
            appState.tracksByMusicrooms[id]?.remove(at: idx)
        }
    }
    
    @EnvironmentObject var appState: AppState
    
    var room: Musicroom
    
    var tracks: [Track] {
        guard let id = room.id?.int else {
            return []
        }
        
        return appState.tracksByMusicrooms[id] ?? []
    }
    
    @State var nowPlayingPosition = 0.0
    @State var nowPlaying: String?
    
    func onDisappear(){
        print("Disappeared!!")
        //self.appState.api.unsubscribe(subject: "PLAYER_STATE_NOW_PLAYING")
    }
    
    static func jsonStringToDict(text: String) -> [String:AnyObject]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
            } catch let error {
                print(error)
            }
        }
        return nil
    }
    
    func onAppear() {
        print("Appeared - 2!!")
        //AVAudioSession.sharedInstance()
        
        if !appState.api.wsClient.connected {
            appState.api.wsClient.connect()
        }
        
        self.appState.api.subscribe(subject: "PLAYER_STATE_NOW_PLAYING"){ result in
            
            guard let json = result.successString, let jsonDict = Self.jsonStringToDict(text: json) else {
                print("failed to  deserialise result: \(result)")
                return
            }
            
            let data = jsonDict["data"] as? [String: AnyObject]
            let item = data?["item"] as? [String: AnyObject]
            //?["name"]
            //print("\(String(describing: item?["name"]))")//duration_ms
            
            //print("\(String(describing: item?["album"]))")
            
            self.nowPlaying = item?["name"] as? String
            
            if let album = item?["album"] as? Json2,
                let img = (album["images"] as? [Json2])?[1],
                let artUrl = img["url"] as? String,
                self.albumArtUrl == nil || (self.albumArtUrl != nil && artUrl != self.albumArtUrl) {
                
                self.appState.fetchedImage(url: artUrl)
                    .then() { imgObj in
                        self.albumArt = imgObj
                        self.albumArtUrl = artUrl
                }
            }
            
            guard let duration = item?["duration_ms"] as? Double, let progress = data?["progress_ms"] as? Double else {
                return
            }
            print("duration: \(duration), progress: \(progress)")
            
            self.nowPlayingPosition = (progress / duration) * 100
        }
        
        appState.fetchSpotifyDevices()
    }
    
}
