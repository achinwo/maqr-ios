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

struct TrackView: View {
    @EnvironmentObject var appState: AppState
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
            
            self.appState.fetchedImage(url: self.track.thumbnailUrl)
                .then() { (image: Image?) in
                    self.image = image
            }
        }
    }
}

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
                    VStack{
                        ImageStore.shared.image(name: "party-people")
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
        }.onAppear() { self.appState.fetchMusicrooms() }
        //.colorScheme(.dark)
    }
}


public final class ImageStore {
    typealias _ImageDictionary = [String: CGImage]
    fileprivate var images: _ImageDictionary = [:]

    fileprivate static var scale = 2
    
    public static var shared = ImageStore()
    
    public func image(name: String) -> Image {
        let index = _guaranteeImage(name: name)
        
        return Image(images.values[index], scale: CGFloat(ImageStore.scale), label: Text(verbatim: name))
    }

    public static func loadImage(name: String) -> CGImage {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
            let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            fatalError("Couldn't load image \(name).jpg from main bundle.")
        }
        return image
    }
    
    fileprivate func _guaranteeImage(name: String) -> _ImageDictionary.Index {
        if let index = images.index(forKey: name) { return index }
        
        images[name] = ImageStore.loadImage(name: name)
        return images.index(forKey: name)!
    }
}


struct MusicroomList_Previews: PreviewProvider {
    static var previews: some View {
        MusicroomList()
    }
}

