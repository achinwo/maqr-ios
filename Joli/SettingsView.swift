//
//  SettingsView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        return VStack {
            
            Button(action: {
                var components = URLComponents(string: "/spotify_login")!
                components.queryItems = [URLQueryItem(name: "platform", value: "ios")]
                
                let url = components.url(relativeTo: self.appState.baseUrl.rawValue.http)!
                
                UIApplication.shared.open(url)
            }) {
                HStack(alignment: .center) {
                    Spacer()
                    
                    if self.appState.spotifyAuthorizationInProgress {
                        ActivityIndicator(isAnimating: self.appState.spotifyAuthorizationInProgress) { (indicator: UIActivityIndicatorView) in
                            indicator.color = .white
                            indicator.hidesWhenStopped = true
                            //Any other UIActivityIndicatorView property you like
                        }
                    }
                    
                    Text("Spotify Authorize").foregroundColor(Color.white).bold()
                    Spacer()
                }
            }.padding()
                .background(Color.green)
                .cornerRadius(CGFloat(4.0))
        }
        .padding()
        .navigationBarTitle("Setting")
        .navigationBarItems(trailing: Button(action: { self.appState.isSettingsPresented.toggle() }) {
            Image(systemName: "xmark")
            Text("Close")
        })
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
