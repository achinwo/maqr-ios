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
                Button("Show Recommended App") {
                            self.showRecommended.toggle()
                        }
                        
                Text("Browse Songs").font(.title)
                TrackList(tracks: SEED_DATA.tracks)
                    .onTapGesture {
                        self.mgr.sheet.show() {
                            print("Partial sheet dismissed")
                        } content: {
                            Text("This is a Partial Sheet")
                        }
                    }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationTitle("Tracks")
        .navigationViewStyle(DefaultNavigationViewStyle())
        .appStoreOverlay(isPresented: $showRecommended) {
            SKOverlay.AppConfiguration(appIdentifier: "1440611372", position: .bottom)
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
