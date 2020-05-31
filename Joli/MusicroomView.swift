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

enum MusicroomTab: Int, CaseIterable, Hashable {
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
    
    var emoji: String? {
        switch(self){
        case .library:
            return "💽"
        case .activity:
            return "🔮"
        case .playQueue:
            return "🎶"
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

protocol MusicroomTabView: View {
    init(room: Musicroom)
}


struct MusicroomView: View {
    @EnvironmentObject var appState: AppState
    
    var room: Musicroom
    @Environment(\.presentationMode) var presentationMode
    //@State var selectedTabIdx = 1
    @State var isSearchingTracks = false
    @State var isDeviceSelectPresented = false
    
    var navTrailingItem: some View {
        var imageName: String
        var action: () -> Void
        
        if self.appState.selectedTabIdx == 0 || self.appState.selectedTabIdx == 1 {
            imageName = "plus.magnifyingglass"
            action = { self.isSearchingTracks.toggle() }
        }else{
            imageName = "gear"
            action = {
                self.appState.isSettingsPresented.toggle()
            }
        }
        
        return HStack(alignment: .firstTextBaseline) {
            Spacer()
            if [MusicroomTab.playQueue.rawValue, MusicroomTab.library.rawValue].contains(self.appState.selectedTabIdx) {
                Button(action: {self.appState.isDeviceChooserPresented.toggle()}) {
                        Image(systemName: "hifispeaker")
                            .padding()
                }.disabled(self.appState.spotifyDevices.isEmpty)
                
            
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
                Button(action: shareButton){
                        Image(systemName: "square.and.arrow.up")
                    .padding()
                    }
                }
        }
    }
    @State private var isSharePresented: Bool = false
    var body: some View {
        return VStack(alignment: .center, spacing: 0){

            if !self.appState.alerts.isEmpty {
                self.appState.alerts.sortedByImportance.first!.view(self.appState)
                .frame(width: UIScreen.main.bounds.width,
                       height: 50, alignment: .center)
                .clipped()
                .animation(.easeInOut)
                
                Divider()
            }
            
            Picker(selection: self.$appState.selectedTabIdx, label: Text("Room")){
                ForEach(MusicroomTab.allCases, id: \.self){ roomTab in
                    Text("\(roomTab.emoji != nil ? "\(roomTab.emoji!) " : "")\(roomTab.title)")
                        .foregroundColor(.green)
                        .tag(roomTab.rawValue)
                }
            }
            .zIndex(500)
            .opacity(90)
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if self.appState.selectedTabIdx == MusicroomTab.library.rawValue{
                MusicLibraryView(room: self.room)
            }else if self.appState.selectedTabIdx == MusicroomTab.playQueue.rawValue {
                PlayQueueView(room: self.room)
            }else if self.appState.selectedTabIdx == MusicroomTab.activity.rawValue{
                ActivityView(room: self.room)
            }

        }
        //.toast(isShowing: self.$appState.showToast, text: Text("Hello toast!"))
        
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height, alignment: .top)
        .padding(.top, 120)
        //.background(Color.green)
        
        .onAppear() {
            self.appState.activeRoom = self.room
            self.appState.fetchTracks(self.room)
            self.appState.assertSpotifyAuthorized()
        }
        .navigationBarItems(trailing:
            self.navTrailingItem
        )
        .navigationBarTitle(Text(room.name), displayMode: .inline)
        
        
    }
    func shareButton(){
        isSharePresented.toggle()
        let text = "You have been invited to join the " + room.name + " room. Use https:://api.jolimc.com/join/" + String(room.id) + " to join the rool."
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
    }

    
    
    @State var isSearching = false
}

struct BubbleTabView<Content> : View where Content : View {
    @EnvironmentObject<AppState> var appState: AppState
    
    let tabItems: [TabItem]
    let label: Text
    @State var selected: TabItem?
    var selectedIndex: Binding<Int>?
    let content: () -> Content
    
    init(selection: Binding<Int>?, tabItems: [TabItem], label: Text, @ViewBuilder content: @escaping () -> Content){
        self.tabItems = tabItems
        self.label = label
        selectedIndex = selection
        self.content = content
        
    }
    
    var body: some View {
        return VStack(alignment: .center, spacing: 0) {
            Picker(selection: self.selectedIndex ?? Binding.constant(0), label: self.label){
                ForEach(TabItem.allCases, id: \.self){ tab in
                    Text(tab.title).tag(tab.rawValue)
                }
            }
            self.content()
        }
    }
    
    enum TabItem: Int, CaseIterable {
        case activity = 0
        case playQueue = 1
        case library = 2
        
        var title: String {
            switch self {
            case .activity:
                return "Activity"
            case .playQueue:
                return "Playing ●"
            case .library:
                return "Library"
            }
        }
        
        func view<V: MusicroomTabView>(room: Musicroom, viewType: V.Type) -> V {
            switch self {
                case .activity:
                    return viewType.init(room: room)
                case .playQueue:
                    return viewType.init(room: room)
                case .library:
                    return viewType.init(room: room)
            }
        }
        
    }
}

struct MusicroomView_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
