//
//  TrackSuggestionsListView.swift
//  Joli
//
//  Created by Anthony Chinwo on 10/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

extension Room {
    
    
}

struct TrackSuggestionsListView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var tracks: [Playable] = []
    @State var artists: [Artist] = []
    
    @Binding var genres: [String]
    
    @State var isLoading: Bool = false
    
    
    var contentView: some View {
        
        return Group(){
            if self.isLoading {
                ProgressView("Getting recommendations...")
            } else {
                TrackList(tracks: self.$tracks) { (track, states, color) in
                    Image(systemName: "plus")
                        .font(.title)
                }
            }
        }
    }
}

//struct TrackSuggestionsListView_Previews: PreviewProvider {
//    static var previews: some View {
//        TrackSuggestionsListView()
//    }
//}
