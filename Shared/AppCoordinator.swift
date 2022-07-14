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
import SwiftUI
import Version
import AlertToast
import struct NetworkImage.NetworkImageLoader
import struct NetworkImage.NetworkImageCache

#if !os(macOS)
import PartialSheet
#endif

public enum AuthenticationFlow {
    case apple((Bool) -> Void)
    case spotify((Bool) -> Void)
}


public class ModalCoordinator {
    
    public typealias CloseCallback = () -> Void
    
    public enum Item {
        case view(AppPreview)
        case mailOptions(MailView.Options)
    }
    
    public struct Modal: Identifiable, Equatable {
        
        public static func == (lhs: ModalCoordinator.Modal, rhs: ModalCoordinator.Modal) -> Bool {
            lhs.id == rhs.id
        }
        
        public let id: UUID = UUID()
        public let item: Item
        public let onClose: () -> Void
    }
    
    private var modal: Modal? = nil {
        didSet {
            self.publisher.send(modal)
        }
    }
    
    public let publisher = PassthroughSubject<Modal?, Never>()
    
    private var pendingCompletions: [(() throws -> Void)] = []

    public func present(onClose: (() -> Void)? = nil, _ content: () -> AppPreview) {
        
        self.modal = .init(item: Item.view(content()), onClose: { [weak self] in
            self?.modal = nil
            onClose?()
            
            guard let self = self, !self.pendingCompletions.isEmpty else { return }
            
            for closure in self.pendingCompletions {
                try? closure()
            }
            
            self.pendingCompletions = []
        })
    }
    
    public func presentMailComposer(_ options: MailView.Options, onClose: (() -> Void)? = nil) {
        
        self.modal = .init(item: Item.mailOptions(options), onClose: {
            self.modal = nil
            onClose?()
        })
    }
    
    public func close(_ completion: (() -> Void)? = nil) {
        
        self.publisher.send(nil)
        
        guard let completion = completion, self.modal != nil else {
            print("[CLOSE] modal is nil")
            self.modal?.onClose()
            return
        }
        
        print("[CLOSE] modal is NOT nil")
        self.pendingCompletions.append(completion)
    }
    
}

// MARK: - AppCoordinator
public final class AppCoordinator: ObservableObject {
    
    @Published public var currentLocation: AppLocation = .unset
    
    #if !os(macOS)
    public var sheet: PartialSheetManager = PartialSheetManager()
    #endif
    
    public var api: JoliApi!
    public lazy var serverLogDestination: ServerDestination = {
        return ServerDestination(url: api.baseUrlHttp, urlSession: api.urlSession)
    }()
    
    private var cancellableSet: Set<AnyCancellable> = []
    
    lazy var imageLoader: NetworkImageLoader = {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 100 * 1024 * 1024
        
        let configuration = api.urlSession.configuration
        
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        configuration.httpAdditionalHeaders = ["Accept": "image/*"]
        
        guard api.env == .production else {
            return NetworkImageLoader(urlSession: URLSession(configuration: configuration, delegate: JoliApi.sharedUrlSessionDelegate, delegateQueue: .current), imageCache: NetworkImageCache())
        }
        
        return NetworkImageLoader(urlSession: URLSession(configuration: configuration), imageCache: NetworkImageCache())
    }()
    
    @Published public var serverInfo: ServerInfo? = nil
    @Published public var isSearching: Search.Category = []
    @Published public var isSharePresented = false
    @Published public var namespace: Namespace.ID? = nil
    @Published public var keyboardHeight: CGFloat = 0
    @Published public var insufficientPointsAttempt = 0
    
    public let signoutSubject = PassthroughSubject<Auth, Never>()
    public let globalToastInfo = PassthroughSubject<(alert: AlertToast, onDismiss: (Bool) -> Void), Never>()
    
    public let requestedSignIn = PassthroughSubject<AuthenticationFlow, Never>()
    
    public let purchaseNotificationSubject = PassthroughSubject<String?, Never>()
    
    public let storeKitHelper: StoreKitHelper
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
    
    public let modal = ModalCoordinator() //PassthroughSubject<AppPreview?, Never>()
    public let globalPreviewSubject = PassthroughSubject<AppPreview?, Never>()
    
    public let globalAlertSubject = PassthroughSubject<Alert, Never>()
    
    public let authSubject = PassthroughSubject<Auth?, Never>()
    
    public let userHeartsSubject = CurrentValueSubject<Hearts?, Never>(nil)
    public let authsSubject = CurrentValueSubject<[Auth], Never>([])
    
    public let pendingSpotifyAuthCallback = CurrentValueSubject<((Bool) -> Void)?, Never>(nil)
    
    @Published public var localPlayRequested: (track: Playable, positionMs: Int?, contentOffset: ContentOffset?)? = nil
    @Published public var connectionStateSubject: CurrentValueSubject<(state: ConnectionState, changedAt: Date?), Never> = CurrentValueSubject((.stopped, nil))
    
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
    
    @Published var refreshingDevices = false
    
    private var localPlaybackConnect: (deferred: Deferred<Future<ConnectionState, Error>>, createdAt: Date)? = nil
    
    //public let playRequestedSubject = CurrentValueSubject([:] as [AppPreview: ])
    
    private var allSearchengines = [spotifyEngine]
    
    public var isPaymentEnabled: Bool {
        serverInfo?.feature.paymentsEnabled == true
    }
    
    public enum ActionError: Error {
        case insufficientHeartPoints
    }
    
    public func globalErrorHandler(file: String = #file, function: String = #function, line: Int = #line) -> (Error) -> Void {
        return { (error: Error) -> Void in
            DispatchQueue.main.async() {
                self.internalErrorSubject.send((error, file, function, line))
            }
        }
    }
    
    public func withAlert(_ title: String, message: String? = nil, destructive: Bool = false, dismissLabel: String? = nil, label: String? = nil,
                          dismissAction: (() -> Void)? = nil, action: @escaping () -> Void = {}) {
        
        var messageTxt: Text? = nil
        
        if let msg = message {
            messageTxt = Text(msg)
        }
        
        let cancelButton: Alert.Button
        let onDismiss = { () -> Void in
            dismissAction?()
            logger.info("[\(Self.self)#\(#function)] dismissed alert: \"\(title)\"")
        }
        
        if let dismissLabel = dismissLabel {
            cancelButton = .cancel(Text(dismissLabel), action: onDismiss)
        } else {
            cancelButton = .cancel(onDismiss)
        }
        
        guard let label = label else {
            self.globalAlertSubject.send(Alert(title: Text(title),
                                                 message: messageTxt,
                                                 dismissButton: cancelButton))
            return
        }
        
        let primaryButton: Alert.Button = destructive ? .destructive(Text(label), action: action) : .default(Text(label), action: action)
        
        let alert: Alert = Alert(title: Text(title),
                                 message: messageTxt,
                                 primaryButton: primaryButton,
                                 secondaryButton: cancelButton)
        
        self.globalAlertSubject.send(alert)
    }
    
    public func withAlert(_ title: String, message: String? = nil, destructive: Bool = false, dismissLabel: String? = nil, label: String? = nil, action: @escaping () -> Void = {}) {
        self.withAlert(title, message: message, destructive: destructive, dismissLabel: dismissLabel, label: label, dismissAction: nil, action: action)
    }
    
    public func withAlert(_ title: String, message: String? = nil, dismissLabel: String, action: @escaping () -> Void) {
        self.withAlert(title, message: message, dismissLabel: dismissLabel, label: nil, dismissAction: action)
    }
    
    public func authorizeSpotify(){
        
        self.spotifyAuthCallback = { (auth: AuthToken?) -> Void in
            self.spotifyAuthCallback = nil
            print("[AppCoordinator#authorizeSpotify] callback auth: \(String(describing: auth))")
        }
    }
    
    public var activeAuth: Auth? {
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
    
    @MainActor
    public func refreshDevices() async {
        print("[AppCoordinator#devicesPublisher] fetching devices")
        
        defer { self.refreshingDevices = false }
        
        self.refreshingDevices = true
        
        do {
            let devices = try await api?.fetchSpotifyDevices() ?? []
            self.devices = devices
            let device = devices.first(where: { $0.isActive }) ?? devices.first(where: { $0.id == self.initialActiveDeviceId }) ?? devices.first(where: { $0.type == .computer })
            
            guard let activeDevice = device ?? devices.last else {
                return
            }
            
            self.activeDeviceSubject.send(activeDevice)
        } catch {
            self.globalErrorHandler()(error)
        }
        
    }
    
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
    
    public static var version: Version {
        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let version = Version("\(appVersion).\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")") else {
            return Version.init(1, 0, 0)
        }
        
        return version
    }
    
    public init(_ playStatePublisher: PlayState.Publisher? = nil, _ votesPublisher: QueuedTrackVote.Publisher? = nil, namespace: Namespace.ID? = nil){
        self.namespace = namespace
        self.playStatePublisher = playStatePublisher
        self.votesPublisher = votesPublisher
        
        self.storeKitHelper = StoreKitHelper()
        
        self.volumeCancel = self.volumeSubject
            .removeDuplicates()
            .debounce(for: 0.2, scheduler: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .sink() { value in
                
                guard let device = self.activeDeviceSubject.value else {
                    return
                }
                
                Task(){
                    do {
                        let res = try await self.api.setVolume(value, deviceId: device.id)
                        print("[AppCoord] updated volume: \(res)")
                            //                        device.volumePercent = value
                            //
                            //                        self.activeDeviceSubject.send(device)
                    } catch {
                        self.globalErrorHandler()(error)
                    }
                }
            }
        
        let notificationCenter = NotificationCenter.default
        
        #if !os(macOS)
        notificationCenter.publisher(for: .storeKitHelperPurchaseNotification)
            .map(){ notification in
                return notification.object as? String
            }
            .sink(){ identifier in
                self.purchaseNotificationSubject.send(identifier)
            }
            .store(in: &cancellableSet)
        
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
        #endif
    }
    
    @MainActor
    public func synchronizePlayroom(_ playroom: Musicroom) async -> Void {
        print("[synchronizePlayroom] button clicked \"Synchronize Playlist\"")
                    
        do {
            let playroom = try await HttpMethod.Fetch.get(url: "/api/musicrooms/\(playroom.id)/sync", dataType: Musicroom.self, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            print("[synchronizePlayroom] sync completed by server \(String(describing: playroom.playlistUri))")
        } catch {
            self.globalErrorHandler()(error)
        }
    }
    
    
    public func dismissKeyboard() {
        #if !os(macOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    @discardableResult
    @MainActor
    public func voteTrack(_ track: QueuedTrack) async throws -> QueuedTrackVote {
        
        guard let hearts = self.userHeartsSubject.value,
              let newHearts = hearts.subtracting(HeartLevel.quarter),
              var user = self.activeAuth?.user else {
            
            throw ActionError.insufficientHeartPoints
        }
        
        let builder = Builder<QueuedTrackVote>()
        self.voteRequestedSubject.send(track.id)
        
        defer { self.voteRequestedSubject.send(nil) }
        
        do {
            let vote = try await builder.update(.queuedTrackId, track.id as AnyObject)
                                        .save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            user.heartPoints = Int(newHearts.score)
            let _ = try await user.save(baseUrl: self.api.baseUrlHttp, urlSession: self.api.urlSession)
            
            self.userHeartsSubject.send(newHearts)
            return vote
        } catch {
            self.globalErrorHandler()(error)
            throw error
        }
    }
    
    public func play(_ track: Playable, positionMs: Int? = nil, contentOffset: ContentOffset? = nil, device: Spotify.Device? = nil) async -> PlayState? {
        self.playRequestedSubject.send(track.uri)
        
        let performPlay = { @MainActor (device: Spotify.Device?) async throws -> PlayState?  in
            
            guard let device = device, ![.smartphone, .tablet].contains(device.type) else {
                self.localPlayRequested = (track, positionMs, contentOffset)
                return nil
            }
            
            self.localPlayRequested = nil
            
            var ps: PlayState
            
            if case let .uri(contextUri) = contentOffset {
                ps = try await Track.playContent(contextUri, deviceId: device.id, positionMs: positionMs, offset: .uri(track.uri), baseUrl: self.api.baseUrlHttp, urlSession: self.api.urlSession)
            } else if case let .both(contextUri, _) = contentOffset {
                ps = try await Track.playContent(contextUri, deviceId: device.id, positionMs: positionMs, offset: .uri(track.uri), baseUrl: self.api.baseUrlHttp, urlSession: self.api.urlSession)
            } else {
                ps = try await track.play(deviceId: device.id, positionMs: positionMs, baseUrl: self.api.baseUrl.http, urlSession: self.api.urlSession)
            }
            
            self.playingSubject.send((track, ps))
            
            return ps
        }
        
        guard let device = device else {
            
            if self.activeAuth != nil {
                
                do {
                    let devices = try await api.fetchSpotifyDevices()
                    logger.debug("Devices: \(devices)")
                    return try await performPlay(devices.first(where: { $0.isActive }) ?? devices.first(where: { $0.type == .computer }))
                } catch {
                    self.globalErrorHandler()(error)
                    return nil
                }
            } else {
                return try? await performPlay(nil)
            }
        }
        
        return try? await performPlay(device)
    }
    
    @discardableResult
    func pausePlayback() async -> Json {
        //                self.spotifyRemote.playerAPI?.pause(){ info, error in
        //                    logger.debug("[pauseTrack] \(String(describing: info)) - \(String(describing: error))")
        //
        let path = URLComponents(string: "/api/spotify/me/player/pause")!
        return (try? await HttpMethod.put.fetchJson(urlPath: path, payload: [:], baseUrl: api.baseUrl.http, urlSession: api.urlSession)) ?? Json()
    }
    
    @discardableResult
    func queueTrack(_ track: Playable, playroom activeRoom: Musicroom) async throws -> QueuedTrack {
        
        self.queueRequestedSubject.send((track.uri, activeRoom))
        
        defer {
            self.queueRequestedSubject.send(nil)
        }
        
        do {
            let queuedTrack = try await activeRoom.queueTrack(track, baseUrl: api.baseUrl.http, urlSession: api.urlSession)
            logger.info("[queueTrack] queued: \(queuedTrack)")
            return queuedTrack
        } catch {
            self.globalErrorHandler()(error)
            throw error
        }
    }
    
    public func share(track: Playable, completionHandler: ((Bool) -> Void)? = nil){
        
        let spotifyUrl = URL(string: "https://open.spotify.com")
        let trackId = track.uri.replacingOccurrences(of: "spotify:track:", with: String.empty)
        
        guard let url = URL(string: "/track/\(trackId)", relativeTo: spotifyUrl) else {
            completionHandler?(false)
            return
        }

        let someText: String = "Here's a song suggestion for you \"\(track.title)\" by \(track.artistName) \(url.absoluteString)"
        
        self.share(text: someText, url: url, completionHandler: completionHandler)
    }
    
    public func share(room: Room, completionHandler: ((Bool) -> Void)? = nil){
        
        guard let url = room.inviteUrl(for: activeAuth?.user, fallback: room.inviteUrl) else {
            completionHandler?(false)
            return
        }
        
        let someText: String = "Hi, lets listen to songs together in \"\(room.name)\" \(url.absoluteString)"
        
        self.share(text: someText, url: url, completionHandler: completionHandler)
    }
    
    public func share(text: String, url: URL, completionHandler: ((Bool) -> Void)? = nil){
        isSharePresented.toggle()
        
        let sharedObjects: [AnyObject] = [text as AnyObject]//, url as AnyObject]
        
        #if os(macOS)
        completionHandler?(false)
        #else
        let av = UIActivityViewController(activityItems: sharedObjects, applicationActivities: [ShareActivity()])
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true) {
            print("[AppCoordinator#share] share view presented")
            completionHandler?(true)
        }
        #endif
    }
    
    public func withImpact(_ impact: FeedbackStyle = .soft, _ action: () -> Void){
        #if os(macOS)
        action()
        #else
        let impactHeavy = UIImpactFeedbackGenerator(style: impact)
        action()
        impactHeavy.impactOccurred()
        #endif
    }
    
    public var isSimulatorOrTestFlight: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        
        let result = path.contains("CoreSimulator") || path.contains("sandboxReceipt")
        return result
    }
    
    public func onConnectionStateChange(_ state: ConnectionState) {
        logger.debug("[\(Self.self)] conection state changed: \(state)")
        self.connectionStateSubject.send((state, Date()))
    }
    
    public struct Modifier: ViewModifier {
        
        let coordinator: AppCoordinator
        
        public init(_ coordinator: AppCoordinator){
            self.coordinator = coordinator
        }
        
        public func body(content: Content) -> some View {
            let view = content.environmentObject(self.coordinator)
            #if os(macOS)
            return view
            #else
            return view.environmentObject(self.coordinator.sheet)
            #endif
        }
        
    }
    
}
