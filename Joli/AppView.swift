//
//  AppView.swift
//  Joli
//
//  Created by Anthony Chinwo on 11/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

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
    @EnvironmentObject var currentlyPlaying: AppCurrentlyPlayingState
    
    @State var settingsViewOffset: ViewOffset = ViewOffset(x: nil, y: 0)
    @State var settingsViewOffsetSize = CGSize(width: 0, height: 0)
    @State var mainViewOffset = CGSize(width: 0, height: 0)
    @State var activityIdx = 0
    
    
    @State var isLogoutAlertPresented = false
    @State var isRoomCreateFormPresented = false
    @State var dragging = false
    
    @State var heightOffset: CGFloat = 0
    
    static let DEFAULT_PLAY_WIDGET_HIEGHTOFFSET: CGFloat = 200
    
    var body: some View {
        let settingsOffsetWidth: CGFloat? = appState.isSettingsPresented ? 0 : nil
        
        let logonButtonAction = {
            if self.appState.auth == nil {
                self.appState.isLogonViewPresented = true
            } else {
                self.isLogoutAlertPresented = true
            }
        }
        
        let roomsView = NavigationView {
                MusicroomList()
                    .sheet(isPresented: self.$appState.isLogonViewPresented) {
                        NavigationView {
                            LogOnView() { cancelled in
                                logger.debug("[LogOnView] view dismissed")
                            }
                        }.environmentObject(self.appState).environmentObject(self.appState.keyboardState)
                }
            .navigationBarItems(leading:
                Button(action: logonButtonAction) {
                    
                    if self.appState.auth != nil {
                        UserProfileView(user: self.appState.auth!.user.builder())
                    } else {
                        Text("Sign In")
                    }
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
        
        return GeometryReader(){ geometry in
            ZStack(alignment: .bottomTrailing) {
                roomsView.animation(.spring())
                
                NavigationView {
                    SettingsView()
                }
                .animation(.spring())
                .offset(CGSize(width: settingsOffsetWidth ?? geometry.size.width, height: 0))
                
                self.currentPlayingView
                
            }
            //.colorScheme(.dark)
        }
        .colorScheme(.light)
    }
        
    var currentPlayingView: some View {
        let gesture = DragGesture(minimumDistance: 10)
            .onEnded() { val in
                self.dragging = false
                self.heightOffset = val.translation.height > 50 ? AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET : val.location.y
            }
            .onChanged() { changeVal in
                self.dragging = true
                self.heightOffset = changeVal.location.y
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
                self.appState.triggerAndClearDeviceCallbacks(cancelled: false)
            }
        }
        
        if buttons.isEmpty && !self.appState.deviceReadyCallbacks.isEmpty {
            buttons.append(.default(Text("iPhone")) {
                let device = Spotify.Device(name: "iPhone", type: Spotify.DeviceType.smartphone, isActive: true, id: "__this_phone__")
                self.appState.triggerAndClearDeviceCallbacks(device: device, cancelled: false)
            })
        }
        
        buttons.append(.cancel() {
            self.appState.triggerAndClearDeviceCallbacks(cancelled: true)
        })
        
        var width: CGFloat = .zero
            
        if self.currentlyPlaying.progressPct > 0 {
            width = CGFloat(self.currentlyPlaying.progressPct / 100.0) * (UIScreen.main.bounds.width - 142)
        }
        
        var deviceChooserMessage = Text(self.appState.spotifyDevices.count == 0 ? "You have no connected Spotify devices" : "Spotify connected devices")
        
        if self.appState.spotifyDevices.count == 0 {
            deviceChooserMessage = deviceChooserMessage.foregroundColor(.red).bold()
        }
        
        return VStack(alignment: .leading){
                HStack(alignment: .center, spacing: 4){
                    if self.currentlyPlaying.content != nil
                        && self.appState.imagesByUrl[self.currentlyPlaying.track!.albumCoverUrl] != nil {
                        self.appState.imagesByUrl[self.currentlyPlaying.track!.albumCoverUrl]?
                            .resizable().frame(width: 116, height: 116, alignment: .bottomLeading)
                    }
                    
                    VStack(alignment: .leading, spacing: 0){
                        
                        HStack(alignment: .top){

                            Text(self.currentlyPlaying.track?.name ?? "No Name")
                                .font(.headline)//.background(Color.blue)
                        }
                        HStack(alignment: .top){
                            VStack(alignment: .leading){
                                Text(self.currentlyPlaying.track == nil ? "" : "By \(self.currentlyPlaying.track!.artistName)").font(.subheadline)
                                
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
                            if self.currentlyPlaying.track != nil && self.currentlyPlaying.content!.isPlaying {
                                Image(systemName: "pause.circle").resizable().padding(.trailing, 10).padding(.bottom, 10)
                                    .frame(width: 64, height: 64, alignment: .bottomLeading)
                                    .onTapGesture {
                                        self.appState.pausePlayback()
                                    }
                            }else{
                                Image(systemName: "play.circle").resizable().padding(.trailing, 10).padding(.bottom, 10)
                                    .frame(width: 64, height: 64, alignment: .bottomLeading)
                                .onTapGesture {
                                    guard let track = self.currentlyPlaying.track else {
                                        return
                                    }
                                    self.appState.playTrack(track)
                                }
                            }
                        }//.background(Color.green)
                        
                        ZStack(alignment: .leading){
                            Color.gray.frame(width: UIScreen.main.bounds.width - 142, height: 4, alignment: .leading)
                                
                            Color.green.frame(width: width, height: 4, alignment: .leading)
                                .cornerRadius(1)
                                .animation(.spring())
                        }.offset(x: -4, y: 0)
                        
                    }.frame(width: UIScreen.main.bounds.width - 32 - 116, height: 116, alignment: .bottomLeading)
                    
                }
            }
            .actionSheet(isPresented: self.$appState.isDeviceChooserPresented){
                ActionSheet(title: Text("Audio Device"),
                            message: deviceChooserMessage,
                            buttons: buttons)
            }
             //   .animation(self.dragging ? .none : .easeInOut)
            .simultaneousGesture(gesture)
            .frame(width: UIScreen.main.bounds.width - 32, height: 116, alignment: .bottomLeading)
            .padding(.trailing, 8)
            .background(Color.yellow)
                .opacity(0.95)
            .shadow(radius: 8)
                
            .cornerRadius(10)
            .animation(.easeInOut)
            .offset(self.currentlyPlayingViewOffset)
            .edgesIgnoringSafeArea(.bottom)
        
    }

    var currentlyPlayingViewOffset: CGSize {
        guard let content = currentlyPlaying.content else {
            return CGSize(width: -16, height: AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET)
        }
        
        if self.appState.activeRoom != nil && self.appState.selectedTabIdx == MusicroomTab.playQueue.rawValue {
            return CGSize(width: -16, height: AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET)
        }
        
        if !content.isPlaying {
            return CGSize(width: -16, height: AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET)
        }
        
        return CGSize(width: -16, height: heightOffset)
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
