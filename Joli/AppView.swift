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
    
    var body: some View {
        let settingsOffsetWidth: CGFloat? = appState.isSettingsPresented ? 0 : nil
        
        let logonButtonAction = {
            if self.appState.auth == nil {
                self.isLogonViewPresented = true
            } else {
                self.isLogoutAlertPresented = true
            }
        }
        
        return GeometryReader(){ geometry in
            ZStack(alignment: .bottomTrailing) {
                
                NavigationView {
                    VStack(alignment: .center){
                        
                        NavigationLink(destination: VStack() { RoomCreateFormView() }) {
                            Text("Create Room").padding()
                        }
                        
                        MusicroomList()
                            .sheet(isPresented: self.$isLogonViewPresented) {
                                NavigationView {
                                    LogOnView() { cancelled in
                                        logger.debug("[LogOnView] view dismissed")
                                    }
                                }.environmentObject(self.appState)
                        }
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
                        Button(action: {
                            self.appState.isSettingsPresented.toggle()
                            
                            print("[messageCallbacks] \(self.appState.api.wsClient.messageCallbacks)")
                        }) {
                            Image(systemName: "gear")
                                .padding()
                        }
                    )
                }
                .animation(.spring())
                
                NavigationView {
                    SettingsView()
                }
                .animation(.spring())
                .offset(CGSize(width: settingsOffsetWidth ?? geometry.size.width, height: 0))
            }
            
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
