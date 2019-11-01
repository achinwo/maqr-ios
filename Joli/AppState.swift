//
//  AppState.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliApi
import SwiftUI
import Combine
import JoliApi
//import SpotifyiOS

class AppState: ObservableObject {
    
    @Published var musicrooms: [Musicroom] = []
    @Published var tracksByMusicrooms: [Int: [Track]] = [:]
    
    var api = JoliApi()

    var didChange = PassthroughSubject<AppState, Never>()

    func fetchMusicrooms() {
        Musicroom.all(on: .global(qos: .background))
            .then(on: .main) { [weak self] rooms in
                self?.musicrooms = rooms
        }
    }
    
    func fetchTracks(_ room: Musicroom) {
        
        guard let roomId = room.id else {
            return
        }
        
        room.fetchTracks().then() { [weak self] tracks in
            self?.tracksByMusicrooms[roomId] = tracks
        }
    }
}
