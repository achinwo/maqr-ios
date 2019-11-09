//
//  TracksSearchView.swift
//  Joli
//
//  Created by Anthony Chinwo on 08/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi


struct TrackView: View {
    @EnvironmentObject var appState: AppState
    var track: Track
    
    @State var image: Image?
    var spotifyDevice: JoliApi.SpotifyDevice? {
        return self.appState.spotifyDevice
    }
    
    
    var body: some View {
        HStack(alignment: VerticalAlignment.top) {
            
            CircleImage(image: image).padding()
            
            VStack(alignment: .leading) {
                Text(track.title ?? track.name!)
                    .font(.title)
                
                Text("By \(track.artistName ?? "None")")
                    .font(.subheadline)
            }
        }
        .onTapGesture {
            print("currect device: \(String(describing: self.spotifyDevice))")
            self.track.play(deviceId: self.spotifyDevice?.id)
        }
        .onAppear(){
            
            self.appState.fetchedImage(url: self.track.thumbnailUrl!)
                .then() { (image: Image?) in
                    self.image = image
            }
        }
    }
}

struct SearchField: View {
    
    @EnvironmentObject var appState: AppState
    @State private var showCancelButton: Bool = false
    
    var body: some View {

        TextField("search", text: self.$appState.searchText, onEditingChanged: { (isEditing:Bool) -> Void in
            self.showCancelButton = true
            print("[TrackSearchView] cancel: \(self.showCancelButton)")
        }) { () -> Void in
            print("onCommit")
        }//.foregroundColor(.primary)
    }
    
}

struct TrackSearchView: View {
    @State var tracks: [Track] = []
    @State private var showCancelButton: Bool = false
    
    @EnvironmentObject var appState: AppState
    
    func searchControl() -> some View {
        return HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                
                TextField("search", text: self.$appState.searchText, onEditingChanged: { (isEditing:Bool) -> Void in
                    self.showCancelButton = true
                    print("[TrackSearchView] cancel: \(self.showCancelButton)")
                    
                }) { () -> Void in
                    print("onCommit")
                }.foregroundColor(.primary)

                Button(action: { () -> Void in
                    self.appState.searchText = ""
                    print("[TrackSearchView] cancel: \(self.appState.searchText)")
                }) {
                    Image(systemName: "xmark.circle.fill").opacity(self.appState.searchText == "" ? 0.0 : 1.0)
                }
            }
            .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
            .foregroundColor(.secondary)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10.0)
            .onAppear(){
                print("changed: \(self.appState.searchText)")

//                self.appState.api.searchTracks(q: "killin")
//                    .then() { tracks in
//
//                        self.tracks = tracks
//                        print("tracks: \(tracks)")
//                }
            }
            
            if showCancelButton  {
                Button("Cancel") {
                    UIApplication.shared.endEditing(true) // this must be placed before the other commands here
                    self.appState.searchText = ""
                    self.showCancelButton = false
                }
                .foregroundColor(Color(.systemBlue))
            }
        }
        .padding(.horizontal)
            .navigationBarHidden(showCancelButton) // .animation(.default) // animation does not work properly
    }
    
    var body: some View {
        NavigationView {
            VStack {
                self.searchControl()
                
                List {
                    // Filtered list of names
                    ForEach(self.appState.trackSearchResult) { (track: Track) in
                        TrackView(track: track)
                    }
                }
                .navigationBarTitle(Text("Search"))
                .resignKeyboardOnDragGesture()
            }
        }.onAppear(){
            print("Thing appeared")
            
        }
    }
}


extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(force)
    }
}

struct ResignKeyboardOnDragGesture: ViewModifier {
    var gesture = DragGesture().onChanged{_ in
        UIApplication.shared.endEditing(true)
    }
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

extension View {
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}

