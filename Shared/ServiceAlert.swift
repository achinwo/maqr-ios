//
//  ServiceAlert.swift
//  Joli
//
//  Created by Anthony Chinwo on 13/01/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI

enum ServiceAlert: Int {
    
    case serverConnectionLost = 0
    case loginRequired = 1
    case spotifyWebAuthRequired = 2
    
    var message: String {
        switch self {
        case .serverConnectionLost:
            return "Connection lost"
        case .spotifyWebAuthRequired:
            return "Connect with Spotify"
        case .loginRequired:
            return "Login"
        }
    }
    
    func view(_ appState: AppState) -> some View {
        var retryText: String
        switch appState.api.wsClient.connectionState {
        case .reconnecting(_):
            let date = Date().addingTimeInterval(Double(appState.serverReconnectState.countdown))

            // ask for the full relative date
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short

            // get exampleDate relative to the current date
            let dateString = formatter.localizedString(for: date, relativeTo: Date())

            retryText = appState.serverReconnectState.countdown > 1 ? "retrying \(dateString)..." : ""
        default:
            retryText = "retry aborted"
        }
        return HStack(alignment: .center) {
            
            if self == .spotifyWebAuthRequired {
                ImageStore.shared.image(name: "Spotify_Icon_RGB_Green")
                    .resizable().frame(width: 32, height: 32, alignment: .center)
                    .padding(.init(top: 4, leading: 16, bottom: 4, trailing: 4))
            } else if self == .serverConnectionLost {
                Image(systemName: "bolt.slash")
                    .resizable().frame(width: 32, height: 32, alignment: .center)
                    .padding(EdgeInsets.init(top: 4, leading: 16, bottom: 4, trailing: 4))
                    .foregroundColor(.gray)
            }
            else if self == .loginRequired {
                Image(systemName: "link.circle.fill")
                    .resizable().frame(width: 32, height: 32, alignment: .center)
                    .padding(EdgeInsets.init(top: 4, leading: 16, bottom: 4, trailing: 4))
                    .foregroundColor(.blue)
            }
            
            Text("\(self.message)\(self == .serverConnectionLost ? "\(retryText.isEmpty ? "" : ",") \(retryText)" : "")")
                .font(.subheadline).foregroundColor(.gray)//.padding()
            Spacer()
            
            if self == .spotifyWebAuthRequired {
                Button(action: {
                    appState.spotifyDelegate.requestSpotifyAccess()//openSpotifyWebAuthorization()
                }) {
                    
                    if appState.spotifyAuthorizationInProgress {
                        ActivityIndicator(isAnimating: appState.spotifyAuthorizationInProgress) { (indicator: UIActivityIndicatorView) in
                            indicator.color = .green
                            indicator.hidesWhenStopped = true
                        }.padding(.leading, 6)
                    }
                    
                    Text("Connect").font(.subheadline)
                    .foregroundColor(.green)
                    .padding(6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(Color.green, lineWidth: 1.2)
                )
                .padding(.trailing, 16)
            } else if self == .serverConnectionLost {
                Button(action: {
                    appState.api.wsClient.connectionState = .reconnecting(0)
                }) {
                    
                    Text("Retry Now").font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(Color.primary, lineWidth: 1.2)
                )
                .padding(.trailing, 16)
            } else if self == .loginRequired {
                Button(action: {
                    appState.isLogonViewPresented = true
                }) {
                    
                    Text("Sign In").font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(Color.blue, lineWidth: 1.2)
                )
                .padding(.trailing, 16)
            }
        }
    }
}

extension Set where Element == ServiceAlert {
    
    var sortedByImportance: [ServiceAlert] {
        return self.sorted() { $0.rawValue < $1.rawValue }
    }
    
}
