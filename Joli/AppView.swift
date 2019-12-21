//
//  AppView.swift
//  Joli
//
//  Created by Anthony Chinwo on 11/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

typealias Size = ()

struct ViewOffset {
    
    var x: CGFloat?
    var y: CGFloat?
    
    func computedSize(geometry: GeometryProxy) -> CGSize {
        return CGSize(width: x ?? geometry.size.width, height: y ?? geometry.size.height)
    }
    
}


struct AppView: View {
    
    @EnvironmentObject var appState: AppState
    
    @State var settingsViewOffset: ViewOffset = ViewOffset(x: nil, y: 0)
    @State var settingsViewOffsetSize = CGSize(width: 0, height: 0)
    @State var mainViewOffset = CGSize(width: 0, height: 0)
    @State var activityIdx = 0
    
    @State var isLogonViewPresented = false
    @State var isLogoutAlertPresented = false
    @State var isRoomCreateFormPresented = false
    @State var dragging = false
    
    @State var heightOffset: CGFloat = 0
    
    var body: some View {
        let settingsOffsetWidth: CGFloat? = appState.isSettingsPresented ? 0 : nil
        
        let logonButtonAction = {
            if self.appState.auth == nil {
                self.isLogonViewPresented = true
            } else {
                self.isLogoutAlertPresented = true
            }
        }
        
        
        let gesture = DragGesture(minimumDistance: 0)
            .onEnded() { val in
                self.dragging = false
        }.onChanged() { changeVal in
            self.dragging = true
            self.heightOffset = changeVal.translation.height
        }
        
        return GeometryReader(){ geometry in
            ZStack(alignment: .bottomTrailing) {
                
                NavigationView {
                        MusicroomList()
                            .sheet(isPresented: self.$isLogonViewPresented) {
                                NavigationView {
                                    LogOnView() { cancelled in
                                        logger.debug("[LogOnView] view dismissed")
                                    }
                                }.environmentObject(self.appState)
                        }
                    .navigationBarItems(leading:
                        Button(action: logonButtonAction) {
                            Text("\(self.appState.auth == nil ? "Sign In" : self.appState.auth!.user.name)")
                        }.alert(isPresented: self.$isLogoutAlertPresented) {
                            Alert(title: Text("Sign out?").font(.title),
                                  message: Text("\(self.appState.auth!.user.name)").font(.subheadline),
                                  primaryButton: .cancel(),
                                  secondaryButton: .destructive(Text("Yes")) {
                                    self.appState.api.auth = nil
                                }
                            )
                        }
                        , trailing:
                        HStack(){
                            NavigationLink(destination: VStack() { RoomCreateFormView() }) {
                                Image(systemName: "plus")
                            }.padding()
                            Button(action: {
                                self.appState.isSettingsPresented.toggle()
                            }) {
                                Image(systemName: "gear")
                                    
                            }.padding()
                        }
                        
                    )
                }
                .animation(.spring())
                
                NavigationView {
                    SettingsView()
                }
                .animation(.spring())
                .offset(CGSize(width: settingsOffsetWidth ?? geometry.size.width, height: 0))
                
                VStack(alignment: .leading){
                    HStack(alignment: .center){
                        if self.appState.currentlyPlayingContent != nil
                        && self.appState.imagesByUrl[self.appState.currentlyPlayingTrack!.albumCoverUrl] != nil {
                            self.appState.imagesByUrl[self.appState.currentlyPlayingTrack!.albumCoverUrl]?
                                .resizable().frame(width: 116, height: 116, alignment: .bottomLeading)
                        }
                        
                        VStack(alignment: .leading, spacing: 0){
                            HStack(alignment: .bottom){

                                Text(self.appState.currentlyPlayingTrack?.name ?? "No Name")
                                    .font(.title)//.background(Color.blue)
                            }
                            HStack(alignment: .top){
                                VStack(alignment: .leading){
                                    Text(self.appState.currentlyPlayingTrack == nil ? "" : "By \(self.appState.currentlyPlayingTrack!.artistName)").font(.subheadline)
                                    
                                    HStack(alignment: .center){
                                        Image(systemName: "hand.thumbsup")
                                        Text("4")
                                        
                                        if self.appState.spotifyDevice != nil {

                                            Text("•").font(.title)
                                            
                                            Image(systemName: "hifispeaker")
                                            Text(self.appState.spotifyDevice!.type.rawValue)
                                            .lineLimit(1)
                                                .font(.footnote)
                                        }
                                    }
                                }
                                Spacer()
                                if self.appState.currentlyPlayingTrack != nil && self.appState.currentlyPlayingContent!.isPlaying {
                                    Image(systemName: "pause.circle").resizable().padding(.trailing, 10).padding(.bottom, 10)
                                        .frame(width: 64, height: 64, alignment: .bottomLeading)
                                        .onTapGesture {
                                            self.appState.pausePlayback()
                                        }
                                }else{
                                    Image(systemName: "play.circle").resizable().padding(.trailing, 10).padding(.bottom, 10)
                                        .frame(width: 64, height: 64, alignment: .bottomLeading)
                                    .onTapGesture {
                                        guard let track = self.appState.currentlyPlayingTrack else {
                                            return
                                        }
                                        self.appState.playTrack(track)
                                    }
                                }
                            }//.background(Color.green)
                        }.frame(width: UIScreen.main.bounds.width - 32 - 116, height: 116, alignment: .bottomLeading)
                        
                    }
                }
                .simultaneousGesture(gesture)
                .frame(width: UIScreen.main.bounds.width - 32, height: 116, alignment: .bottomLeading)
                .padding(.trailing, 8)
                .background(Color.yellow)
                    .opacity(0.95)
                .shadow(radius: 8)
                    
                .cornerRadius(10)
                .animation(.easeInOut)
                    .offset(CGSize(width: -16, height: self.dragging ? self.heightOffset : self.appState.currentlyPlayingTrack != nil && self.appState.currentlyPlayingContent!.isPlaying ? 0 : 150))
                .edgesIgnoringSafeArea(.bottom)
                
            }
            
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
