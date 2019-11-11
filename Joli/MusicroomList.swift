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

struct MusicLibraryView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        //        Picker(selection: self.$selectedSpotifyDeviceIdx, label: Text("Devices")) {
        //            ForEach(self.spotifyDevices) { device in
        //                Text(device.name).tag(self.spotifyDevices.firstIndex(of: device))
        //            }
        //        }.pickerStyle(SegmentedPickerStyle())
        
        TrackSearchView()
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
                NavigationLink(destination: MusicroomView(room: room)) {
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
            .navigationBarTitle(Text("Joli"), displayMode: .inline)
            
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
