//
//  MusicroomList.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import AVKit


//extension MPVolumeView {
//    var volumeSlider: UISlider? {
//        showsRouteButton = false
//        showsVolumeSlider = false
//        isHidden = true
//        for subview in subviews where subview is UISlider {
//            let slider =  subview as! UISlider
//            slider.isContinuous = false
//            slider.value = AVAudioSession.sharedInstance().outputVolume
//            return slider
//        }
//        return nil
//    }
//}

struct PlayQueueView: View {
    var body: some View {
        VStack(alignment: .leading) {
            
            Text(self.nowPlaying != nil ? "Now Playing...\(self.nowPlaying!)" : "")
                .font(.title)
                .padding()
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
    @State var selectedSpotifyDeviceIdx: Int?
    @State var nowPlaying: String?
    
    var spotifyDevice: JoliApi.SpotifyDevice? {
        guard let selectedSpotifyDeviceIdx = selectedSpotifyDeviceIdx else { return nil }
        return spotifyDevices[selectedSpotifyDeviceIdx]
    }
    @State var spotifyDevices: [JoliApi.SpotifyDevice] = []
    
    
    
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
                
                //                guard let sel = self.selectedSpotifyDeviceIdx else {
                //                    return
                //                }
                
                //let volume = Float(devices[sel].volumePercent) / 100
                //AVAudioSession.sharedInstance().setValue(volume, forKeyPath: "outputVolume")
        }
    }
    
}

struct MusicLibraryView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        //        Picker(selection: self.$selectedSpotifyDeviceIdx, label: Text("Devices")) {
        //            ForEach(self.spotifyDevices) { device in
        //                Text(device.name).tag(self.spotifyDevices.firstIndex(of: device))
        //            }
        //        }.pickerStyle(SegmentedPickerStyle())
        
        NavigationView {
            Text("Music Library")
        }
        .navigationBarItems(trailing: NavigationLink(destination: TrackSearchView()) {
            Text("Search")
        })
    }
}

struct ActivityView: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        //        Picker(selection: self.$selectedSpotifyDeviceIdx, label: Text("Devices")) {
        //            ForEach(self.spotifyDevices) { device in
        //                Text(device.name).tag(self.spotifyDevices.firstIndex(of: device))
        //            }
        //        }.pickerStyle(SegmentedPickerStyle())
        Text("Activity")
            .onAppear() {
                
                self.appState.api.subscribe(subject: "") { result in
                    print("Activity: \(result)")
                }
        }
    }
}

struct MusicroomDetail: View {
    @EnvironmentObject var appState: AppState
    
    var room: Musicroom
    @Environment(\.presentationMode) var presentationMode
    @State var selectedTabIdx = 1
    
    var body: some View {
        TabView(selection: self.$selectedTabIdx) {
            MusicLibraryView()
                .tabItem {
                    //Image(systemName: "2.circle")
                    Text("Music Library").font(.largeTitle)
            }.tag(0)
            
            
            PlayQueueView(room: self.room)
                .tabItem {
                    //Image(systemName: "1.circle")
                    Text("Playing")
            }.tag(1)
            
            ActivityView()
                .tabItem {
                    //Image(systemName: "2.circle")
                    Text("Activity")
            }.tag(2)
        }.font(.largeTitle)
            .accentColor(.orange)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading:
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text("Joli").accentColor(.orange).font(.title)
                    }
                }, trailing:
                Button(action: {
                    self.isSearching = true
                }) {
                    Text("Search")
                }.sheet(isPresented: self.$isSearching){
                    TrackSearchView().environmentObject(self.appState)
            })
        //            .navigationBarItems(trailing:
        //                Button(action: {
        //                    self.isSearching = true
        //                }) {
        //                  Text("Search")
        //                }.sheet(isPresented: self.$isSearching){
        //                    TrackSearchView()
        //                }
        //            )
        
        //.navigationBarTitle(Text(verbatim: room.name), displayMode: .inline)
    }
    
    @State var isSearching = false
}

//struct MusicroomDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomDetail()
//    }
//}

extension View {
    
}

struct MusicroomList: View {
    
    @EnvironmentObject var appState: AppState
    @State var showingDetail = false
    
    var body: some View {
        NavigationView {
            List(appState.musicrooms) { room in
                NavigationLink(destination: MusicroomDetail(room: room)) {
                    VStack{
                        ImageStore.shared.image(name: "party-people")
                            .cornerRadius(100)
                        //.border(Rectangle())
                        //.frame(width: .infinity, height: nil, alignment: .center)
                        HStack {
                            Spacer()
                            Text(verbatim: room.name).font(.title)
                            Spacer()
                        }
                    }
                }.onAppear() { self.appState.fetchTracks(room) }
            }
            .navigationBarTitle(Text("Joli"))
            
        }.onAppear() {
            self.appState.fetchMusicrooms()
        }
        //.colorScheme(.dark)
    }
}

//struct MusicroomList_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomList()
//    }
//}
//
