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
    
    @Published public var currentLocation: AppLocation = .home
    public var sheet: PartialSheetManager = PartialSheetManager()
    public var api: JoliApi!
    public var serverLogDestination: ServerDestination? = nil
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
                logger.warning("[AppCoordinator] votes listener closed unexpectedly: \(String(describing: completion))")
            } receiveValue: { value in
                self.voteCastSubject.send(value)
            }
            .store(in: &cancellableSet)
        }
        
    }
    
    @Published public var devices: [Spotify.Device] = []
    
    public typealias ErrorInfo = (error: Error, file: String, function: String, line: Int)
    
    public let internalErrorSubject = PassthroughSubject<ErrorInfo, Never>()
    
    public let voteCastSubject: AutoResetSubject<QueuedTrackVote?, Never, RunLoop> = AutoResetSubject(nil, delay: .milliseconds(300), scheduler: RunLoop.main)
    
    public let activeDeviceSubject = CurrentValueSubject<Spotify.Device?, Never>(nil)
    public let playingSubject = CurrentValueSubject<(track: Playable, playState: PlayState)?, Never>(nil)
    public let volumeSubject = PassthroughSubject<Int, Never>()
    
    public let playStateChangeSubject = PassthroughSubject<Date, Never>()
    
    public let playRequestedSubject = CurrentValueSubject<String?, Never>(nil)
    public let voteRequestedSubject = CurrentValueSubject<Int?, Never>(nil)
    public let queueRequestedSubject = CurrentValueSubject<(uri: String, room: Musicroom)?, Never>(nil)
    public let globalModalSubject = CurrentValueSubject<AppPreview?, Never>(nil)
    public let globalPreviewSubject = PassthroughSubject<AppPreview?, Never>()
    
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
    
    @Published public var pendingTrackChoice: (category: Search.Category, callback: (Playable) -> Void)? = nil
    
    public var appViewScrollPosition = PassthroughSubject<ScrollPosition, Never>()
    
    //public let playRequestedSubject = CurrentValueSubject([:] as [AppPreview: ])
    
    private var allSearchengines = [spotifyEngine]
    
    public enum ActionError: Error {
        case insufficientHeartPoints
    }
    
    public func globalErrorHandler(file: String = #file, function: String = #function, line: Int = #line) -> (Error) -> Void {
        return { (error: Error) -> Void in
            self.internalErrorSubject.send((error, file, function, line))
        }
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
    
    public func pickTrack(callback: @escaping (_ track: Playable) -> Void) -> Void {
        logger.debug("[AppCoordinator#pickTrack] picking track")
        dismissKeyboard()
        self.appViewScrollPosition.send(.leadingEdge)
        self.pendingTrackChoice = (category: .tracks,
                                   callback: { tck in
                                        self.pendingTrackChoice = nil
                                        self.appViewScrollPosition.send(.trailingEdge)
                                        callback(tck)
                                   })
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
            .catch(self.globalErrorHandler())
            .always {
                self.refreshingDevices = false
            }
    }
    
    private var localPlaybackConnect: (deferred: Deferred<Future<ConnectionState, Error>>, createdAt: Date)? = nil
    
    @Published var localPlaybackConnectRequest: Future<ConnectionState, Error>.Promise? = nil {
        didSet {
            guard localPlaybackConnectRequest == nil else { return }
            localPlaybackConnect = nil
        }
    }
    
    @discardableResult
    public func requestLocalPlaybackConnect() -> Deferred<Future<ConnectionState, Error>> {
        
        let makeRequest = { () -> Future<ConnectionState, Error> in
            return Future<ConnectionState, Error>() { promise in
                self.localPlaybackConnectRequest = promise
            }
        }
        
        guard let deferred = localPlaybackConnect else {
            let def = Deferred(createPublisher: makeRequest)
            localPlaybackConnect = (deferred: def, createdAt: Date())
            return def
        }
        
        return deferred.deferred
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
                        .catch(self.globalErrorHandler())
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
    
    public func synchronizePlayroom(_ playroom: Musicroom) -> Void {
        print("[synchronizePlayroom] button clicked \"Synchronize Playlist\"")
        HttpMethod.Fetch.get(url: "/api/musicrooms/\(playroom.id)/sync", dataType: Musicroom.self, baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .global(qos: .userInitiated))
            .then(on: .main){ playroom in
                print("[synchronizePlayroom] sync completed by server \(String(describing: playroom.playlistUri))")
            }
            .catch(self.globalErrorHandler())
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
            .catch(self.globalErrorHandler())
            .always {
                self.voteRequestedSubject.send(nil)
            }
        
    }
    
    @Published var localPlayRequested: (track: Playable, positionMs: Int?, contextUri: String?)? = nil
    @Published var connectionStateSubject: CurrentValueSubject<(state: ConnectionState, changedAt: Date?), Never> = CurrentValueSubject((.stopped, nil))
    
    public func play(_ track: Playable, positionMs: Int? = nil, contextUri: String? = nil, device: Spotify.Device? = nil) -> Promise<PlayState?> {
        self.playRequestedSubject.send(track.uri)
        
        let on = DispatchQueue.global(qos: .userInitiated)
        
        let performPlay = { (device: Spotify.Device?) -> Promise<PlayState?>  in
            
            guard let device = device, ![.smartphone, .tablet].contains(device.type) else {
                self.localPlayRequested = (track, positionMs, contextUri)
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
                DispatchQueue.main.async() {
                    self.playingSubject.send((track, ps))
                }
                return Promise(ps)
            }
        }
        
        guard let device = device else {
            return api.fetchSpotifyDevices(on: on)
                .catch(self.globalErrorHandler())
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
    func queueTrack(_ track: Playable, playroom activeRoom: Musicroom) -> Promise<QueuedTrack> {
        
        self.queueRequestedSubject.send((track.uri, activeRoom))
        
        return activeRoom.queueTrack(track, baseUrl: api.baseUrl.http, urlSession: api.urlSession, on: nil)
            .then() { queuedTrack in
                logger.info("[queueTrack] queued: \(queuedTrack)")
            }
            .catch(self.globalErrorHandler())
            .always {
                self.queueRequestedSubject.send(nil)
            }
    }
    
    public func share(room: Room, completionHandler: ((Bool) -> Void)? = nil){
        let currentUser: Auth? = activeAuth
        let entitlement: Entitlement? = room.entitlements.first() { $0.createdById == currentUser?.user.id }
        let uuid = entitlement?.uuid ?? room.uuid ?? ""
        
        guard let url = URL(string: uuid.isEmpty ? "" : "/i/\(uuid)", relativeTo: self.api.baseUrlHttp) else {
            completionHandler?(false)
            return
        }
        
        let someText: String = "Hi, lets listen to songs together in \"\(room.name)\" \(url.absoluteString)"
        
        self.share(text: someText, url: url, completionHandler: completionHandler)
    }
    
    public func share(text: String, url: URL, completionHandler: ((Bool) -> Void)? = nil){
        isSharePresented.toggle()
        
        let sharedObjects: [AnyObject] = [text as AnyObject]//, url as AnyObject]
        
        let av = UIActivityViewController(activityItems: sharedObjects, applicationActivities: [ShareActivity()])
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true) {
            print("[AppCoordinator#share] share view presented")
            completionHandler?(true)
        }
    }
    
    public func withImpact(_ impact: UIImpactFeedbackGenerator.FeedbackStyle = .soft, _ action: () -> Void){
        let impactHeavy = UIImpactFeedbackGenerator(style: impact)
        action()
        impactHeavy.impactOccurred()
    }
    
    public var isSimulatorOrTestFlight: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        
        let result = path.contains("CoreSimulator") || path.contains("sandboxReceipt")
        return result
    }
    
    func onConnectionStateChange(_ state: ConnectionState) {
        logger.debug("[\(Self.self)] conection state changed: \(state)")
        self.connectionStateSubject.send((state, Date()))
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
