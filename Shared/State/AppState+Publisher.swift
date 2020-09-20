//
//  AppState+Publisher.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/06/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import Combine
import JoliCore
import JoliApi

extension AppState {
    
    static var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> = {
        logger.info("[AppState] init keyboardHeightPublisher")
        return Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
                .map { $0.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        ).eraseToAnyPublisher()
    }()
    
    var trackSearchResultPublisher: AnyPublisher<[Spotify.Track], Never> {
        $searchText
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .background))
            .map { input -> Future<[Spotify.Track], Never> in
                
                if let curr = self.currentSearchFuture{
                    curr.reject(FetchError.cancelled)
                }
                
                return Future<[Spotify.Track], Never>() { promise in
                    
                    guard !input.trimmingCharacters(in: [" "]).isEmpty else {
                        promise(.success([]))
                        return
                    }
                    
                    self.currentSearchFuture = self.api.searchTracks(q: input, limit: 25)
                        .then() { promise(.success($0.tracks)) }
                        .catch() { logger.debug("[AppState] trackSearchResult: \($0)") }
                    
                }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
    func initReactive(){
        // MARK: - initialize (Authentication Handler)
        self.api.$auth
            .receive(on: RunLoop.main)
            //.assign(to: \.auth, on: self)
            .sink { auth in
                self.auth = auth
                self.userSettings.authToken = auth?.session.token
                //logger.info("[AppState] storing token: \(String(describing: self.userSettings.authToken))")
                
                if auth == nil {
                    self.spotifyWebAuth = nil
                }
                
                self.updateAlerts(.loginRequired, add: auth == nil ? true : false)
                self.fetchMusicrooms()
            }
            .store(in: &cancellableSet)
        
        trackSearchResultPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.trackSearchResult, on: self)
            .store(in: &cancellableSet)
        
        self.$deviceVolume
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .userInteractive))
            .eraseToAnyPublisher()
            .sink() { volume in
                
                guard let device = self.spotifyDevice else {
                    return
                }
                
                self.api.setVolume(Int(volume), deviceId: device.id)
                print("[AppState] setting volume: \(Int(volume))")
            }
            .store(in: &cancellableSet)
        
        self.$activeRoom
            .receive(on: RunLoop.main)
            .sink { room in
                
                guard var user = self.api.auth?.user else {
                    return
                }
                
                user.activeRoomId = room?.id //.setActiveRoom(room, baseUrl: api.baseUrl.http, )
                user.save(baseUrl: self.api.baseUrl.http,
                          urlSession: self.api.urlSession,
                          on: nil)
                    .catch(self.errorHandler())
            }
            .store(in: &cancellableSet)
        
        api.subscribe(subject: .playerStateChanged){ (response, error) in
            
            guard let ctx = response?.payload,
                  let rawData = try? ctx.toData(),
                  let cPlaying = try? Spotify.CurrentlyPlayingContent.fromData(rawData)
            else {
                self.setAudioSession(false)
                return
            }
            logger.info("[\(JoliApi.Subject.playerStateChanged.rawValue)] playing: \(cPlaying.isPlaying)")
            
            self.setAudioSession(cPlaying.isPlaying)
        }
        
        api.subscribe(subject: .playerStateNowPlaying){ (result, error) in
            
            let data = result?.payload
            
            guard let ctx = data,
                  let rawData = try? ctx.toData(),
                  let cPlaying = try? Spotify.CurrentlyPlayingContent.fromData(rawData)
            else {
                return
            }
            
            let progress = (Double(cPlaying.progressMs) / Double(cPlaying.item.durationMs)) * 100
            
            self.currentlyPlaying.content = cPlaying
            self.currentlyPlaying.track = cPlaying.item
            self.currentlyPlaying.progressPct = progress
            
            if self.currentlyPlayingAlbumUrl == nil || self.currentlyPlayingAlbumUrl! != cPlaying.item.albumCoverUrl {
                self.currentlyPlayingAlbumUrl = cPlaying.item.albumCoverUrl
                
                self.fetchedImage(url: cPlaying.item.albumCoverUrl)
                    .then() { imgObj in
                        self.currentlyPlaying.albumImage = imgObj
                    }
            }
            
        }
        
        api.subscribe(subject: .activityFeed) { (result, error) in
            logger.debug("Activity: \(String(describing: result)) - \(String(describing: error))")
        }
        
        // MARK: - Database Updates
        api.subscribe(subject: .dbUpdates) { (result, error) in
            logger.debug("DbUpdates: \(String(describing: result)) - \(String(describing: error))")
            guard let typeName = result?.payload["type"] as? String, QueuedTrackVote.className() == typeName else {
                return
            }
            
            self.fetchTrackVotes()
        }
        
        self.$spotifyWebAuth
            .removeDuplicates()
            .sink() { authToken in
                let spotifyConnected = authToken != nil
                let urlSuffix = spotifyConnected ? ".original" : ".noir"
                
                for (url, img) in self.imagesByUrl {
                    if !url.hasSuffix(urlSuffix) {
                        continue
                    }
                    
                    let targetUrl = String(url.prefix(upTo: url.index(url.endIndex, offsetBy: urlSuffix.count * -1)))
                    self.imagesByUrl[targetUrl] = img
                }
                
                if let cover = self.currentlyPlayingAlbumUrl, let newImage = self.imagesByUrl["\(cover)\(urlSuffix)"] {
                    self.currentlyPlaying.albumImage = newImage
                }
                
                if spotifyConnected {
                    self.fetchSpotifyDevices()
                        .always {
                            self.updateAlerts(.spotifyWebAuthRequired, add: false)
                            Spotify.CurrentlyPlayingContent.fetch(baseUrl: self.api.baseUrl.http,
                                                                  urlSession: self.api.urlSession)
                        }
                } else {
                    self.updateAlerts(.spotifyWebAuthRequired, add: true)
                }
            }.store(in: &cancellableSet)
    }
    
}
