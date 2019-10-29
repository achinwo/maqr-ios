//
//  MusicroomDetail.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi


struct CircleImage: View {
    var image: Image?

    var body: some View {
        if let img = self.image {
            return img
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
        } else {
            return Image(systemName: "Prohibit")
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
        }
        
    }
}

struct TrackView: View {
    
    @State var image: Image?
    var track: Track
    
    
    var body: some View {
        HStack(alignment: .top) {
            
            CircleImage(image: image).padding()

            VStack(alignment: .leading) {
                Text(track.title)
                .font(.title)
                
                Text("By \(track.artistName)")
                    .font(.subheadline)
            }
        }
        .onTapGesture {
            self.track.play()
        }
        .onAppear(){
            
            guard let url = URL(string: self.track.thumbnailUrl) else {
                print("failed to load \(self.track.thumbnailUrl)")
                return
            }
            
            let task: URLSessionDataTask = URLSession.shared.dataTask(with: url) { (data, resp, error) in
                guard let data = data, let img = UIImage(data: data) else {
                    print("failed to load \(self.track.thumbnailUrl)")
                    return
                }
                
                self.image = Image(uiImage: img)
            }
            task.resume()
        }
    }
}

struct MusicroomDetail: View {
    @EnvironmentObject var appState: AppState
    var room: Musicroom
    
    var tracks: [Track] {
        guard let id = room.id else {
            return []
        }
        
        return appState.tracksByMusicrooms[id] ?? []
    }

    var body: some View {
        List(tracks) { track in
            TrackView(track: track)//.background(Color.pink)
            Spacer()
        }
        //.navigationBarTitle(Text(verbatim: room.name), displayMode: .inline)
    }
}

//struct MusicroomDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomDetail()
//    }
//}
