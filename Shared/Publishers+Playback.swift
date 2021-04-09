//
//  Publishers+Playback.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import Combine
import SwiftUI

public struct PlaybackControllerMetadata: Equatable, Identifiable, CustomStringConvertible {
    public var id: String
    public var name: String
    public var logoImage: Images
    public var brandColor: Color
    public var isInstalled: Bool
    public var connectionState: JoliCore.ConnectionState
    
    public var description: String {
        return "playback-controller/\(id)/metadata(name: \(name), logoname: \(logoImage), installed: \(isInstalled), connectionstate: \(connectionState))"
    }
}

public protocol PlaybackController: ConnectablePublisher, CustomCombineIdentifierConvertible, Identifiable, ObservableObject where Output == JoliCore.ConnectionState, Failure == Error {
    
    var id: String { get }
    var name: String { get }
    var logoImage: Images { get }
    
    func checkInstalled() -> AnyPublisher<Bool, Error>
    
    var authPublisher: Published<AuthTokenRecord?>.Publisher { get }
    
    var metadata: PlaybackControllerMetadata { get }
    var metadataPublisher: Published<PlaybackControllerMetadata>.Publisher { get }
    
    var connectionState: JoliCore.ConnectionState { get }
    var connectionStatePublisher: Published<JoliCore.ConnectionState>.Publisher { get }
    
    var playbackState: PlaybackState? { get set }
    var playbackStatePublisher: Published<PlaybackState?>.Publisher { get }
    func play(_ track: Playable, positionMs: Int?, contextUri: String?, device: Spotify.Device?) -> Future<Any, Failure>
}

extension PlaybackController {
    
    
    public var id: String {
        metadata.id
    }
    
    public var name: String {
        metadata.name
    }
    
    public var logoImage: Images {
        metadata.logoImage
    }
    
    public func getMetadata() -> AnyPublisher<PlaybackControllerMetadata, Never> {
        
        //        return Future<PlaybackControllerMetadata?, Never>() { promise in
        //            metadataRequest = self.checkInstalled()
        //                .sink() { (completion) in
        //                    switch completion {
        //                        case .failure(let error):
        //                            logger.error("[\(Self.self)#getMetadata] error: \(error.localizedDescription)")
        //                            promise(.success(nil))
        //                        default:
        //                            break
        //                    }
        //                } receiveValue: { installed in
        //                    let value = PlaybackControllerMetadata(id: self.id, name: self.name, logoImage: self.logoImage, isInstalled: installed)
        //                    promise(.success(value))
        //                }
        //        }
        return self.checkInstalled()
            .replaceError(with: false)
            .map() { (installed) -> AnyPublisher<PlaybackControllerMetadata, Never> in
                let value = PlaybackControllerMetadata(id: self.metadata.id,
                                                       name: self.metadata.name,
                                                       logoImage: self.metadata.logoImage,
                                                       brandColor: self.metadata.brandColor,
                                                       isInstalled: installed,
                                                       connectionState: self.connectionState)
                return Just(value).eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
}

public protocol PlaybackState: Playable, CustomStringConvertible {
    var contextTitle: String { get }
    var contextUri: URL { get }
    var isPaused: Bool { get }
    var position: Int { get }
    var speed: Float { get }
    
    var isShuffling: Bool { get }
    var repeatMode: PlaybackRepeatMode { get }
}


public enum PlaybackRepeatMode: UInt {
    case off = 0
    case track = 1
    case context = 2
}
