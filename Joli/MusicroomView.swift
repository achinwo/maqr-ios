//
//  MusicroomView.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

enum MusicroomTab: Int, CaseIterable {
    case library = 0
    case playQueue = 1
    case activity = 2
    
    var title: String {
        switch(self){
        case .library:
            return "Library"
        case .activity:
            return "Activity"
        case .playQueue:
            return "Playing"
        }
    }
    
    var iconName: String {
        switch(self){
        case .library:
            return "rectangle.stack"
        case .activity:
            return "list.bullet.below.rectangle"
        case .playQueue:
            return "music.house"
        }
    }
}

struct MusicroomView: View {
    @EnvironmentObject var appState: AppState
    
    var room: Musicroom
    @Environment(\.presentationMode) var presentationMode
    @State var selectedTabIdx = 1
    @State var isSearchingTracks = false
    @State var isDeviceSelectPresented = false
    
    var navTrailingItem: some View {
        var imageName: String
        var action: () -> Void
        
        if selectedTabIdx == 0 || selectedTabIdx == 1 {
            imageName = "plus"
            action = { self.isSearchingTracks.toggle() }
        }else{
            imageName = "gear"
            action = {
                self.appState.isSettingsPresented.toggle()
            }
        }
        
        var buttons: [ActionSheet.Button] = appState.spotifyDevices.map() { device in
            var suffix = ""
            if let selectedDeviceIdx = self.appState.selectedSpotifyDeviceIdx,
                device == self.appState.spotifyDevices[selectedDeviceIdx] {
                suffix = " ✔️"
            }
            
            return .default(Text("\(device.name)\(suffix)")) {
                logger.debug("[spotifyDevices] selected device: \(device)")
                self.appState.selectedSpotifyDeviceIdx = self.appState.spotifyDevices.firstIndex(of: device)
            }
        }
        
        buttons.append(.cancel())
        
        return HStack(alignment: .firstTextBaseline) {
            Spacer()
            if selectedTabIdx == MusicroomTab.playQueue.rawValue {
                Button(action: {self.isDeviceSelectPresented.toggle()}) {
                        Image(systemName: "hifispeaker")
                            .padding()
                    }.actionSheet(isPresented: self.$isDeviceSelectPresented){
                    ActionSheet(title: Text("Select Audio Device"), message: Text("Spotify connected devices"), buttons: buttons)
                }
            }
            
            Button(action: action) {
                    Image(systemName: imageName)
                        .padding()
            }.sheet(isPresented: self.$isSearchingTracks){
                NavigationView(){
                    TrackSearchView()
                    .navigationBarTitle(Text("Add Tracks to Queue"), displayMode: .inline)
                }
                .environmentObject(self.appState)
            }
        }
    }
    
    var body: some View {
 
        return VStack(alignment: .center){
            Picker(selection: self.$selectedTabIdx, label: Text("Room")){
                ForEach(MusicroomTab.allCases, id: \.self){ roomTab in
                    Text(roomTab.title).tag(roomTab.rawValue)
                }
            }
        .zIndex(500)
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if self.selectedTabIdx == MusicroomTab.library.rawValue{
                MusicLibraryView(room: self.room)
            }else if self.selectedTabIdx == MusicroomTab.playQueue.rawValue {
                PlayQueueView(room: self.room)
            }else if self.selectedTabIdx == MusicroomTab.activity.rawValue{
                ActivityView(room: self.room)
            }
        }
        
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 200, alignment: .top)
        //.padding(.top, 80)
        //.background(Color.yellow)
        .onAppear() {
            self.appState.activeRoom = self.room
            self.appState.fetchTracks(self.room)
        }
        .navigationBarItems(trailing:
            self.navTrailingItem
        )
            .navigationBarTitle(Text(room.name), displayMode: .inline)
    }
    
    @State var isSearching = false
}

//struct MusicroomView_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomView()
//    }
//}
