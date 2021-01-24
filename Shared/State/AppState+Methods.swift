//
//  AppState+Methods.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/06/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import Promises
import JoliCore
import SwiftUI

extension AppState {
    
    
    func setAudioSession(_ enabled: Bool){
        do {
            try appDelegate.audioSession.setActive(enabled)
            try appDelegate.audioSession.setCategory(.ambient)
            
            if enabled {
                appDelegate.startObservingVolumeChanges()
            }else{
                appDelegate.stopObservingVolumeChanges()
            }
            logger.debug("[setAudioSession] App is active")
        } catch {
            logger.debug("[setAudioSession] Failed to update audio session: \(error)")
        }
    }
    
    func triggerAndClearDeviceCallbacks(device: Spotify.Device? = nil, cancelled: Bool = false){
        for callback in self.deviceReadyCallbacks {
            do{
                try callback(device ?? self.spotifyDevice, cancelled)
            }catch{
                logger.error("[triggerAndClearDeviceCallbacks] \(error)")
            }
        }
        self.deviceReadyCallbacks.removeAll()
    }
    
    func assertSelectedDevice(_ callback: @escaping DeviceReadyCallback) {
        if let spotifyDevice = spotifyDevice {
            try? callback(spotifyDevice, false)
            return
        }
        
        self.deviceReadyCallbacks.append(callback)
        
        guard spotifyDevices.isEmpty else {
            self.isDeviceChooserPresented = true
            return
        }
        
        fetchSpotifyDevices()
            .then() { devices in
                self.isDeviceChooserPresented = true
        }.catch() { error in
            guard case let NetworkError.errorMessage(err) = error, let message = err.message else{
                return
            }
            
            logger.warning("[assertSelectedDevice] spotify: \(message) - \(message == Spotify.ErrorMessage.invalidAccessToken.rawValue)")
            try? callback(nil, false)
            
            //self.openSpotifyWebAuthorization()
            self.spotifyDelegate.requestSpotifyAccess()
        }
    }
    
    func updateAlerts(_ alert: ServiceAlert, add: Bool = true){
        var existingAlerts = self.alerts
        if add {
            existingAlerts.insert(alert)
        } else {
            existingAlerts.remove(alert)
        }
        
        DispatchQueue.main.async {
            self.alerts = existingAlerts
        }
    }
    
    
    // MARK: - errorHandler
    public func errorHandler(_ funcName: String = #function) -> (Error) -> Void {
        return { (error: Error) in
            logger.error("[\(funcName)] error: \(error)")
            
            guard case let NetworkError.errorMessage(err) = error,
                let message = err.message,
                message == Spotify.ErrorMessage.invalidAccessToken.rawValue
            else {
                return
            }
            
            self.spotifyWebAuth = nil
        }
    }

        func queueTrack(_ track: Playable) -> Promise<QueuedTrack> {
            guard let activeRoom = self.activeRoom else {
                fatalError("Cant queue track without active musicroom")
            }
            
            return activeRoom.queueTrack(track, baseUrl: baseUrl.http, urlSession: api.urlSession, on: nil)
                .then() { queuedTrack in
                    logger.info("[queueTrack] queued: \(queuedTrack)")
                    self.fetchQueuedTracks(activeRoom)
            }.catch() { error in
                logger.error("[queueTrack] \(error)")
                self.assertSpotifyAuthorized()
            }
        }
        
        @discardableResult
        func playTrack(_ track: Playable, positionMs: Int? = nil) -> Promise<Void> {
    //        if track is Spotify.Track {
    //
    //            setAudioSession(false)
    //
    //            guard spotifyRemote.isConnected else {
    //                logger.debug("[Track#play] spotify not connected")
    //                spotifyRemote.authorizeAndPlayURI(track.uri)
    //                return
    //            }
    //
    //            spotifyRemote.playerAPI?.play(track.uri){ info, error in
    //                logger.debug("[Track#play] \(String(describing: info)) - \(String(describing: error))")
    //            }
    //        }else{
            
            return Promise() { (resolve, reject) in
                self.assertSelectedDevice() { [weak self] (device, cancelled) in
                    logger.debug("[Track#play] assertion completed - \(String(describing: device))")
                    
                    guard !cancelled else { return }
                    
                    guard self?.selectedSpotifyDeviceIdx == nil else {
                        track.play(deviceId: device?.id, positionMs: positionMs, baseUrl: self?.api.baseUrl.http, urlSession: self?.api.urlSession, on: nil)
                            .then { _ in
                                resolve(())
                        }.catch(reject)
                        return
                    }
                    
                    guard let spotifyRemote = self?.spotifyRemote else {
                        logger.debug("[playTrack] spotify remote is not initialized")
                        return
                    }
                    
                    if spotifyRemote.isConnected {
                        spotifyRemote.playerAPI?.play(track.uri){ info, error in
                            logger.debug("[playTrack] \(String(describing: info)) - \(String(describing: error))")
                        }
                    } else {
                        logger.debug("[playTrack] spotify not connected")
                        spotifyRemote.authorizeAndPlayURI(track.uri)
                    }
                    
                }
            }.catch() { error in
                logger.error("[playTrack] \(error)")
                self.assertSpotifyAuthorized()
            }
        }
        
        func voteTrack(_ track: QueuedTrack) -> Promise<QueuedTrackVote> {
            let builder = Builder<QueuedTrackVote>()
            return builder.update(.queuedTrackId, track.id as AnyObject)
                .save()
                .always {
                    guard let room = self.activeRoom else {
                        return
                    }
                    self.fetchQueuedTracks(room.musicroom, clean: true)
            }
        }
        
        @discardableResult
        func pausePlayback() -> Promise<Json> {
    //        if spotifyRemote.isConnected {
    //            setAudioSession(false)
    //
    //            return Promise() { (resolve, reject) in
    //
    //                self.spotifyRemote.playerAPI?.pause(){ info, error in
    //                    logger.debug("[pauseTrack] \(String(describing: info)) - \(String(describing: error))")
    //
    //                    guard let error = error else {
    //                        return resolve(info as? Json ?? [:])
    //
    //                    }
    //
    //                    return reject(error)
    //                }
    //            }
    //        }else{
                let path = URLComponents(string: "/api/spotify/me/player/pause")!
                return HttpMethod.put.fetchJson(urlPath: path, payload: [:], baseUrl: api.baseUrl.http, urlSession: api.urlSession)
                    .catch(self.errorHandler())
        }
    
    @discardableResult
    func fetchedImage(url: String) -> Promise<Image?> {
        
        if let cached = imagesByUrl[url] {
            return Promise<Image?>(cached)
        }
        
        guard let urlObj = URL(string: url) else {
            return Promise<Image?>(nil)
        }
        
        return Promise {  (resolve, reject) in
            
            let task: URLSessionDataTask = URLSession.shared.dataTask(with: urlObj) { (data, resp, error) in
                guard let data = data, let img = UIImage(data: data) else {
                    logger.debug("failed to load \(url)")
                    return reject(error!)
                }
                
                let image = Image(uiImage: img)
                let noirImgage: Image
                
                if let noirImg = img.noir {
                    noirImgage = Image(uiImage: noirImg)
                }else{
                    noirImgage = image
                }
                
                DispatchQueue.main.async {
                    let noirUrl = "\(url).noir"
                    let origUrl = "\(url).original"
                    self.imagesByUrl[origUrl] = image
                    self.imagesByUrl[noirUrl] = noirImgage
                    
                    self.imagesByUrl[url] = self.imagesByUrl[self.spotifyWebAuthorized ? origUrl : noirUrl]
                }
                
                resolve(self.spotifyWebAuthorized ? image : noirImgage)
            }
            task.resume()
        }
    }
    
    @discardableResult
    func fetchMusicrooms() -> Promise<[Room]> {
        return Musicroom.all(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession, on: .global(qos: .background))
            .then(on: .main) { [weak self] (rooms) -> Promise<[User]> in
                guard let self = self else { return Promise([]) }
                
                self.musicrooms = rooms
                let creatorIds: [Int] = rooms.compactMap() { $0.createdById }
                return User.findByIds(ids: creatorIds, baseUrl: self.api.baseUrl.rawValue.http,
                                      urlSession: self.api.urlSession)
        }
        .then(){ [weak self] users in
            let items = users.map() { ($0.id, $0) }
            self?.usersById = Dictionary<Int, User>(uniqueKeysWithValues: items)
            //logger.info("[users]")
            guard let self = self else { return Promise([]) }
            
            return Promise(self.musicrooms)
        }
    }
    
    func fetchTracks(_ room: Musicroom) {
        RoomTrack.all(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
            .then() { [weak self] tracks in
                
                guard let self = self else { return }
                
                for track in tracks.filter({ $0.isPlayable }) {
                    var roomTracks = self.tracksByMusicrooms[track.roomId] ?? []
                    
                    guard !roomTracks.contains(track) else {
                        continue
                    }
                    
                    roomTracks.append(track)
                    self.tracksByMusicrooms[track.roomId] = roomTracks.sorted() { $0.createdAt > $1.createdAt}
                }
        }
        .catch() { error in
            logger.error("[fetchTracks] error: \(error)")
        }
    }
    
    func fetchQueuedTracks(_ room: Musicroom, clean: Bool = false) {
        QueuedTrack.all(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
            .then() { [weak self] tracks in
                
                guard let self = self else { return }
                
                if clean {
                    self.queuedTracksByMusicrooms.removeAll()
                }
                
                for track in tracks {
                    var roomTracks = self.queuedTracksByMusicrooms[track.roomId] ?? []
                    roomTracks.insert(track)
                    self.queuedTracksByMusicrooms[track.roomId] = roomTracks
                    
                    guard let votes = track.votes else {
                        self.votesByTrackId[track.id] = []
                        continue
                    }
                    
                    self.updateVotes(votes)
                }
        }
        .catch() { error in
            logger.error("[fetchQueuedTracks] error: \(error)")
        }
    }
    
    private func updateVotes(_ votes: [QueuedTrackVote]){
        for vote in votes {
            var trackVotes = self.votesByTrackId[vote.queuedTrackId] ?? []
            
            guard !trackVotes.contains(vote) else {
                continue
            }
            
            trackVotes.append(vote)
            self.votesByTrackId[vote.queuedTrackId] = trackVotes
        }
    }
    
    func fetchTrackVotes(){
        QueuedTrackVote.all(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
            .then() { [weak self] votes in
                
                guard let self = self else { return }
                
                self.updateVotes(votes)
        }
        .catch() { error in
            logger.error("[fetchTrackVotes] error: \(error)")
        }
    }
    
}
