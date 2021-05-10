//
//  SkipVoteView.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

public struct SpotifyItemView<Item>: View {
    
    @State var item: Item
    let images: [Spotify.Image]?
    let titleKeyPath: KeyPath<Item, String>
    let subtitleKeyPath: KeyPath<Item, String>
    
    public var body: some View {
        HStack(){
            NetworkImage(string: images?.smallestImage?.url){
                Image(systemName: "music.note.list")
                    .resizable()
                    .padding()
                    .foregroundColor(.primary)
                    .background(Color.systemGray)
                    .frame(width: 64, height: 64, alignment: .bottomLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
            }
            .frame(width: 64, height: 64, alignment: .bottomLeading)
            .clipped()

            VStack(alignment: .leading){
                Text(item[keyPath: titleKeyPath]).font(Font.subheadline)

                Text(item[keyPath: subtitleKeyPath])
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}


let spotifyEngine = Search.Engine("FakeSpotify", categories: [.tracks, .playlists, .artists, .shows, .episodes, .albums])

let joliEngine = Search.Engine("Joli", categories: .playrooms)

public enum SearchResult {
    case playrooms(Search.Query, Search.Engine, [Musicroom])
    case spotifyResult(Search.Query, Search.Engine, Spotify.SearchResult)
}

public struct ArtistView: View {
    @State var artist: Spotify.Artist
    
    public var body: some View {
        HStack(){
            NetworkImage(string: artist.images?.smallestImage?.url){
                PersonGenericImage()
                    .frame(width: 64, height: 64, alignment: .bottomLeading)
            }
            .frame(width: 64, height: 64, alignment: .bottomLeading)
            .clipShape(Circle())
            
            VStack(alignment: .leading){
                Text(artist.name).font(.body)
                
                if let genres = artist.genres {
                    Text(genres.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}


struct SkipVoteView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct SkipVoteView_Previews: PreviewProvider {
    static var previews: some View {
        SkipVoteView()
    }
}
