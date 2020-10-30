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
    
    @Published public var playStatePublisher: PlayState.Publisher
    
    @Published public var devices: [Spotify.Device] = []
    
    public let activeDeviceSubject = CurrentValueSubject<Spotify.Device?, Never>(nil)
    public let playingSubject = CurrentValueSubject<(Playable, PlayState)?, Never>(nil)
    public let volumeSubject = PassthroughSubject<Int, Never>()
    
    public let playRequestedSubject = CurrentValueSubject<Bool, Never>(false)
    public let voteRequestedSubject = CurrentValueSubject<Int?, Never>(nil)
    
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
    
    private var allSearchengines = [spotifyEngine]
    
    public enum ActionError: Error {
        case insufficientHeartPoints
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
    
    public init(_ playStatePublisher: PlayState.Publisher, namespace: Namespace.ID? = nil){
        self.namespace = namespace
        self.playStatePublisher = playStatePublisher
        
        //let activeDeviceSubject = self.activeDeviceSubject
        //let deviceId = initialActiveDeviceId
        
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
    
    public func play(_ track: Playable, positionMs: Int? = nil, device: Spotify.Device? = nil) -> Promise<PlayState?> {
        
        guard let device = device else {
            return api.fetchSpotifyDevices(on: DispatchQueue.global(qos: .userInitiated))
                .catch(){ error in
                    logger.error("[fetchSpotifyDevices] error: \(error)")
                }
                .then() { (devices) -> Promise<PlayState?> in
                    logger.debug("Devices: \(devices)")
                    
                    guard let device = devices.first(where: { $0.isActive }) ?? devices.first(where: { $0.type == .computer }) else {
                        return Promise(nil)
                    }
                    
                    return track.play(deviceId: device.id, positionMs: positionMs, baseUrl: self.api.baseUrl.http, urlSession: self.api.urlSession, on: DispatchQueue.global(qos: .userInitiated))
                        .then(on: .main) { ps in
                            self.playingSubject.send((track, ps))
                            return Promise(ps)
                        }
            }
        }
        
        return track.play(deviceId: device.id, positionMs: positionMs, baseUrl: self.api.baseUrl.http, urlSession: self.api.urlSession, on: DispatchQueue.global(qos: .userInitiated))
            .then(on: .main) { ps in
                self.playingSubject.send((track, ps))
                return Promise(ps)
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
