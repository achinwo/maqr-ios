//
//  MusicroomView.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

struct MusicroomView: View {
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
                }
//                                ,trailing:
//                Button(action: {
//                    self.isSearching = true
//                }) {
//                    Text("Search")
//                }.sheet(isPresented: self.$isSearching){
//                    TrackSearchView().environmentObject(self.appState)
//            }
        ).onAppear() {
            self.appState.activeRoom = self.room
        }
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

//struct MusicroomView_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomView()
//    }
//}
