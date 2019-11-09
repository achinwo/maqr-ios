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
import Promises


class AppState: ObservableObject {
    
    @Published var musicrooms: [Musicroom] = []
    @Published var tracksByMusicrooms: [Int: [Track]] = [:]
    @Published var imagesByUrl: [String: Image] = [:]
    @Published var currentPlaying: TrackInfo?
    
    var api = JoliApi()

    var didChange = PassthroughSubject<AppState, Never>()
    
    @discardableResult
    func fetchedImage(url: String) -> Promise<Image?> {
        
        if let cached = imagesByUrl[url] {
            return Promise<Image?>(cached)
        }
        
        guard let urlObj = URL(string: url) else {
            return Promise<Image?>(nil)
        }
        
        return Promise {  (resolve, reject) in
            
            let task: URLSessionDataTask = URLSession.shared.dataTask(with: urlObj) { (data, resp, error) in
                guard let data = data, let img = UIImage(data: data) else {
                    print("failed to load \(url)")
                    return reject(error!)
                }
                
                let image = Image(uiImage: img)
                
                DispatchQueue.main.async {
                    self.imagesByUrl[url] = image
                }
                
                resolve(image)
            }
            task.resume()
        }
    }

    func fetchMusicrooms() {
        Musicroom.all(on: .global(qos: .background))
            .then(on: .main) { [weak self] rooms in
                self?.musicrooms = rooms
        }
    }
    
    func fetchTracks(_ room: Musicroom) {
        
        guard let roomId = room.id?.int else {
            return
        }
        
        room.fetchTracks().then() { [weak self] tracks in
            self?.tracksByMusicrooms[roomId] = tracks
        }
    }
}
