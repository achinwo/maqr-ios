//
//  SpotifyDelegate.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore

class SpotifyDelegate: NSObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate, SPTSessionManagerDelegate {
    
    let SpotifyClientID = "e3966e30011d4895997ce89c797de5a5"
    let SpotifyRedirectURL = URL(string: "joli://spotify-callback/")!
    //URL(string: "spotify-ios-quick-start://spotify-login-callback")!
    
    lazy var configuration = SPTConfiguration(clientID: SpotifyClientID, redirectURL: SpotifyRedirectURL)
    
    let playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
    
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
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        logger.debug("Spotify: created session \(session)")
        
        self.appRemote.connectionParameters.accessToken = session.accessToken
        self.appRemote.connect()
        
        let builder = Builder<AuthToken>.init(properties: [
            AuthToken.CodingKeys.accessToken: session.accessToken as AnyObject,
            AuthToken.CodingKeys.refreshToken: session.refreshToken as AnyObject,
            AuthToken.CodingKeys.scope: session.scope as AnyObject,
            AuthToken.CodingKeys.expiresIn: 3016 as AnyObject,
            AuthToken.CodingKeys.tokenType: "Bearer" as AnyObject,
        ])
        
        builder.save()
            .then(){ auth in
                logger.info("[\(#function)] AUth: \(auth)")
            }//.catch(appState.errorHandler())
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        logger.debug("Spotify: session failure \(error)")
    }
    
    func connect() {
        self.appRemote.authorizeAndPlayURI(self.playURI)
    }
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        logger.debug("Spotify connected!")
        //let playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
        //self.appRemote.authorizeAndPlayURI(playURI)
        
        self.appRemote.playerAPI?.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                logger.debug("Spotify: playstae subsrcibe error: \(error)")
                logger.debug(error.localizedDescription)
                return
            }
            
            logger.info("[PlayerState] \(String(describing: result))")
        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        logger.debug("Spotify: disconnected \(String(describing: error))")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        logger.debug("Spotify: failed: \(String(describing: error))")
    }
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        logger.debug("player state changed")
        
        logger.debug("Track name: \(playerState.track.name) - \(playerState.contextTitle), \(playerState)")
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
    
    func requestSpotifyAccess() {
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
        
        self.spotifySessionManager.alwaysShowAuthorizationDialog = true
        //self.spotifySessionManager.
        self.spotifySessionManager.initiateSession(with: requestedScopes, options: .default)
    }
    
}
