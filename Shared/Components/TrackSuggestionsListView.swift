//
//  TrackSuggestionsListView.swift
//  Joli
//
//  Created by Anthony Chinwo on 10/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

struct TrackSuggestionsListView<P: Playable>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @Binding var playables: [P]
    
    var className: String {
        return "\(P.self)"
    }
    
    var contentView: some View {
        Text("Hello, World!")
    }
}

//struct TrackSuggestionsListView_Previews: PreviewProvider {
//    static var previews: some View {
//        TrackSuggestionsListView()
//    }
//}
