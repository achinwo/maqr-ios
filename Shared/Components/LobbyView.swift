//
//  LobbyView.swift
//  Joli
//
//  Created by Anthony Chinwo on 05/11/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi
import Promises

public struct LobbyView: JoliView {
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    
    @Binding var liveTracks: [Spotify.Track]
    @Binding var playrooms: [Musicroom]
    @Binding var isLoading: Bool
    let onPlayroomSelected: ((Playroom) -> Void)?
    
    
    public var body: some View {
        GeometryReader() { proxy in
            VStack(){
                
                Divider()
                    .opacity(self.isLoading ? 1 : 0)
                
                if !self.liveTracks.isEmpty {
                    
                    let header = HStack(){
                        Text("Live Tracks")
                            .font(Font.largeTitle.weight(.thin))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Section(header: header) {
                        ForEach(self.liveTracks, id: \.uri) { (track: Spotify.Track) in
                            TrackView2(track: .constant(track), useDynamicColors: true)
                                .frame(height: 64)
                                .id(track.uri)
                        }
                    }
                }
                
                if !self.playrooms.isEmpty {
                    let header = HStack(){
                        Text("Playrooms")
                        Spacer()
                        Button() {
                            print("[LobbyView] made")
                            self.appCoordinator.globalModalSubject.send(.playroomCreate)
                        } label: {
                            Image(systemName: "plus").font(Font.title.weight(.thin))
                        }
                    }
                    .font(Font.largeTitle.weight(.thin))
                    .foregroundColor(.secondary)
                    
                    let columns = [
                        //GridItem(.fixed(proxy.size.width / 2 - space), spacing: space),
                        //GridItem(.fixed(proxy.size.width / 2 - space), spacing: space)
                        GridItem(),
                        GridItem()
                    ]
                    
                    Section(header: header) {
                        LazyVGrid(columns: columns) {
                            ForEach(self.playrooms, id: \.id) { room in
                                SpotifyItemView(item: room,
                                                images: [],
                                                titleKeyPath: \.name,
                                                subtitleKeyPath: \.details)
                                    .frame(height: 64)
                                    .onTapGesture {
                                        self.onPlayroomSelected?(room)
                                    }
                                    //.background(Color.yellow)
                                    .id(room.id)
                            }
                        }
                    }
                    
                }
                
                //                                Group(){
                //                                    Color.white
                //                                }
                //                                .frame(width: screenWidth, height: screenWidth)
                
                Divider().padding(.vertical, Sizing.xxLarge)
                
                let header = HStack(){
                    Label(){
                        Text("Settings")
                    } icon: {
                        Image(systemName: "gearshape")
                            .font(Font.title.weight(.thin))
                    }
                    .foregroundColor(.secondary)
                    .font(Font.largeTitle.weight(.thin))
                    
                    Spacer()
                }
                
                Section(header: header) {
                    HStack(alignment: .top){
                        VStack(alignment: .leading) {
                            Text("Autoplay")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Begin playback immediately when joining a playroom")
                                .font(.footnote)
                                .foregroundColor(Color.secondary)
                        }
                        .frame(maxWidth: screenWidth / 2)
                        
                        Spacer()
                        
                        Toggle("Autoplay", isOn: .constant(false))
                            .labelsHidden()
                    }
                }
                .id("settings")
                
            }
            //.frame(height: proxy.size.height)
        }
    }
    
}

//struct LobbyView_Previews: PreviewProvider {
//    static var previews: some View {
//        LobbyView()
//    }
//}
