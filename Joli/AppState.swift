//
//  AppState.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliApi
import JoliCore
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
    
    static let URL_SCHEME = "joli"
    static let SPOTIFY_URL_BASEPATH = "spotify-callback"
    
    @Published var currentlyPlayingProgressPct = 0.0
    @Published var currentlyPlayingTrack: Spotify.Track? = nil
    @Published var currentlyPlayingContent: Spotify.CurrentlyPlayingContent? = nil
    @Published var currentlyPlayingAlbumImage: Image? = nil
    
    private var currentlyPlayingAlbumUrl: String? = nil
    
    @Published var spotifyAuthorizationInProgress = false
    @Published var userSettings = UserSettings()
    
    @Published var musicrooms: [Musicroom] = []
    @Published var tracksByMusicrooms: [Int: [Track]] = [:]
    @Published var usersById: [Int: User] = [:]
    @Published var imagesByUrl: [String: Image] = [:]
    
    @Published var isSettingsPresented = false
    
    @Published var searchText: String = ""
    
    var appDelegate: AppDelegate {
        return sceneDelegate.appDelegate
    }
    
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
    @Published public var trackSearchResult: [Spotify.Track] = []
    
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
    
    var trackSearchResultPublisher: AnyPublisher<[Spotify.Track], Never> {
        $searchText
        .removeDuplicates()
        .debounce(for: 0.3, scheduler: RunLoop.main)
        .map { input -> Future<[Spotify.Track], Never> in
            
            if let curr = self.currentSearchFuture{
                curr.reject(FetchError.cancelled)
            }
            
            return Future<[Spotify.Track], Never>() { promise in
                
                guard !input.trimmingCharacters(in: [" "]).isEmpty else {
                    promise(.success([]))
                    return
                }
                
                self.currentSearchFuture = self.api.searchTracks(q: input, limit: 25)
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
    
    //var currentlyPlayingContent = CurrentValueSubject<Spotify.CurrentlyPlayingContent?, Never>(nil)
    
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
    
    func spotifyWebAuthorize(_ urlPath: URLComponents) -> Promise<Json> {
        spotifyAuthorizationInProgress = true
        
        return HttpMethod.get.fetchJson(urlPath: urlPath,
                                 payload: [:],
                                 baseUrl: api.baseUrl.rawValue.http,
                                 urlSession: api.urlSession)
                .always() {
                    self.spotifyAuthorizationInProgress = false
                }
    }
    
    func resolveSpotifyRedirectUrl(_ url: URL) -> URL? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let scheme = components?.scheme,
            let basePath = components?.host,
            let codeQuery = components?.queryItems?.first(where: { $0.name == "code" }),
            scheme == AppState.URL_SCHEME,
            basePath == AppState.SPOTIFY_URL_BASEPATH else {
            return nil
        }
        
        var redirectUrl = URLComponents(string: "/spotify_callback")
        redirectUrl?.queryItems = [codeQuery, URLQueryItem(name: "platform", value: "ios")]
        
        return redirectUrl?.url(relativeTo: api.baseUrl.rawValue.http)
    }
    
    func setAudioSession(_ enabled: Bool){
        do {
            try appDelegate.audioSession.setActive(enabled)
            try appDelegate.audioSession.setCategory(.playback)
            
            if enabled {
                appDelegate.startObservingVolumeChanges()
            }else{
                appDelegate.stopObservingVolumeChanges()
            }
            logger.debug("[setAudioSession] App is active")
        } catch {
            logger.debug("[setAudioSession] Failed to update audio session: \(error)")
        }
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
                //logger.info("[AppState] storing token: \(String(describing: self.userSettings.authToken))")
            }
            .store(in: &cancellableSet)
        
        if let authToken = self.userSettings.authToken {
            logger.info("[AppState] authenticating with token: \(authToken)")
            self.api.authenticate(token: authToken)
        }
        
        api.subscribe(subject: .playerStateChanged){ (response, error) in
            
            guard let ctx = response?.payload,
                let rawData = try? ctx.toData(),
                let cPlaying = try? Spotify.CurrentlyPlayingContent.fromData(rawData)
                else {
                self.setAudioSession(false)
                return
            }
            logger.info("[\(JoliApi.Subject.playerStateChanged.rawValue)] \(cPlaying.isPlaying)")
            
            self.setAudioSession(cPlaying.isPlaying)
        }
        
        api.subscribe(subject: .playerStateNowPlaying){ (result, error) in
            
            let data = result?.payload
            
            guard let ctx = data,
                let rawData = try? ctx.toData(),
                let cPlaying = try? Spotify.CurrentlyPlayingContent.fromData(rawData)
                else {
                return
            }

            let progress = (Double(cPlaying.progressMs) / Double(cPlaying.item.durationMs)) * 100
            
            self.currentlyPlayingContent = cPlaying
            self.currentlyPlayingTrack = cPlaying.item
            self.currentlyPlayingProgressPct = progress
            
            if self.currentlyPlayingAlbumUrl == nil || self.currentlyPlayingAlbumUrl! != cPlaying.item.albumCoverUrl {
                self.currentlyPlayingAlbumUrl = cPlaying.item.albumCoverUrl
             
                self.fetchedImage(url: cPlaying.item.albumCoverUrl)
                                    .then() { imgObj in
                                        self.currentlyPlayingAlbumImage = imgObj
                                }
            }
        }
    }
    
    @Published var spotifyDevices: [Spotify.Device] = []
    @Published var selectedSpotifyDeviceIdx: Int? = nil
    @Published var activeRoom: Musicroom? = nil
    
    public var spotifyDevice: Spotify.Device? {
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
        .catch(){ error in
            logger.error("[fetchSpotifyDevices] error: \(error)")
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

    @discardableResult
    func fetchMusicrooms() -> Promise<[Musicroom]> {
        return Musicroom.all(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession, on: .global(qos: .background))
            .then(on: .main) { [weak self] (rooms) -> Promise<[User]> in
                guard let self = self else { return Promise([]) }
                
                self.musicrooms = rooms
                let creatorIds: [Int] = rooms.compactMap() { $0.createdById }
                return User.findByIds(ids: creatorIds, baseUrl: self.api.baseUrl.rawValue.http,
                                      urlSession: self.api.urlSession)
        }
        .then(){ [weak self] users in
            let items = users.map() { ($0.id, $0) }
            self?.usersById = Dictionary<Int, User>(uniqueKeysWithValues: items)
            //logger.info("[users]")
            guard let self = self else { return Promise([]) }
            
            return Promise(self.musicrooms)
        }
    }
    
    func fetchTracks(_ room: Musicroom) {
        room.fetchTracks(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession).then() { [weak self] tracks in
            self?.tracksByMusicrooms[room.id] = tracks
        }
        .catch() { error in
            logger.error("[fetchTracks] error: \(error)")
        }
    }
    
}
