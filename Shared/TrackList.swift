//
//  TrackList.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import UIImageColors

public extension UIImageColors {
    
    var primaryColor: Color {
        return Color(primary)
    }
    
    var backgroundColor: Color {
        return Color(background)
    }
    
    var secondaryColor: Color {
        return Color(secondary)
    }
    
    var detailColor: Color {
        return Color(detail)
    }
    
}

public struct TrackView2: View {
    
    @State var track: Track
    @State var colors: UIImageColors? = nil
    
    public init(track: Track, colors: UIImageColors? = nil){
        _track = State(initialValue: track)
        self.colors = colors
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            
            NetworkImage(imageURL: URL(string: track.thumbnailUrl)!,
                         placeholderImage: UIImage(systemName: "timelapse")!) { loadedImage in
                
                guard let loadedImage = loadedImage else {
                    return
                }
                
                DispatchQueue.global(qos: .background).async {
                    colors = loadedImage.getColors()
                        
                    DispatchQueue.main.async {
                        self.colors = colors
                    }
                }
            }.padding(.all, 2)
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .foregroundColor(colors?.primaryColor ?? Color.primary)
                    .animation(.easeInOut)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    
                    Text(track.artistName)
                        .foregroundColor(colors?.secondaryColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(.subheadline)
                    Text("•").foregroundColor(colors?.detailColor ?? Color.primary)
                    Text("2003")
                        .foregroundColor(colors?.detailColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(.subheadline)
                    Spacer()
                }
            }
        }.background(colors?.backgroundColor ?? Color.clear)
    }
}

public struct TrackList: View {
    
    @State var tracks: [Track]
    
    public init(tracks: [Track]){
        self._tracks = State(initialValue: tracks)
    }
    
    public var body: some View {
        return ScrollView(.vertical, showsIndicators: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/) {
            VStack(alignment: .center, spacing: 0) {
                ForEach(tracks) { track in
                    TrackView2(track: track)
                }
            }
        }
    }
    
}

struct TrackList_Previews: PreviewProvider {
    
    static var previews: some View {
        TrackList(tracks: SEED_DATA.tracks)
    }
    
}
