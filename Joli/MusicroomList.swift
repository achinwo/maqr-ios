//
//  MusicroomList.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI

struct MusicroomList: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            List(appState.musicrooms) { room in
                NavigationLink(destination: MusicroomDetail(room: room)) {
                    MusicroomRow(room: room)
                }
            }
            .navigationBarTitle(Text("Music Rooms"))
        }.onAppear() { self.appState.fetch() }
    }
}

struct MusicroomList_Previews: PreviewProvider {
    static var previews: some View {
        MusicroomList()
    }
}
