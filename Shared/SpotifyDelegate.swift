//
//  SpotifyDelegate.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import Combine

public struct SpotifyPlaybackState: PlaybackState, CustomStringConvertible, CustomDebugStringConvertible {
    
    private let sptState: SPTAppRemotePlayerState
    
    public init(_ spotifyPlayerState: SPTAppRemotePlayerState){
        self.sptState = spotifyPlayerState
    }
    
    public var contextTitle: String {
        return sptState.contextTitle
    }
    
    public var description: String {
        return sptState.description
    }
    
    public var debugDescription: String {
        return sptState.debugDescription ?? self.description
    }
    
    public var isPaused: Bool {
        return sptState.isPaused
    }
    
    public var explicit: Bool {
        return true
    }
    
    public var contextUri: URL {
        return self.sptState.contextURI
    }
    
    public var repeatMode: PlaybackRepeatMode {
        return PlaybackRepeatMode(rawValue: self.sptState.playbackOptions.repeatMode.rawValue) ?? PlaybackRepeatMode.off
    }
    
    public var isShuffling: Bool {
        return self.sptState.playbackOptions.isShuffling
    }
    
    public var speed: Float {
        return self.sptState.playbackSpeed
    }
    
    public var position: Int {
        return self.sptState.playbackPosition
    }
    
    public var title: String {
        self.sptState.track.name
    }
    
    public var thumbnailUrl: String {
        self.sptState.track.imageIdentifier
    }
    
    public var albumCoverUrl: String {
        self.sptState.track.imageIdentifier
    }
    
    public var artistName: String {
        self.sptState.track.artist.name
    }
    
    public var uri: String {
        self.sptState.track.uri
    }
    
    public var isPlayable: Bool {
        return true
    }
    
    public var duration: Int {
        Int(self.sptState.track.duration)
    }
    
    public var releasedAt: Date? {
        return nil
    }
    
}

public class SpotifyDelegate: NSObject, PlaybackController {
    
    public func checkInstalled() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error>(){ promise in
            promise(.success(self.isSpotifyAppInstalled))
        }
        .eraseToAnyPublisher()
    }
    
    public func play(_ track: Playable, positionMs: Int?, contextUri: String?, device: Spotify.Device?) -> Future<Any, Error> {
        return Future() { promise in
            
        }
    }
    
    public var combineIdentifier: String {
        return "playback-controller/\(id)"
    }
    
    @Published public var metadata: PlaybackControllerMetadata = PlaybackControllerMetadata(id: "spotify",
                                                                                            name: "Spotify",
                                                                                            logoImage: .spotifyLogo,
                                                                                            brandColor: .green,
                                                                                            isInstalled: false,
                                                                                            connectionState: .stopped)
    @Published public var connectionState: ConnectionState = .stopped {
        didSet {
            var item = self.metadata
            item.connectionState = connectionState
            item.isInstalled = isSpotifyAppInstalled
            
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
    
    
    public override init() {
        super.init()
        
        DispatchQueue.main.async {
            var meta = self.metadata
            meta.isInstalled = self.isSpotifyAppInstalled
            self.metadata = meta
        }
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        self.subscribe(subscriber)
    }
    
    public func connect() -> Cancellable {
        
        let cancellation = AnyCancellable() {
            logger.debug("[\(Self.self)#\(#function)] disconnecting...")
            self.appRemote.disconnect()
        }
        
        guard !self.appRemote.isConnected else {
            return cancellation
        }
        
        self.remoteConnect()
        
        return cancellation
    }
    
    let SpotifyClientID = "e3966e30011d4895997ce89c797de5a5"
    let SpotifyRedirectURL = URL(string: "joli://spotify-callback/")!
    //URL(string: "spotify-ios-quick-start://spotify-login-callback")!
    
    var authCallback: ((AuthToken?, Error?) -> Void)? = nil
    var playStateCallback: ((SPTAppRemotePlayerState) -> Void)? = nil
    
    lazy var configuration = SPTConfiguration(clientID: SpotifyClientID, redirectURL: SpotifyRedirectURL)
    
    lazy var appRemote: SPTAppRemote = {
        
        self.configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        self.configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!
        
        let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    static private let kAccessTokenKey = "access-token-key"
    
    var accessToken = UserDefaults.standard.string(forKey: kAccessTokenKey) {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(accessToken, forKey: Self.kAccessTokenKey)
        }
    }
    
    public func remoteConnect(token: String? = nil){
        
        guard !self.appRemote.isConnected else {
            return
        }
        
        let token = token ?? accessToken
        self.appRemote.connectionParameters.accessToken = token
        self.appRemote.connect()
    }
    
    lazy var spotifySessionManager: SPTSessionManager = {
        
        var configuration = SPTConfiguration(
            clientID: SpotifyClientID,
            redirectURL: SpotifyRedirectURL //URL(string: "joli://spotify-callback/")!
        )
        
        configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        //https://localhost:8080/spotify_callback/
        configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!
        
        configuration.playURI = nil
        
        return SPTSessionManager(configuration: configuration, delegate: self)
    }()
    
    lazy var isSpotifyAppInstalled = {
        return spotifySessionManager.isSpotifyAppInstalled
    }()
    
    @discardableResult
    func requestSpotifyAccess(trackUri: String? = nil, alwaysShowAuthorizationDialog: Bool = false) -> SPTSessionManager {
        //"app-remote-control streaming user-modify-playback-state user-read-playback-state user-read-currently-playing user-read-birthdate user-read-email user-read-private"
        let requestedScopes: SPTScope = [
            .appRemoteControl,
            .streaming,
            .userModifyPlaybackState,
            .userReadPlaybackState,
            .userReadCurrentlyPlaying,
            .userReadBirthDate,
            .userReadEmail,
            .userReadRecentlyPlayed,
            .userReadPrivate,
            .playlistModifyPrivate,
            .playlistModifyPublic,
            .playlistReadPrivate
        ]
        
        let configuration = SPTConfiguration(
            clientID: SpotifyClientID,
            redirectURL: SpotifyRedirectURL //URL(string: "joli://spotify-callback/")!
        )
        
        configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        //https://localhost:8080/spotify_callback/
        configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!
        
        configuration.playURI = trackUri
        let mgr = SPTSessionManager(configuration: configuration, delegate: self)
        
        mgr.alwaysShowAuthorizationDialog = alwaysShowAuthorizationDialog
        mgr.initiateSession(with: requestedScopes, options: .default)
        
        return mgr
    }
    
}

extension SpotifyDelegate: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate, SPTSessionManagerDelegate {
    
    public func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        logger.debug("Spotify: session failure \(String(describing: error))")
    }
    
    public func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        logger.debug("Spotify connected!")
        //let playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
        //self.appRemote.authorizeAndPlayURI(playURI)
        
        self.appRemote.playerAPI?.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                logger.debug("Spotify: playstae subsrcibe error: \(String(describing: error))")
                return
            }
            
            logger.info("[PlayerState] \(String(describing: result))")
        })
        self.connectionState = .connected
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        logger.debug("Spotify: disconnected \(String(describing: error))")
        self.connectionState = .stopped
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        logger.debug("Spotify: failed: \(String(describing: error))")
        self.connectionState = .stopped
    }
    
    public func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        logger.debug("Track name: \(playerState.track.name) - \(playerState.contextTitle), \(String(describing: playerState))")
        self.playStateCallback?(playerState)
        self.playbackState = SpotifyPlaybackState(playerState)
    }
    
    public func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        logger.debug("Spotify: created session \(session)")
        
        remoteConnect(token: session.accessToken)
        
        self.auth = Builder<AuthToken>.init(properties: [
            .accessToken: session.accessToken as AnyObject,
            .refreshToken: session.refreshToken as AnyObject,
            .scope: session.scope as AnyObject,
            .expiresIn: 3016 as AnyObject,
            .tokenType: "Bearer" as AnyObject,
        ])
        
    }
    
}
