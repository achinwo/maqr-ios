//
//  AppCoordinator.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/10/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import Combine
import JoliApi
import JoliCore
import PartialSheet
import SwiftUI
import Promises

// MARK: - AppCoordinator
public final class AppCoordinator: ObservableObject {
    
    public var currentLocation: AppLocation = .home
    public var sheet: PartialSheetManager = PartialSheetManager()
    public var api: JoliApi!
    
    private var cancellableSet: Set<AnyCancellable> = []
    
    @Published public var isSearching: Search.Category = []
    @Published public var isSharePresented = false
    @Published public var namespace: Namespace.ID? = nil
    @Published public var keyboardHeight: CGFloat = 0
    @Published public var insufficientPointsAttempt = 0
    
    @Published public var playStatePublisher: PlayState.Publisher? = nil
    @Published public var votesPublisher: QueuedTrackVote.Publisher? = nil {
        
        didSet {
            
            guard let votesPub = self.votesPublisher else {
                return
            }
            
            votesPub.sink() { completion in
                logger.warning("[AppCoordinator] votes listener closed unexpectedly: \(completion)")
            } receiveValue: { value in
                self.voteCastSubject.send(value)
            }
            .store(in: &cancellableSet)
        }
        
    }
    
    @Published public var devices: [Spotify.Device] = []
    
    public let voteCastSubject: AutoResetSubject<QueuedTrackVote?, Never, RunLoop> = AutoResetSubject(nil, delay: .milliseconds(300), scheduler: RunLoop.main)
    
    public let activeDeviceSubject = CurrentValueSubject<Spotify.Device?, Never>(nil)
    public let playingSubject = CurrentValueSubject<(Playable, PlayState)?, Never>(nil)
    public let volumeSubject = PassthroughSubject<Int, Never>()
    
    public let playStateChangeSubject = PassthroughSubject<Date, Never>()
    
    public let playRequestedSubject = CurrentValueSubject<String?, Never>(nil)
    public let voteRequestedSubject = CurrentValueSubject<Int?, Never>(nil)
    public let queueRequestedSubject = CurrentValueSubject<(uri: String, room: Playroom)?, Never>(nil)
    public let globalModalSubject = CurrentValueSubject<AppPreview?, Never>(nil)
    
    public let authSubject = PassthroughSubject<Auth?, Never>()
    
    public let userHeartsSubject = CurrentValueSubject<Hearts?, Never>(nil)
    public let authsSubject = CurrentValueSubject<[Auth], Never>([])
    
    @Published public var activeSessionToken: String? = nil {
        didSet {
            self.authSubject.send(activeAuth)
            self.activeDeviceSubject.send(nil)
            self.devices = []
            self.playingSubject.send(nil)
        }
    }
    
    private var volumeCancel: AnyCancellable? = nil
    
    public var initialActiveDeviceId: String? = nil
    
    @Published public var authorizedSpotify: AuthToken? = nil
    @Published public var spotifyAuthCallback: ((AuthToken?) -> Void)? = nil
    @Published public var spotifyAuthRequestedAt: Date? = nil
    
    private var allSearchengines = [spotifyEngine]
    
    public enum ActionError: Error {
        case insufficientHeartPoints
    }
    
    public func authorizeSpotify(){
        
        self.spotifyAuthCallback = { (auth: AuthToken?) -> Void in
            self.spotifyAuthCallback = nil
            print("[AppCoordinator#authorizeSpotify] callback auth: \(String(describing: auth))")
        }
    }
    
    var activeAuth: Auth? {
        return self.authsSubject.value.first() { $0.session.token == activeSessionToken }
    }
    
    public func refreshDevices(){
        print("[AppCoordinator#devicesPublisher] fetching devices")
        self.refreshingDevices = true
        api?.fetchSpotifyDevices(on: .global(qos: .userInitiated))
            .then() { devices in
                
                self.devices = devices
                let device = devices.first(where: { $0.isActive }) ?? devices.first(where: { $0.id == self.initialActiveDeviceId }) ?? devices.first(where: { $0.type == .computer })
                
                guard let activeDevice = device ?? devices.last else {
                    return
                }
                
                self.activeDeviceSubject.send(activeDevice)
            }
            .catch() { error in
                print("[AppCoordinator#devicesPublisher] error: \(error)")
            }
            .always {
                self.refreshingDevices = false
            }
    }
    
    @Published var refreshingDevices = false
    
    public init(_ playStatePublisher: PlayState.Publisher? = nil, _ votesPublisher: QueuedTrackVote.Publisher? = nil, namespace: Namespace.ID? = nil){
        self.namespace = namespace
        self.playStatePublisher = playStatePublisher
        self.votesPublisher = votesPublisher
        
        self.volumeCancel = self.volumeSubject
            .removeDuplicates()
            .debounce(for: 0.2, scheduler: DispatchQueue.global(qos: .userInitiated))
            .sink() { value in
                
                guard let device = self.activeDeviceSubject.value else {
                    return
                }
                
                let setVolume = { () -> Void in
                    self.api.setVolume(value, deviceId: device.id)
                        .then() { res in
                            print("[AppCoord] updated volume: \(res)")
    //                        device.volumePercent = value
    //
    //                        self.activeDeviceSubject.send(device)
                        }
                        .catch() { error in
                            print("[AppCoord] volume set error: \(error)")
                        }
                }
                
                setVolume()
                
//                guard let (track, playingState) = self.playingSubject.value, playingState.deviceUid != device.id else {
//
//                    return
//                }
//
//                self.play(track, positionMs: playingState.progressMs, device: device)
//                    .then() { _ in
//                        print("[AppCordinator] auto switching device: \(playingState.deviceUid) -> \(device.id)")
//                        setVolume()
//                    }
//                    .catch() { error in
//                        print("[AppCoord] auto switching device: \(error)")
//                    }
            }
        
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.publisher(for: UIWindow.keyboardWillShowNotification)
            .map {
                guard
                    let info = $0.userInfo,
                    let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                else { return 0 }
                
                return keyboardFrame.height
            }
            .assign(to: \.keyboardHeight, on: self)
            .store(in: &cancellableSet)
        
        notificationCenter.publisher(for: UIWindow.keyboardDidHideNotification)
            .map { _ in 0 }
            .assign(to: \.keyboardHeight, on: self)
            .store(in: &cancellableSet)
    }
    
    public func synchronizePlayroom(_ playroom: Playroom) -> Void {
        print("[synchronizePlayroom] button clicked \"Synchronize Playlist\"")
        HttpMethod.Fetch.get(url: "/api/musicrooms/\(playroom.id)/sync", dataType: Playroom.self, baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .global(qos: .userInitiated))
            .then(on: .main){ playroom in
                print("[synchronizePlayroom] sync completed by server \(String(describing: playroom.playlistUri))")
            }.catch(){error in
                print("error synchronizing playlist \(error)")
            }
    }
    
    
    public func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @discardableResult
    public func voteTrack(_ track: QueuedTrack) -> Promise<QueuedTrackVote> {
        
        guard let hearts = self.userHeartsSubject.value,
              let newHearts = hearts.subtracting(HeartLevel.quarter),
              var user = self.activeAuth?.user else {
            
            return Promise.init(ActionError.insufficientHeartPoints)
        }
        
        let builder = Builder<QueuedTrackVote>()
        self.voteRequestedSubject.send(track.id)
        
        return builder.update(.queuedTrackId, track.id as AnyObject)
            .save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            .then() { vote -> Promise<QueuedTrackVote> in
                user.heartPoints = Int(newHearts.score)
                
                return user.save(baseUrl: self.api.baseUrlHttp, urlSession: self.api.urlSession)
                    .then() { user -> QueuedTrackVote in
                        self.userHeartsSubject.send(newHearts)
                        return vote
                    }
            }
            .always {
                self.voteRequestedSubject.send(nil)
            }
            
    }
    
    @Published var localPlayRequested: (track: Playable, positionMs: Int?)? = nil
    
    public func play(_ track: Playable, positionMs: Int? = nil, contextUri: String? = nil, device: Spotify.Device? = nil) -> Promise<PlayState?> {
        self.playRequestedSubject.send(track.uri)
        
        let on = DispatchQueue.global(qos: .userInitiated)
        
        let performPlay = { (device: Spotify.Device?) -> Promise<PlayState?>  in
            
            guard let device = device, ![.smartphone, .tablet].contains(device.type) else {
                self.localPlayRequested = (track, positionMs)
                return Promise(nil)
            }
            
            self.localPlayRequested = nil
            
            var promise: Promise<PlayState>
            
            if let contextUri = contextUri {
                promise = Track.playContent(contextUri, deviceId: device.id, positionMs: positionMs, offset: .uri(track.uri), baseUrl: self.api.baseUrlHttp, urlSession: self.api.urlSession, on: on)
            } else {
                promise = track.play(deviceId: device.id, positionMs: positionMs, baseUrl: self.api.baseUrl.http, urlSession: self.api.urlSession, on: on)
            }
            
            return promise.then(on: on) { ps in
                    self.playingSubject.send((track, ps))
                    return Promise(ps)
                }
        }
        
        guard let device = device else {
            return api.fetchSpotifyDevices(on: on)
                .catch(){ error in
                    logger.error("[fetchSpotifyDevices] error: \(error)")
                }
                .then() { (devices) -> Promise<PlayState?> in
                    logger.debug("Devices: \(devices)")
                    return performPlay(devices.first(where: { $0.isActive }) ?? devices.first(where: { $0.type == .computer }))
                }
                .always {
                    self.playRequestedSubject.send(nil)
                }
        }
        
        return performPlay(device)
    }
    
    @discardableResult
    func pausePlayback() -> Promise<Json> {
        //                self.spotifyRemote.playerAPI?.pause(){ info, error in
        //                    logger.debug("[pauseTrack] \(String(describing: info)) - \(String(describing: error))")
        //
        let path = URLComponents(string: "/api/spotify/me/player/pause")!
        return HttpMethod.put.fetchJson(urlPath: path, payload: [:], baseUrl: api.baseUrl.http, urlSession: api.urlSession)
    }
    
    @discardableResult
    func queueTrack(_ track: Playable, playroom activeRoom: Playroom) -> Promise<QueuedTrack> {
        
        self.queueRequestedSubject.send((track.uri, activeRoom))
        
        return activeRoom.queueTrack(track, baseUrl: api.baseUrl.http, urlSession: api.urlSession, on: nil)
            .then() { queuedTrack in
                logger.info("[queueTrack] queued: \(queuedTrack)")
            }
            .catch() { error in
                logger.error("[queueTrack] \(error)")
            }
            .always {
                self.queueRequestedSubject.send(nil)
            }
    }
    
    public func share(text: String){
        isSharePresented.toggle()
        //
        let text = "You have been invited to join the room. Go to https://api.jolimc.com/join/abcd to join the room."
        let av = UIActivityViewController(activityItems: [text], applicationActivities: [ShareActivity()])
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true) {
            print("[AppCoordinator#share] share view presented")
        }
    }
    
    public func withImpact(_ impact: UIImpactFeedbackGenerator.FeedbackStyle = .soft, _ action: () -> Void){
        let impactHeavy = UIImpactFeedbackGenerator(style: impact)
        action()
        impactHeavy.impactOccurred()
    }
    
    public struct Modifier: ViewModifier {
        
        let coordinator: AppCoordinator
        
        public init(_ coordinator: AppCoordinator){
            self.coordinator = coordinator
        }
        
        public func body(content: Content) -> some View {
            return content
                .environmentObject(self.coordinator)
                .environmentObject(self.coordinator.sheet)
        }
        
    }
    
}
