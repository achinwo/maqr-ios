//
//  AppState+Spotify.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/06/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import Promises
import JoliCore

extension AppState {
    
    // MARK: - fetchSpotifyRecommendations
    public func fetchSpotifyRecommendations() -> Promise<Spotify.Recommendation> {
        var path = URLComponents(string: "/api/spotify/recommendations")!
        
        path.queryItems = [
            URLQueryItem(name: "limit", value: "10"),//
            URLQueryItem(name: "min_energy", value: "0.4"),
            URLQueryItem(name: "seed_genres", value: "afrobeat"),
            URLQueryItem(name: "seed_artists", value: ""),
            URLQueryItem(name: "seed_tracks", value: "44SSviC4R1TkAdsyptjDpE"),
        ]
        return HttpMethod.Fetch.get(url: path, dataType: Spotify.Recommendation.self, baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
    }
    
    @discardableResult
    func fetchSpotifyDevices() -> Promise<[Spotify.Device]> {
        return api.fetchSpotifyDevices(on: DispatchQueue.main)
            .then() { devices in
                logger.debug("Devices: \(devices)")
                self.spotifyDevices = devices
                
                if self.selectedSpotifyDeviceIdx != nil || devices.isEmpty {
                    return
                }
                
                self.selectedSpotifyDeviceIdx = devices.firstIndex() { $0.isActive }
        }
        .catch(){ error in
            logger.error("[fetchSpotifyDevices] error: \(String(describing: error))")
        }
    }
    
    func spotifyWebAuthorize(_ urlPath: URLComponents) -> Promise<AuthToken> {
        spotifyAuthorizationInProgress = true
        
        return HttpMethod.Fetch.get(url: urlPath,
                                    dataType: AuthToken.self,
                                    baseUrl: api.baseUrl.rawValue.http,
                                    urlSession: api.urlSession)
            .then(){ auth -> Promise<AuthToken> in
                //self.spotifyWebAuthorized = !auth.isExpired
                return Promise(auth)
        }
        .always() {
            self.spotifyAuthorizationInProgress = false
        }
    }
    
    func resolveSpotifyRedirectUrl(_ url: URL) -> URL? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        guard let scheme = components?.scheme,
            let basePath = components?.host,
            let codeQuery = components?.queryItems?.first(where: { $0.name == "code" }),
            [AppState.URL_SCHEME, "spotify-ios-quick-start"].contains(scheme),
            [AppState.SPOTIFY_URL_BASEPATH, "spotify-login-callback"].contains(basePath) else {
            return nil
        }
        
        var redirectUrl = URLComponents(string: "/spotify_callback")
        redirectUrl?.queryItems = [codeQuery,
                                   URLQueryItem(name: "redirect",
                                                value: (scheme == AppState.URL_SCHEME ?
                                                    "joli://\(AppState.SPOTIFY_URL_BASEPATH)"
                                                    : "https://localhost:8080/spotify_callback/"
                                                    //: "spotify-ios-quick-start://spotify-login-callback/"
                                   )),
                                   URLQueryItem(name: "platform", value: "ios")]
        
        return redirectUrl?.url(relativeTo: api.baseUrl.rawValue.http)
    }
    
    func openSpotifyWebAuthorization(){
        var components = URLComponents(string: "/spotify_login")!
        components.queryItems = [URLQueryItem(name: "platform", value: "ios")]
        
        let url = components.url(relativeTo: baseUrl.http)!
        
        UIApplication.shared.open(url)
    }
    
    // MARK: - fetchSpotifyAuth
    public func fetchSpotifyAuthToken() -> Promise<AuthToken> {
        
        guard self.auth != nil else {
            return Promise<AuthToken>(SpotifyError.unathorized)
        }
        
        return HttpMethod.Fetch.post(url: "/api/spotify/auth", dataType: AuthToken.self,
                                    baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
    }
    
    
    func assertSpotifyAuthorized(caller: String = #function) {
        DispatchQueue.main.async {
            self.spotifyAuthorizationInProgress = true
        }
        
        self.fetchSpotifyAuthToken()
        .then() { auth in
            self.spotifyWebAuth = auth
        }
        .catch() { error in
            self.errorHandler("fetchSpotifyAuthToken#\(caller)")(error)
            self.spotifyWebAuth = nil
            
            self.currentlyPlaying.track = nil
            self.currentlyPlaying.content = nil
        }
        .always {
            self.spotifyAuthorizationInProgress = false
        }
    }
    
}
