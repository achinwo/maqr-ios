//
//  SearchView.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

extension Track: View  {
    
    public var body: some View {
        TrackView2(track: .constant(self))
    }
    
}

struct SearchView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
