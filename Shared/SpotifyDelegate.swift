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
    
    public var pendingPlayRequest: PlayRequest? = nil
    
    public func play(_ track: Playable, positionMs: Int?, contentOffset: ContentOffset? = nil, completionHandler: (() -> Void)? = nil) {
        
        let onComplete = {
            self.pendingPlayRequest = nil
            completionHandler?()
        }
        
        guard appRemote.isConnected else {
            
            self.pendingPlayRequest = (track, positionMs, contentOffset, onComplete)
            
            Swift.print("[App#$localPlayRequested] set pending: \(String(describing: self.pendingPlayRequest?.track.title)) - \(String(describing: self.pendingPlayRequest?.positionMs)) - \(String(describing: self.pendingPlayRequest?.contentOffset))")
            
            
            #if APPCLIP
            self.authorizationHandler?()
            #else
            let mgr = self.requestSpotifyAccess(trackUri: track.uri)
            logger.debug("[authorizeSpotify] spotify authresult: \(String(describing: mgr))")
            #endif
            
            
            return
        }
        
        let callback: SPTAppRemoteCallback = { (res, error) in
            
            guard let positionMs = positionMs else {
                completionHandler?()
                return
            }
            
            self.appRemote.playerAPI?.seek(toPosition: positionMs) { (res, error) in
                Swift.print("[\(Self.self)#$localPlayRequested] seek to \(positionMs): \(String(describing: res)) - \(String(describing: error))")
                onComplete()
            }
        }
        
        Swift.print("[\(Self.self)#$localPlayRequested] local play: \(track.title)")
        if let contextUri = contentOffset?.uri {
                
            let playPlaylistLocal = { (item: SPTAppRemoteContentItem, position: Int) in
                self.appRemote.playerAPI?.play(item, skipToTrackIndex: position, callback: callback)
            }
            
            self.appRemote.contentAPI?.fetchContentItem(forURI: contextUri) { item, error in
                Swift.print("[\(Self.self)#$localPlayRequested] local play playlsit: \(String(describing: (item as? SPTAppRemoteContentItem)?.children)) --- \(String(describing: error))")
                
                guard let sptItem = item as? SPTAppRemoteContentItem else {
                    return
                }
                
                guard let position = contentOffset?.position else {
                    
                    self.appRemote.contentAPI?.fetchChildren(of: sptItem) { children, error in
                        
                        guard let contentItems = children as? [SPTAppRemoteContentItem] else {
                            return
                        }
                        ///spotifyRemote.contentAPI
                        Swift.print("[\(Self.self)] fetchChildren: \(contentItems.map({$0.subtitle})) --- \(String(describing: error))")
                        
                        let idx = contentItems.firstIndex() { itm in
                            return itm.uri == track.uri
                        }
                        
                        playPlaylistLocal(sptItem, idx ?? 0)
                    }
                    return
                }
                
                playPlaylistLocal(sptItem, position)
            }
        } else {
            self.appRemote.playerAPI?.play(track.uri, asRadio: true, callback: callback)
        }
    }
    
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
    
    
    public init(authCallbackUrl: URL, authRefreshUrl: URL) {
        self.authCallbackUrl = authCallbackUrl
        self.authRefreshUrl = authRefreshUrl
        
        super.init()
        
        DispatchQueue.main.async {
            var meta = self.metadata
            meta.isInstalled = self.isSpotifyAppInstalled
            self.metadata = meta
        }
    }
    
    public typealias Failure = Error
    public typealias Output = JoliCore.ConnectionState
    
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
    
    lazy var configuration = SPTConfiguration(clientID: SpotifyClientID, redirectURL: SpotifyRedirectURL)
    
    let authCallbackUrl: URL
    let authRefreshUrl: URL
    
    lazy var appRemote: SPTAppRemote = {
        
        self.configuration.tokenSwapURL = authCallbackUrl
        self.configuration.tokenRefreshURL = authRefreshUrl
        
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
        self.remoteConnect(token: token) { error in
            self.pendingConnectCallback = nil
        }
    }
    
    private var pendingConnectCallback: ((Error?) -> Void)? = nil
    
    private func remoteConnect(token: String? = nil, callback: @escaping (Error?) -> Void){
        
        guard !self.appRemote.isConnected else {
            return callback(nil)
        }
        
        self.pendingConnectCallback = callback
        
        let token = token ?? accessToken
        self.appRemote.connectionParameters.accessToken = token
        self.appRemote.connect()
    }
    
    lazy var spotifySessionManager: SPTSessionManager = {
        
        var configuration = SPTConfiguration(
            clientID: SpotifyClientID,
            redirectURL: SpotifyRedirectURL //URL(string: "joli://spotify-callback/")!
        )
        
        configuration.tokenSwapURL = authCallbackUrl
        configuration.tokenRefreshURL = authRefreshUrl
        
        configuration.playURI = nil
        
        return SPTSessionManager(configuration: configuration, delegate: self)
    }()
    
    lazy var isSpotifyAppInstalled = {
        return spotifySessionManager.isSpotifyAppInstalled
    }()
    
    var authorizationHandler: (() -> Void)? = nil
    
    public func authorize(token: String? = nil) -> Void {
        #if APPCLIP
        self.authorizationHandler?()
        #else
        requestSpotifyAccess(token: token)
        #endif
    }
    
    #warning("fix spt reconnect callback")
    @discardableResult
    func requestSpotifyAccess(trackUri: String? = nil, token: String? = nil, alwaysShowAuthorizationDialog: Bool = false) -> SPTSessionManager? {
        //"app-remote-control streaming user-modify-playback-state user-read-playback-state user-read-currently-playing user-read-birthdate user-read-email user-read-private"
        
        guard !appRemote.isConnected else {
            logger.debug("[authorizeSpotify] spotify remote is not initialized")
            remoteConnect(token: token) { error in
                guard self.appRemote.isConnected, error == nil else {
                    self.pendingConnectCallback?(error)
                    return
                }
                
                self.requestSpotifyAccess(trackUri: trackUri,
                                          token: token,
                                          alwaysShowAuthorizationDialog: alwaysShowAuthorizationDialog)
            }
            return nil
        }
        
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
        
        configuration.tokenSwapURL = authCallbackUrl
        //https://localhost:8080/spotify_callback/
        configuration.tokenRefreshURL = authRefreshUrl
        
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
        
        self.appRemote.playerAPI?.delegate = self
        self.connectionState = .connected
        
        guard let pending = pendingPlayRequest else { return }
        
        self.play(pending.track, positionMs: pending.positionMs, contentOffset: pending.contentOffset, completionHandler: pending.completionHandler)
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
        self.playbackState = SpotifyPlaybackState(playerState)
        
        guard let pendingPlayRequest = pendingPlayRequest,
              let positionMs = pendingPlayRequest.positionMs,
              pendingPlayRequest.track.uri == playerState.track.uri,
              positionMs >= 0 else {
            self.pendingPlayRequest?.completionHandler?()
            return
        }
        
        //print("[App#onLocalSpotifyPlayStateChanged] seek to \(pendingLocalPlayPosition)...")
        
        appRemote.playerAPI?.seek(toPosition: positionMs) { (res, error) in
            Swift.print("[\(Self.self)#onLocalSpotifyPlayStateChanged] seek to \(positionMs): \(String(describing: res)) - \(String(describing: error))")
        }
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
