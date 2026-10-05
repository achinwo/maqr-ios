//
//  Playback.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import SharedUI
import Combine
import JoliApi
import JoliCore

public class VideoPlaybackController: PlaybackController, ObservableObject, ConnectablePublisher {
    
    public typealias Failure = Swift.Error
    public typealias Output = JoliCore.ConnectionState
    
    public enum ControllerError: Swift.Error {
        case notImplemented
    }
    
    public func checkInstalled() -> AnyPublisher<Bool, Swift.Error> {
        Future<Bool, Swift.Error>(){ promise in
            promise(.failure(ControllerError.notImplemented))
        }
        .eraseToAnyPublisher()
    }
    
    public var pendingPlayRequest: PlayRequest? = nil
    
    
    public init(){
        
    }
    
    public func play(_ track: Playable, positionMs: Int?, contentOffset: ContentOffset?, completionHandler: (() -> Void)?) {
    }
    
    public func authorize(token: String?) {
        
    }
    
    public func play(_ track: Playable, positionMs: Int?, contextUri: String?, device: Spotify.Device?) -> Future<Any, Error> {
        return Future() { promise in
            
        }
    }
    
    public var combineIdentifier: String {
        return "playback-controller/\(id)"
    }
    
    @Published public var metadata: PlaybackControllerMetadata = PlaybackControllerMetadata(id: "smartz-video",
                                                                                            name: "Smartz Video",
                                                                                            logoImage: .spotifyLogo,
                                                                                            brandColor: .green,
                                                                                            isInstalled: false,
                                                                                            connectionState: .stopped)
    @Published public var connectionState: ConnectionState = .stopped {
        didSet {
            var item = self.metadata
            item.connectionState = connectionState
            item.isInstalled = false
            
            DispatchQueue.main.async {
                self.metadata = item
            }
        }
    }
    
    @Published public var playbackState: PlaybackState? = nil
    @Published public var auth: AuthTokenRecord? = nil
    
    public var metadataPublisher: Published<PlaybackControllerMetadata>.Publisher { $metadata }
    public var playbackStatePublisher: Published<PlaybackState?>.Publisher { $playbackState }
    public var connectionStatePublisher: Published<ConnectionState>.Publisher { $connectionState }
    public var authPublisher: Published<AuthTokenRecord?>.Publisher { $auth }
    
    public func connect() -> Cancellable {
        fatalError("Not Implemented")
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, ConnectionState == S.Input {
        self.subscribe(subscriber)
    }
    
    
}
