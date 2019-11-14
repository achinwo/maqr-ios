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
        TrackSearchView()
    }
}

struct ActivityView: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Text("Activity")
            .onAppear() {
                
                self.appState.api.subscribe(subject: "activity_feed") { result in
                    print("Activity: \(result)")
                }
        }
    }
}

struct MusicroomList: View {
    
    @EnvironmentObject var appState: AppState
    @State var showingDetail = false
    
    init() {
        // To remove all separators including the actual ones:
        UITableView.appearance().separatorStyle = .none
    }
    
    var body: some View {
        //NavigationView {
            List(appState.musicrooms) { room in
                NavigationLink(destination: MusicroomView(room: room)) {

                    ZStack(alignment: .bottomTrailing) {
                        VStack {
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
                        //Text("Home").background(Color.red)
                        
                    }
                }.onAppear() { self.appState.fetchTracks(room) }
            }
    
            .navigationBarTitle(Text("Joli"), displayMode: .large)
            
    //    }
    .onAppear() {
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
