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

struct MusicroomList: View {
    
    @EnvironmentObject var appState: AppState
    @State var showingDetail = false
    
    init() {
        // To remove all separators including the actual ones:
        UITableView.appearance().separatorStyle = .none
    }
    
    var body: some View {
        return ZStack(alignment: .top) {
            self.roomsListView
            
            if self.appState.alerts.sortedByImportance.first == ServiceAlert.serverConnectionLost {
                VStack(alignment: .leading, spacing: 0) {
                    self.appState.alerts.sortedByImportance.first!.view(self.appState)
                    Divider()
                }
                .alignmentGuide(.top) { d in d[explicit: VerticalAlignment.top] ?? CGFloat.zero }
                .background(Color.white)
//                .frame(width: UIScreen.main.bounds.width,
//                       height: 50, alignment: .center)
                .clipped()
                .animation(.interactiveSpring())
            }
        }
    }
    
    var roomsListView: some View {
        //NavigationView {
        
        let resolveCreatedBy = { (room: Musicroom) -> String in
            var createdBy: String
            
            if let id = room.createdById, let createdByUser = self.appState.usersById[id] {
                createdBy = createdByUser.name
            } else {
                createdBy = "Unknown"
            }
            return createdBy
        }
        
        return List(appState.musicrooms) { (room: Musicroom) in
            NavigationLink(destination: MusicroomView(room: room)) {

                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading) {

                        HStack(alignment: .center){
                            VStack(alignment: .leading) {
                                Text(verbatim: room.name).font(.title)
                                
                                if (self.appState.auth == nil || room.createdById == nil) || self.appState.api.auth!.user.createdById != room.createdById! {
                                    Text(resolveCreatedBy(room))
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(room.details).font(.subheadline).lineLimit(4)
                                
                                HStack(alignment: .firstTextBaseline){
                                    Image(systemName: "music.note")
                                    Text((room.createdById ?? 2) == 2 ? "Grim" : "Afrobeats").font(.footnote)
                                    Text("•").font(.subheadline)
                                    Image(systemName: "headphones")
                                    Text(room.createdById?.description ?? "7")
                                }.foregroundColor(.gray)
                            }
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
                        
                        ImageStore.shared.image(name: "party-people")
                            .resizable()
                            .frame(width: UIScreen.main.bounds.width - 40, height: 220, alignment: .center)
                        .cornerRadius(10)
//                            .overlay(ZStack() {
//
//                                })
                        
                        
                        Divider()
                    }
                    //Text("Home").background(Color.red)
                    
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarTitle("J❍li", displayMode: .large)
        .accentColor(appState.navbarColor)
        .onAppear() {
            logger.debug("[Musicroom❖] fetchMusicrooms")
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

struct MusicroomList_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
