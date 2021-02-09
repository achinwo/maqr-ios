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

public struct SpotifyConnectButton: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public var body: some View {
        Button() {
            self.appCoordinator.authorizeSpotify()
        } label: {
            
            HStack() {
                Spacer()
                Image(uiImage: #imageLiteral(resourceName: "Spotify_Icon_RGB_Green.png"))
                    .resizable()
                    .frame(width: 64, height: 64, alignment: .center)
                VStack(alignment: .leading){
                    Text("Connect to Spotify ")
                        .font(.subheadline)
                        .foregroundColor(Color.green.opacity(0.9))
                        + Text("Premium")
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                    Text("Access Spotify's vast library of tracks, podcasts, shows, and more.")
                        .font(Font.caption.weight(.light))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.7), lineWidth: 2)
        )
        .background(Color.green.opacity(0.1))
    }
    
}

public struct LobbyView: JoliView {
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    
    @Binding var liveTracks: [Spotify.Track]
    @Binding var playrooms: [Musicroom]
    @Binding var filterText: String
    @Binding var isLoading: Bool
    let onPlayroomSelected: ((Musicroom) -> Void)?
    
    @SceneStorage("refreshTokenSpotify") var refreshTokenSpotify: String = .empty
    @State var bannerDisplayedAt: Date? = nil
    
    @State var auths: [Auth] = []
    @State var activeSessionId: String? = nil
    
    public var body: some View {
        GeometryReader() { proxy in
            VStack(alignment: .center){
                
                Divider()
                    .opacity(self.isLoading ? 1 : 0)
                
                Group(){
                    if self.auths.isEmpty && self.bannerDisplayedAt != nil {
                        SpotifyConnectButton()
                        .padding()
                    }
                }
                .animation(.easeInOut)
                
                if !self.liveTracks.isEmpty {
                    
                    let header = HStack(){
                        VStack(alignment: .leading){
                            Text("Live Tracks")
                                .font(Font.largeTitle.weight(.thin))
                                .foregroundColor(.secondary)
                            Text("See whats trending live — tap album art to follow along")
                                .lineLimit(2)
                                .font(Font.subheadline.weight(.light))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, Sizing.small)
                    
                    Section(header: header) {
                        ForEach(self.liveTracks, id: \.uri) { (track: Spotify.Track) in
                            TrackView2(track: .constant(track), useDynamicColors: false) { (track, playStates, colors) in
                                    VStack() {
//                                        Button() {
//                                            //appCoordinator.
//                                        } label: {
//                                            Text("𖧊 Follow").font(Font.subhealine)
//                                        }
//                                        //.padding(.all, 3)
//                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray))
//                                        .disabled(true)
                                    }
                                }
                                .frame(height: 64)
                                .id(track.uri)
                        }
                    }
                }
                
                if !self.playrooms.isEmpty {
                    let header = VStack(alignment: .leading) {
                            
                            HStack(alignment: .top){
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
                        
                            Text("Listen together and vote up your favorite tracks")
                                .lineLimit(2)
                                .font(Font.subheadline.weight(.light))
                                .foregroundColor(.primary)
                    }
                    .padding(.bottom, Sizing.small)
                    
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
                                                images: room.images,
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
                            .padding()
                    }
                    .padding(.top)
                    
                    VStack(alignment: .leading){
                        HStack(){
                            Text("Spotify Accounts")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button() {
                                self.appCoordinator.spotifyAuthRequestedAt = Date()
                            } label: {
                                Image(systemName: "plus")
                                    .font(Font.title2.weight(.thin))
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        
                        if self.auths.isEmpty {
                            SpotifyConnectButton().padding()
                        }
                        
                        ForEach(self.auths, id: \.session.token) { auth in
                            HStack() {
                                
                                let color = self.activeSessionId == auth.session.token ? Color.green : Color.gray
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(auth.user.name).font(.headline).foregroundColor(color)
                                    Text(auth.user.ranking.description.lowercased()).font(.footnote).foregroundColor(Color.gray)
                                }
                                Spacer()
                                Image(systemName: "minus")
                                    .font(Font.largeTitle.weight(.thin))
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .padding([.top, .horizontal])
                        }
                    }
                    .padding(.top)
                    .onReceive(self.appCoordinator.authsSubject) { auths in
                        self.auths = auths
                    }
                    
                }
                .id("settings")
                
            }.padding()
            //.frame(height: proxy.size.height)
        }
        .onReceive(appCoordinator.authSubject) { auth in
            self.refreshTokenSpotify = auth?.user.refreshTokenSpotify ?? .empty
        }
        .onReceive(appCoordinator.$activeSessionToken) { activeSessionId in
            self.activeSessionId = activeSessionId
        }
        .onAppear() {
            
            guard bannerDisplayedAt == nil else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                self.bannerDisplayedAt = Date()
            }
        }
    }
    
}

public extension Musicroom {
    
    var images: [Spotify.Image] {
        return [self.imageLarge, self.imageSmall, self.imageMedium].compactMap() { url in
            guard let url = url else { return nil }
            
            return Spotify.Image(url: url)
        }
    }
    
}

//struct LobbyView_Previews: PreviewProvider {
//    static var previews: some View {
//        LobbyView()
//    }
//}
