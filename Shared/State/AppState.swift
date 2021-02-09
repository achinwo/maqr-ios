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
import Version

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


class AppCurrentlyPlayingState: ObservableObject {
    
    @Published var progressPct = 0.0
    @Published var track: Spotify.Track? = nil
    @Published var content: Spotify.CurrentlyPlayingContent? = nil
    @Published var albumImage: Image? = nil

    var didChange = PassthroughSubject<AppState, Never>()
    
}

class AppKeyboardState: ObservableObject {
    
    @Published var keyboardHeight: CGFloat = 0
    private var cancellableSet: Set<AnyCancellable> = []
    
    var didChange = PassthroughSubject<AppState, Never>()
    
    init(){
        AppState.keyboardHeightPublisher
        .receive(on: RunLoop.main)
        .assign(to: \.keyboardHeight, on: self)
        .store(in: &cancellableSet)
    }
}

class AppServerReconnectState: ObservableObject {

    @Published var countdown: Int = 0
    
}

class AppState: ObservableObject {
    
    typealias DeviceReadyCallback = (Spotify.Device?, Bool) throws -> Void
    typealias SpotifyReadyCallback = (Spotify.UserProfile?, Bool) throws -> String?
    
    static let URL_SCHEME = "joli"
    static let SPOTIFY_URL_BASEPATH = "spotify-callback"
    
    @Published var lastPlayedTrack: Spotify.Track? = nil
    @Published var lastPlayedContent: Spotify.CurrentlyPlayingContent? = nil
    
    @Published var navbarColor: Color = .gray
    @Published var selectedTabIdx = 1
    
    @Published var spotifyAuthorizationInProgress = false
    @Published var userSettings = UserSettings()
    
    @Published var musicrooms: [Musicroom] = []
    
    @Published var tracksByMusicrooms: [Int: [RoomTrack]] = [:]
    @Published var queuedTracksByMusicrooms: [Int: Set<QueuedTrack>] = [:]
    @Published var votesByTrackId: [Int: [QueuedTrackVote]] = [:]
    
    @Published var usersById: [Int: User] = [:]
    @Published var imagesByUrl: [String: Image] = [:]
    
    @Published var isSettingsPresented = false
    
    @Published var searchText: String = ""
    @Published var deviceVolume: CGFloat = 30
    
    @Published var auth: Auth?
    @Published var serverConnectionState: ConnectionState = .stopped
    @Published var serverReconnectState = AppServerReconnectState()
    
    @Published var spotifyDevices: [Spotify.Device] = []
    @Published var selectedSpotifyDeviceIdx: Int? = nil {
        didSet {
            guard let idx = self.selectedSpotifyDeviceIdx, idx < self.spotifyDevices.count else {
                return
            }
            
            self.deviceVolume = CGFloat(self.spotifyDevices[idx].volumePercent)
        }
    }
    
    @Published var activeRoom: Musicroom? = nil
    
    @Published var spotifyWebAuth: AuthToken? = nil
    @Published public var trackSearchResult: [Spotify.Track] = []
    
    @Published var isDeviceChooserPresented: Bool = false
    @Published var isSpotifyConnectPresented: Bool = false
    
    var currentSearchFuture: Promise<Any>?
    
    var didChange = PassthroughSubject<AppState, Never>()
    
    var appDelegate: AppDelegate {
        return appDelegateSingleton
    }
    
    var env: JoliApi.Environment {
        return self.appDelegate.env
    }
    
    static var version: Version {
        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let version = Version("\(appVersion).\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")") else {
            return Version.init(1, 0, 0)
        }
        
        return version
    }
    
    var spotifyDelegate: SpotifyDelegate = spotifyDelegateInstance
    
    var spotifyRemote: SPTAppRemote? {
        return spotifyDelegate.appRemote
    }
    
    let baseUrl: JoliApi.BaseUrl
    
    let api: JoliApi
    var serverVersion: Version?
    
    var cancellableSet: Set<AnyCancellable> = []
    
    var deviceReadyCallbacks: [DeviceReadyCallback] = []
    
    let currentlyPlaying: AppCurrentlyPlayingState
    let keyboardState: AppKeyboardState
    
    var currentlyPlayingAlbumUrl: String? = nil
    
    var spotifyWebAuthorized: Bool {
        return spotifyWebAuth != nil
    }
    
    public var spotifyDevice: Spotify.Device? {
        guard let selectedSpotifyDeviceIdx = selectedSpotifyDeviceIdx, spotifyDevices.count > selectedSpotifyDeviceIdx else { return nil }
        return spotifyDevices[selectedSpotifyDeviceIdx]
    }
    
    @Published var isLogonViewPresented = false
    
    @State var showToast: Bool = false
    
    @Published var alerts: Set<ServiceAlert> = [.loginRequired, .spotifyWebAuthRequired, .serverConnectionLost]
    
    var screen: CGRect {
        return UIScreen.main.bounds
    }
    
    // MARK: - Class variables
    weak var timer: Timer?
    
    deinit {
        timer?.invalidate()
        cancellableSet.removeAll()
    }
    
    // MARK: - onServerConnectionStateChanged
    func onServerConnectionStateChanged(_ state: ConnectionState){
        DispatchQueue.main.async {
            self.serverConnectionState = state
        }
        
        timer?.invalidate()
        
        switch state {
        case .connected:
            self.navbarColor = state.isConnected ? Color.green : .gray
            self.updateAlerts(.serverConnectionLost, add: false)
            self.fetchMusicrooms()
            self.assertSpotifyAuthorized()
            
        case .reconnecting(let attempt):
            
            self.updateAlerts(.serverConnectionLost, add: true)
            
            self.serverReconnectState.countdown = attempt * 5
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timerInstance in
                
                guard let self = self else {
                    return
                }
                //logger.info("[on server state] \(self.serverReconnectCountdown)")
                
                //currentAttemptSecs = currentAttemptSecs - 1
                self.serverReconnectState.countdown = self.serverReconnectState.countdown - Int(timerInstance.timeInterval)
                
                if self.serverReconnectState.countdown <= 0 {
                    self.timer?.invalidate()
                }
            }
        case .stopped:
            self.updateAlerts(.serverConnectionLost, add: true)
            self.assertSpotifyAuthorized()
        }
    }
    
    
    // MARK: - initialize (Start)
    init(baseUrl: JoliApi.BaseUrl, serverVersion: Version? = nil) {
        self.baseUrl = baseUrl
        
        self.currentlyPlaying = AppCurrentlyPlayingState()
        self.keyboardState = AppKeyboardState()
        self.serverVersion = serverVersion
        
        let headers: [String: String] = [
            "X-PLATFORM": "ios",
            "X-DEVICE-UUID": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "X-DEVICE-MODEL": UIDevice.current.model,
            "X-DEVICE-NAME": UIDevice.current.name,
            "X-APP-VERSION": AppState.version.description,
        ]
        
        self.api = JoliApi(baseUrl: self.baseUrl, headers: headers)
        api.urlSessionConfiguration = api.urlSessionConfiguration.withAuthHeader(self.userSettings.authToken)
        
        JoliApi.setDefault(self.api)
        
        if let authToken = self.userSettings.authToken {
            logger.info("[AppState] authenticating with token: \(authToken)")
            self.api.authenticate(token: authToken)
        }
        
        self.initReactive()
        
        guard self.serverVersion != nil else {
            return
        }
        
        JoliApi.resolveServer(self.baseUrl.http)
            .timeout(3.0)
            .then(on: .main) { version in
                logger.info("[AppState#init] server version: \(version)")
                self.serverVersion = version
            }
            .catch() { error in
                logger.error("[serverResolve] error: \(String(describing: error))")
            }
        
    }
    // MARK: initialize (End)
    
}

