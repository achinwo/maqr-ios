//
//  TracksSearchView.swift
//  Joli
//
//  Created by Anthony Chinwo on 08/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

struct SearchField: View {
    
    @EnvironmentObject var appState: AppState
    @State private var showCancelButton: Bool = false
    
    var body: some View {

        TextField("search", text: self.$appState.searchText, onEditingChanged: { (isEditing:Bool) -> Void in
            self.showCancelButton = true
            logger.debug("[TrackSearchView] cancel: \(self.showCancelButton)")
        }) { () -> Void in
            logger.debug("onCommit")
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
                    
                }) { () -> Void in
                    logger.debug("onCommit")
                }.foregroundColor(.primary)
                    .keyboardType(.alphabet)

                Button(action: { () -> Void in
                    self.appState.searchText = ""
                    logger.debug("[TrackSearchView] cancel: \(self.appState.searchText)")
                }) {
                    Image(systemName: "xmark.circle.fill").opacity(self.appState.searchText == "" ? 0.0 : 1.0)
                }
            }
            .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
            .foregroundColor(.secondary)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10.0)
            .font(.title)
            .onAppear(){
                logger.debug("changed: \(self.appState.searchText)")

//                self.appState.api.searchTracks(q: "killin")
//                    .then() { tracks in
//
//                        self.tracks = tracks
//                        logger.debug("tracks: \(tracks)")
//                }
            }
            
            if showCancelButton  {
                Button("Cancel") {
                    UIApplication.shared.endEditing(true) // this must be placed before the other commands here
                    self.appState.searchText = ""
                    self.showCancelButton = false
                }
                .foregroundColor(Color(.systemBlue))
                .font(.title)
            }
        }
        .padding(.horizontal)
            //.navigationBarHidden(showCancelButton) // .animation(.default) // animation does not work properly
    }
    
    var body: some View {
         VStack {
                self.searchControl().padding()
                
                List {
                    // Filtered list of names
                    ForEach(self.appState.trackSearchResult, id: \.uri) { (track: Playable) in
                        TrackView(track: track)
                    }
                }
                .resignKeyboardOnDragGesture()
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
        content.simultaneousGesture(gesture)
    }
    
}

extension View {
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}

