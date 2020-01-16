//
//  SceneDelegate.swift
//  Joli
//
//  Created by Anthony Chinwo on 25/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import UIKit
import SwiftUI
import MediaPlayer
import JoliApi
import JoliCore

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = volume
        }
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate, SPTSessionManagerDelegate {
    
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
        }.catch(appState.errorHandler())
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        logger.debug("Spotify: session failure \(error)")
    }

    var window: UIWindow?
    var appState: AppState {
        (UIApplication.shared.delegate as! AppDelegate).appState
    }
    
    var appDelegate: AppDelegate {
        (UIApplication.shared.delegate as! AppDelegate)
    }
    
    let SpotifyClientID = "e3966e30011d4895997ce89c797de5a5"
    let SpotifyRedirectURL = URL(string: "spotify-ios-quick-start://spotify-login-callback")!

    lazy var configuration = SPTConfiguration(
      clientID: SpotifyClientID,
      redirectURL: SpotifyRedirectURL
    )
    
    let playURI = "spotify:track:20I6sIOMTCkB6w7ryavxtO"
    
    lazy var appRemote: SPTAppRemote = {
        
        self.configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        self.configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!

        let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    lazy var spotifySessionManager: SPTSessionManager = {
        
        var configuration = SPTConfiguration(
          clientID: SpotifyClientID,
          redirectURL: SpotifyRedirectURL //URL(string: "joli://spotify-callback/")!
        )
        
        configuration.tokenSwapURL = URL(string: "https://192.168.1.173:8080/spotify_callback/")!
        //https://localhost:8080/spotify_callback/
        configuration.tokenRefreshURL = URL(string: "https://192.168.1.173:8080/api/spotify/refresh")!
        
        configuration.playURI = ""
        
        return SPTSessionManager(configuration: configuration, delegate: self)
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
                                         .userReadPrivate
        ]
        self.spotifySessionManager.alwaysShowAuthorizationDialog = true
        //self.spotifySessionManager.
        self.spotifySessionManager.initiateSession(with: requestedScopes, options: .default)
    }
    
    lazy var isSpotifyAppInstalled = {
        return spotifySessionManager.isSpotifyAppInstalled
    }()
    
    static private let kAccessTokenKey = "access-token-key"
    
    var accessToken = UserDefaults.standard.string(forKey: kAccessTokenKey) {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(accessToken, forKey: SceneDelegate.kAccessTokenKey)
        }
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
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        
        logger.info("[SceneDelegate] url: \(url)")
        
        if let redirectUrl = appState.resolveSpotifyRedirectUrl(url), let urlComp = URLComponents(url: redirectUrl, resolvingAgainstBaseURL: false) {
            appState.spotifyWebAuthorize(urlComp)
            .then() { auth in
                logger.info("[SceneDelegate] spotify auth recieved: \(auth)")
            }
            .catch() { error in
                logger.error("[SceneDelegate] spotify auth error: \(error)")
            }
            return
        }
        
        let parameters = appRemote.authorizationParameters(from: url);
        logger.info("[\(#function)] spotify auth params: \(String(describing: parameters))")
        if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = access_token
            self.accessToken = access_token
        } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
            logger.debug("Spotify error:", error_description)
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Create the SwiftUI view that provides the window contents.
        //let env: EnvironmentObject<AppState> = EnvironmentObject();
        let contentView = AppView()
            .environmentObject(appState)
            .environmentObject(appState.currentlyPlaying)
            .environmentObject(appState.keyboardState)

        logger.debug("Spootify app installed: \(spotifySessionManager.isSpotifyAppInstalled)")
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        logger.debug("[SceneDelegate] App is inactive")
        appState.api.wsClient.disconnect()
    }

    
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        
        //appState.api.wsClient.connect()
        if let _ = self.appRemote.connectionParameters.accessToken {
          self.appRemote.connect()
        }
        
        //connect()
    }
    
    func connect() {
      self.appRemote.authorizeAndPlayURI(self.playURI)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        logger.debug("[SceneDelegate] sceneWillResignActive")
        //appDelegate.stopObservingVolumeChanges()
        
        if self.appRemote.isConnected {
          self.appRemote.disconnect()
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        logger.debug("[SceneDelegate] App is active")
        appState.api.wsClient.connect() { connectionState in
            self.appState.onServerConnectionStateChanged(connectionState)
        }
        
//        do {
//            try appDelegate.audioSession.setActive(true)
//            appDelegate.startObservingVolumeChanges()
//
//            guard let deviceVolume = appState.spotifyDevice?.volumePercent else { return }
//
//            MPVolumeView.setVolume(Float(deviceVolume) / 100.0)
//            logger.debug("[SceneDelegate] App is active - setting volume to \(Float(deviceVolume) / 100.0)")
//        } catch {
//            logger.debug("[SceneDelegate] Failed to activate audio session")
//        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

