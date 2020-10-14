//
//  ContentView.swift
//  JoliClip
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import JoliCore
import StoreKit

struct ContentView: View {
    
    @State var showRecommended = false
    @EnvironmentObject var mgr: AppCoordinator
    
    var body: some View {
        return NavigationView(){
            VStack() {
                
                
                #if APPCLIP
                Button("Show Recommended App") {
                    self.showRecommended.toggle()
                }
                .appStoreOverlay(isPresented: $showRecommended) {
                    SKOverlay.AppConfiguration(appIdentifier: "1440611372", position: .bottom)
                }
                #endif
                        
                Text("Browse Songs").font(.title)
                ScrollView(){
                    TrackList(tracks: .constant(SEED_DATA.tracks), activeDevice: .constant(nil))
                        .onTapGesture {
                            self.mgr.sheet.show() {
                                print("Partial sheet dismissed")
                            } content: {
                                Text("This is a Partial Sheet")
                            }
                        }
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationTitle("Tracks")
        .navigationViewStyle(DefaultNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
