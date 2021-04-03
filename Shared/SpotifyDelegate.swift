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
    
    public func play(_ track: Playable, positionMs: Int?, contextUri: String?, device: Spotify.Device?) -> Future<Any, Error> {
        return Future() { promise in
            
        }
    }
    
    public var combineIdentifier: String {
        return "PlaybackController/Spotify"
    }
    
    @Published public var connectionState: ConnectionState = .stopped
    @Published public var playbackState: PlaybackState? = nil
    
    public var playbackStatePublisher: Published<PlaybackState?>.Publisher { $playbackState }
    
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
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        logger.debug("Spotify: disconnected \(String(describing: error))")
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        logger.debug("Spotify: failed: \(String(describing: error))")
    }
    
    public func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        logger.debug("Track name: \(playerState.track.name) - \(playerState.contextTitle), \(String(describing: playerState))")
        self.playStateCallback?(playerState)
        self.playbackState = SpotifyPlaybackState(playerState)
    }
    
    public func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        logger.debug("Spotify: created session \(session)")
        
        remoteConnect(token: session.accessToken)
        
        let builder = Builder<AuthToken>.init(properties: [
            .accessToken: session.accessToken as AnyObject,
            .refreshToken: session.refreshToken as AnyObject,
            .scope: session.scope as AnyObject,
            .expiresIn: 3016 as AnyObject,
            .tokenType: "Bearer" as AnyObject,
        ])
        
        builder.save()
            .then(){ auth in
                logger.info("[\(#function)] AUth: \(auth)")
                self.authCallback?(auth, nil)
            }
            .catch() { error in
                self.authCallback?(nil, error)
            }
    }
    
}
