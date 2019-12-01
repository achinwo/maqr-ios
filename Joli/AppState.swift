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

struct KeyboardAwareModifier: ViewModifier {
    
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(AppState.keyboardHeightPublisher) { self.keyboardHeight = $0 }
    }
}

extension View {
    
    func keyboardAwarePadding() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAwareModifier())
    }
}

@propertyWrapper
struct UserDefault<T: Codable> {
    
    enum Key: String {
        case authToken
    }
    
    let key: Key
    let defaultValue: T
    
    init(_ key: Key, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            let data = UserDefaults.standard.data(forKey: key.rawValue)
            let value = data.flatMap { try? JSONDecoder().decode(T.self, from: $0) }
            return value ?? defaultValue
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: key.rawValue)
        }
    }
}

final class UserSettings: ObservableObject {

    var objectWillChange = PassthroughSubject<UserSettings, Never>()

    @UserDefault(.authToken, defaultValue: nil)
    var authToken: String? {
        willSet {
            objectWillChange.send(self)
        }
    }
}

class AppState: ObservableObject {
    
    @Published var userSettings = UserSettings()
    
    @Published var musicrooms: [Musicroom] = []
    @Published var tracksByMusicrooms: [Int: [Track]] = [:]
    @Published var imagesByUrl: [String: Image] = [:]
    
    @Published var currentlyPlayingTrack: Track?
    @Published var currentlyPlayingImage: Image?
    @Published var currentlyPlayingProgress: Int?
    
    @Published var isSettingsPresented = false
    
    @Published var searchText: String = ""
    
    var sceneDelegate: SceneDelegate {
        return UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate
    }
    
    var env: JoliApi.Environment {
        return self.sceneDelegate.appDelegate.env
    }
    
    var spotifyRemote: SPTAppRemote {
        return sceneDelegate.appRemote
    }
    
    let baseUrl: JoliApi.BaseUrl
    
    lazy var api: JoliApi = {
        JoliApi(baseUrl: self.baseUrl)
    }()
    
    private var cancellableSet: Set<AnyCancellable> = []
    @Published public var trackSearchResult: [Track] = []
    
    var currentSearchFuture: Promise<Any>?
    
    @Published var keyboardHeight: CGFloat = 0
    
    static var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> = {
        logger.info("[AppState] init keyboardHeightPublisher")
        return Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
                .map { $0.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        ).eraseToAnyPublisher()
    }()
    
    var trackSearchResultPublisher: AnyPublisher<[Track], Never> {
        $searchText
        .removeDuplicates()
        .debounce(for: 0.3, scheduler: RunLoop.main)
        .map { input -> Future<[Track], Never> in
            
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
                    .catch() { logger.debug("[AppState] trackSearchResult: \($0)") }
                
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
//                    .catch() { logger.debug("[AppState] trackSearchResult: \($0)") }
//            }
//        }
//        .switchToLatest()
//        .eraseToAnyPublisher()
//    }

    var didChange = PassthroughSubject<AppState, Never>()
    
    var nowPlayingSubject = CurrentValueSubject<[String: AnyObject]?, Never>(nil)
    
    @Published var auth: Auth?
    
    static func jsonStringToDict(text: String) -> [String:AnyObject]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
            } catch let error {
                logger.debug(error)
            }
        }
        return nil
    }
    
    // MARK: - initialize
    init(baseUrl: JoliApi.BaseUrl) {
        self.baseUrl = baseUrl
        
        trackSearchResultPublisher
        .receive(on: RunLoop.main)
        .assign(to: \.trackSearchResult, on: self)
        .store(in: &cancellableSet)
        
        AppState.keyboardHeightPublisher
        .receive(on: RunLoop.main)
        .assign(to: \.keyboardHeight, on: self)
        .store(in: &cancellableSet)
        
        self.api.$auth
            .receive(on: RunLoop.main)
            //.assign(to: \.auth, on: self)
            .sink { auth in
                self.auth = auth
                self.userSettings.authToken = auth?.session.token
            }
            .store(in: &cancellableSet)
        
        if let authToken = self.userSettings.authToken {
            logger.info("[AppState] authenticating with token: \(authToken)")
            self.api.authenticate(token: authToken)
        }
        
        nowPlayingSubject
            .sink() { result in
                logger.debug("[AppState] result: \(String(describing: result))")
            }
            .store(in: &cancellableSet)
        
//        self.appState.api.subscribe(subject: "PLAYER_STATE_NOW_PLAYING"){ result in
//
//            guard let json = result.successString, let jsonDict = Self.jsonStringToDict(text: json) else {
//                logger.debug("failed to  deserialise result: \(result)")
//                return
//            }
//
//            let data = jsonDict["data"] as? [String: AnyObject]
//            let item = data?["item"] as? [String: AnyObject]
//            
//            log("[PLAYER_STATE_NOW_PLAYING] \(String(describing: item))")
//
//            self.appState.nowPlayingSubject.send(item)
//
//        }
        
//            .sink(receiveCompletion: { completion in logger.debug("Completion: \(completion)") }) { track in
//                logger.debug("[AppState] track: \(String(describing: track))")
//            }
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
                logger.debug("Devices: \(devices)")
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
                    logger.debug("failed to load \(url)")
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
        Musicroom.all(baseUrl: api.baseUrl.rawValue.http, on: .global(qos: .background))
            .then(on: .main) { [weak self] rooms in
                self?.musicrooms = rooms
        }
    }
    
    func fetchTracks(_ room: Musicroom) {
        
        guard let roomId = room.id?.int else {
            return
        }
        
        room.fetchTracks(baseUrl: api.baseUrl.rawValue.http).then() { [weak self] tracks in
            self?.tracksByMusicrooms[roomId] = tracks
        }
    }
}
