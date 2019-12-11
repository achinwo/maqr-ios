//
//  MusicroomList.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore
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
                    logger.debug("Activity: \(result)")
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
        List(appState.musicrooms) { (room: Musicroom) in
            NavigationLink(destination: MusicroomView(room: room)) {

                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading) {

                        ImageStore.shared.image(name: "party-people")
                            .resizable()
                            .frame(width: UIScreen.main.bounds.width - 40, height: 220, alignment: .center)
                        .cornerRadius(10)

                        HStack(alignment: .lastTextBaseline) {
                            Text(verbatim: room.name).font(.title)
                            Spacer()
                            
                            Text("By \(room.createdBy?.obj?.name ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }.contextMenu {
                            
                            Button(action: {
                                self.appState.api.delete(room)
                                    .catch() { error in
                                        logger.error("[MusicroomList] delete error: \(error)")
                                }
                                    .always() {
                                        self.appState.fetchMusicrooms()
                                }
                            }) {
                                Text("Delete").foregroundColor(.red)
                                Image(systemName: "minus.circle")
                            }
                        }
                        
                        Text(room.details).font(.body).lineLimit(4)
                        Divider()
                    }
                    //Text("Home").background(Color.red)
                    
                }
            }
        }
        .navigationBarTitle(Text("Joli"), displayMode: .large)
        .onAppear() {
            logger.debug("[Musicroom] fetchMusicrooms")
            self.appState.fetchMusicrooms()
                .catch() { error in
                    logger.error("[Musicroom] fetch Musicrooms error: \(error)")
            }
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
