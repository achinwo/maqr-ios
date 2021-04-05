//
//  SpotifyConnectButton.swift
//  Joli
//
//  Created by Anthony Chinwo on 05/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI

public struct SpotifyConnectButton: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public var contentView: some View {
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

struct SpotifyConnectButton_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyConnectButton()
    }
}
