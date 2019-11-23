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
import Promises

enum FetchError: Error {
    case cancelled
}

class AppState: ObservableObject {
    
    @Published var musicrooms: [Musicroom] = []
    @Published var tracksByMusicrooms: [Int: [Track]] = [:]
    @Published var imagesByUrl: [String: Image] = [:]
    @Published var currentPlaying: TrackInfo?
    
    //@Published var tracks: [Track] = []
    @Published var searchText: String = ""
    
    var sceneDelegate: SceneDelegate {
        return UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate
    }
    
    var spotifyRemote: SPTAppRemote {
        return sceneDelegate.appRemote
    }
    
    
    var api = JoliApi(baseUrl: .homeLaptop)
    
    private var cancellableSet: Set<AnyCancellable> = []
    @Published public var trackSearchResult: [Track] = []
    
    var currentSearchFuture: Promise<Any>?
    
    var trackSearchResultPublisher: AnyPublisher<[Track], Never> {
        $searchText
        .removeDuplicates()
        .debounce(for: 0.3, scheduler: RunLoop.main)
        .map { input -> Future<[Track], Never> in
//
//            if let existing = self.currentSearchFuture {
//                existing
//            }
//            for cancel in self.cancellableSet {
//                cancel.cancel()
//            }
            
            if let curr = self.currentSearchFuture{
                curr.reject(FetchError.cancelled)
            }
            
            return Future<[Track], Never>() { promise in
                
                guard !input.trimmingCharacters(in: [" "]).isEmpty else {
                    promise(.success([]))
                    return
                }
                
                self.currentSearchFuture = self.api.searchTracks(q: input)
                    .then() { promise(.success($0)) }
                    .catch() { print("[AppState] trackSearchResult: \($0)") }
                
            }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
    
//    var deviceChangePublisher: AnyPublisher<JoliApi.SpotifyDevice, Never> {
//        $selectedSpotifyDeviceIdx
//        .map { input -> Future<[Track], Never> in
//            return Future<[Track], Never>() { promise in
//
//                guard !input.trimmingCharacters(in: [" "]).isEmpty else {
//                    promise(.success([]))
//                    return
//                }
//
//                self.api.searchTracks(q: input)
//                    .then() { promise(.success($0)) }
//                    .catch() { print("[AppState] trackSearchResult: \($0)") }
//            }
//        }
//        .switchToLatest()
//        .eraseToAnyPublisher()
//    }

    var didChange = PassthroughSubject<AppState, Never>()
    
    init() {
        trackSearchResultPublisher
        .receive(on: RunLoop.main)
        .assign(to: \.trackSearchResult, on: self)
        .store(in: &cancellableSet)
        
        //let u = DZRUser.init()
        
//        let cancellableSink = remoteDataPublisher
//        .sink(receiveCompletion: { completion in
//                print(".sink() received the completion", String(describing: completion))
//                switch completion {
//                    case .finished:
//                        break
//                    case .failure(let anError):
//                        print("received error: ", anError)
//                }
//        }, receiveValue: { someValue in
//            self.trackSearchResult = someValue
//        })
    }
    
    @Published var spotifyDevices: [JoliApi.SpotifyDevice] = []
    @Published var selectedSpotifyDeviceIdx: Int? = nil
    @Published var activeRoom: Musicroom? = nil
    
    public var spotifyDevice: JoliApi.SpotifyDevice? {
        guard let selectedSpotifyDeviceIdx = selectedSpotifyDeviceIdx else { return nil }
        return spotifyDevices[selectedSpotifyDeviceIdx]
    }
    
    func fetchSpotifyDevices() {
        api.fetchSpotifyDevices(on: DispatchQueue.main)
            .then() { devices in
                print("Devices: \(devices)")
                self.spotifyDevices = devices
                
                if self.selectedSpotifyDeviceIdx != nil || devices.isEmpty {
                    return
                }
                
                self.selectedSpotifyDeviceIdx = devices.firstIndex() { $0.isActive }
        }
    }
    
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
