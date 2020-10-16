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
    
    @Published public var playStatePublisher: PlayState.Publisher
    
    @Published public var devices: [Spotify.Device] = []
    
    public let activeDeviceSubject = CurrentValueSubject<Spotify.Device?, Never>(nil)
    
    public var initialActiveDeviceId: String? = nil
    
    private var allSearchengines = [spotifyEngine]
    
    public func refreshDevices(){
        print("[AppCoordinator#devicesPublisher] fetching devices")
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
    }
    
    public init(_ playStatePublisher: PlayState.Publisher, namespace: Namespace.ID? = nil){
        self.namespace = namespace
        self.playStatePublisher = playStatePublisher
        
        let api = self.api
        let activeDeviceSubject = self.activeDeviceSubject
        let deviceId = initialActiveDeviceId
        
        
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
                        .then(on: .main) { $0 }
            }
        }
        
        return track.play(deviceId: device.id, positionMs: positionMs, baseUrl: self.api.baseUrl.http, urlSession: self.api.urlSession, on: DispatchQueue.global(qos: .userInitiated))
            .then(on: .main) { $0 }
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
