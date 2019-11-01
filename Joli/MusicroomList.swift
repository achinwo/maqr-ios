//
//  MusicroomList.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

struct TrackView: View {
    
    var track: Track

    @State var image: Image?
    var spotifyDevice: JoliApi.SpotifyDevice?
    
    
    var body: some View {
        HStack(alignment: .top) {
            
            CircleImage(image: image).padding()

            VStack(alignment: .leading) {
                Text(track.title)
                .font(.title)
                
                Text("By \(track.artistName)")
                    .font(.subheadline)
            }
        }
        .onTapGesture {
            print("currect device: \(String(describing: self.spotifyDevice))")
            self.track.play(deviceId: self.spotifyDevice?.id)
        }
        .onAppear(){
            
            guard let url = URL(string: self.track.thumbnailUrl) else {
                print("failed to load \(self.track.thumbnailUrl)")
                return
            }
            
            let task: URLSessionDataTask = URLSession.shared.dataTask(with: url) { (data, resp, error) in
                guard let data = data, let img = UIImage(data: data) else {
                    print("failed to load \(self.track.thumbnailUrl)")
                    return
                }
                
                self.image = Image(uiImage: img)
            }
            task.resume()
        }
    }
}


struct MusicroomDetail: View {
    @EnvironmentObject var appState: AppState
    
    @State var nowPlayingPosition = 0.0
    @State var selectedSpotifyDeviceIdx: Int?
    @State var nowPlaying: String?
    
    var spotifyDevice: JoliApi.SpotifyDevice? {
        guard let selectedSpotifyDeviceIdx = selectedSpotifyDeviceIdx else { return nil }
        return spotifyDevices[selectedSpotifyDeviceIdx]
    }
    @State var spotifyDevices: [JoliApi.SpotifyDevice] = []
    
    var room: Musicroom
    
    var tracks: [Track] {
        guard let id = room.id else {
            return []
        }
        
        return appState.tracksByMusicrooms[id] ?? []
    }

    var body: some View {
        VStack(alignment: .leading) {
            
            Text(self.nowPlaying != nil ? "Now Playing...\(self.nowPlaying!)" : "").padding()
            Slider(value: self.$nowPlayingPosition, in: 0...100, step: 1)
            .disabled(self.nowPlaying == nil)
                .padding()
            
            Picker(selection: self.$selectedSpotifyDeviceIdx, label: Text("Devices")) {
                ForEach(self.spotifyDevices) { device in
                    Text(device.name).tag(self.spotifyDevices.firstIndex(of: device))
                }
            }.pickerStyle(SegmentedPickerStyle())
                .onAppear(perform: onAppear)
                .onDisappear(perform: onDisappear)
            
                //Text("Value: \(self.selectedSpotifyDeviceId ?? "None")")
            
            List(tracks) { track in
                TrackView(track: track, spotifyDevice: self.spotifyDevice)//.background(Color.pink)
                Spacer()
            }
        }
        //.navigationBarTitle(Text(verbatim: room.name), displayMode: .inline)
    }
    
    func onDisappear(){
        print("Disappeared!!")
        self.appState.api.unsubscribe(subject: "PLAYER_STATE_NOW_PLAYING")
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
            self.nowPlaying = item?["name"] as? String
            
            guard let duration = item?["duration_ms"] as? Double, let progress = data?["progress_ms"] as? Double else {
                return
            }
            print("duration: \(duration), progress: \(progress)")
            
            self.nowPlayingPosition = (progress / duration) * 100
        }
        
        appState.api.fetchSpotifyDevices(on: DispatchQueue.main)
            .then() { devices in
                print("Devices: \(devices)")
                self.spotifyDevices = devices
                
                if self.selectedSpotifyDeviceIdx != nil {
                    return
                }
                
                self.selectedSpotifyDeviceIdx = devices.firstIndex() { $0.isActive }
        }
    }
}

//struct MusicroomDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomDetail()
//    }
//}


struct MusicroomList: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            List(appState.musicrooms) { room in
                NavigationLink(destination: MusicroomDetail(room: room)) {
                    HStack {
                        Text(verbatim: room.name)
                        Spacer()
                    }
                }.onAppear() { self.appState.fetchTracks(room) }
            }
            .navigationBarTitle(Text("Joli"))
        }.onAppear() { self.appState.fetchMusicrooms() }
        //.colorScheme(.dark)
    }
}

struct MusicroomList_Previews: PreviewProvider {
    static var previews: some View {
        MusicroomList()
    }
}
