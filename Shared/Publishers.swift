//
//  LiveObject.swift
//  Joli
//
//  Created by Anthony Chinwo on 23/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import JoliCore
import JoliApi
import Combine
import Starscream
import CommonCrypto
import SwiftUI
import Foundation

extension Data {
    
    public func sha256() -> String{
        return hexStringFromData(input: digest(input: self as NSData))
    }
    
    private func digest(input : NSData) -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }
    
    private  func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)
        
        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }
        
        return hexString
    }
}

public extension String {
    var sha256: String {
        if let stringData = self.data(using: String.Encoding.utf8) {
            return stringData.sha256()
        }
        return ""
    }
}

extension Track {
    
    public static func fetchByUris(_ uris: [String], baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil) async throws -> [Track] {
        
        let props: Track.PropertiesDict = [.uri: uris as AnyObject]
        print("URIS: \(uris)")
        
        guard !uris.isEmpty else {
            return []
        }

        return try await Track.all(where: props, limit: uris.count,
                         baseUrl: baseUrl, urlSession: urlSession)
    }
}

public class Playroom: ObservableObject, Room, Equatable {
    
    public typealias TrackStrip = (playing: Playable?, next: Playable?, runnerup: Playable?)
    
    public static func == (lhs: Playroom, rhs: Playroom) -> Bool {
        return lhs.musicroom == rhs.musicroom
    }
    
    @Published public var playingState: PlayingState? = nil
    
    @Published public var musicroom: Musicroom
    
    @Published public var themeTracks: [Track] = []
    
    @Published public var entitlements: [Entitlement]? = nil {
        didSet {
            Task() { await self.updateMembership() }
        }
    }
    
    @Published public var artists: [Artist] = []
    
    @Published public var name: String
    
    @Published public var membership: [PlayroomMembership] = []
    @Published public var votes: [QueuedTrackVote] = []
    
    @Published public var votesByQueuedTrackId: [Int: Int] = [:]
    
    @Published public var queue: [QueuedTrack] = []
    @Published public var loadingRoomTracks: Bool = false
    @Published public var recommendations: [Playable] = []
    
    @Published public var strip: TrackStrip = (nil, nil, nil)
    
    var userStatus: [String: PlayroomMembership.ActivityStatus] = [:]
    let api: JoliApi
    
    private var cancellationSet: Set<AnyCancellable> = []
    
    public var baseUrl: URL? {
        return api.baseUrlHttp
    }
    
    @discardableResult
    public func fetchSpotifyTopArtists(limit: Int = 6) async throws -> [Artist] {
        
        var path = URLComponents(string: "/api/db/\(Artist.self)")!
        var artists1: [Artist] = []
        
        if let uris = themeArtistIds, !uris.isEmpty {
            
            path.queryItems = [
                URLQueryItem(name: "uris", value: uris)
            ]
            
            logger.debug("[fetchSpotifyRecommendations] getting suggestion: \(path)")
            
            artists1 = (try? await HttpMethod.Fetch.get(url: path, dataType: [Artist].self,
                                         baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)) ?? []
        }
        
        var artists2: [Artist] = []
        
        if !queue.isEmpty {
            let names = queue.prefix(limit).map() { $0.artistName }
            path.queryItems = [
                URLQueryItem(name: "names", value: names.joined(separator: ",")),
            ]
            
            artists2 = (try? await HttpMethod.Fetch.get(url: path, dataType: [Artist].self,
                                         baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)) ?? []
        }
        
        return Array(Set(artists1 + artists2))
    }
    
    @discardableResult
    public func fetchSpotifyRecommendations(limit: Int = 6) async throws -> Spotify.Recommendation {
        var path = URLComponents(string: "/api/spotify/recommendations")!
        let trackIds = queue.prefix(5).map({ $0.uri.replacingOccurrences(of: "spotify:track:", with: "") })
        let artistIds = themeArtistIds?.split(separator: ",").map({ String($0).replacingOccurrences(of: "spotify:artist:", with: "") }) ?? []
        
        path.queryItems = [
            URLQueryItem(name: "limit", value: limit.description),//
            URLQueryItem(name: "min_energy", value: "0.4"),
        ]
        
        var alloc = 5
        if !genres.isEmpty {
            let gSeeds = trackIds.isEmpty && artistIds.isEmpty ? alloc : 3
            path.queryItems?.append(URLQueryItem(name: "seed_genres", value: genres.prefix(gSeeds).joined(separator: ",")))
            alloc = alloc - gSeeds
        }
        
        if !trackIds.isEmpty {
            let tSeeds = artistIds.isEmpty ? alloc : 1
            path.queryItems?.append(URLQueryItem(name: "seed_tracks", value: trackIds.prefix(tSeeds).joined(separator: ",")))
            alloc = alloc - tSeeds
        } else {
            let uri = self.themeTrackUri.replacingOccurrences(of: "spotify:track:", with: "")
            path.queryItems?.append(URLQueryItem(name: "seed_tracks", value: uri))
            alloc = alloc - 1
        }
        
        if !artistIds.isEmpty {
            let q = URLQueryItem(name: "seed_artists", value: artistIds.prefix(alloc).joined(separator: ","))
            path.queryItems?.append(q)
        }
        
        logger.debug("[fetchSpotifyRecommendations] getting suggestion: \(path)")
        
        return try await HttpMethod.Fetch.get(url: path, dataType: Spotify.Recommendation.self,
                                                  baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
    }
    
    public func fetchThemeTracks() async throws -> [Track] {
        let themeTrackUris: [String] = [self.themeTrackUri2, self.themeTrackUri].compactMap({ $0 })
        
        return try await Track.fetchByUris(themeTrackUris, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
    }
    
    @discardableResult
    @MainActor
    public func updateQueuedTracks(additions: [QueuedTrack] = []) async throws -> [QueuedTrack] {
        self.loadingRoomTracks = true
        
        defer {
            self.loadingRoomTracks = false
        }
        
        let tracks = await self.fetchQueuedTracks()
        self.queue = tracks
        
        var tracksByMusicrooms: [Int: [QueuedTrack]] = [:]
        var allVotes: [QueuedTrackVote] = []
        var votesById: [Int: Int] = [:]
        
        let themeTrackUris = [self.themeTrackUri2, self.themeTrackUri].compactMap({ $0 })
        
        for track in tracks.filter({ $0.isPlayable }) {
            var roomTracks = tracksByMusicrooms[track.roomId] ?? []
            
            guard !roomTracks.map({ $0.uri }).contains(track.uri) else {
                continue
            }
            
            roomTracks.append(track)
            tracksByMusicrooms[track.roomId] = roomTracks
            votesById[track.id] = track.voteCount ?? 0
            
            if let trackObj = track.track,
               themeTrackUris.contains(track.uri),
               !self.themeTracks.map({ $0.uri }).contains(track.uri) {
                
                self.themeTracks.append(trackObj)
            }
            
            guard let votes = track.votes, track.roomId == self.musicroom.id else {
                continue
            }
            
            allVotes.append(contentsOf: votes)
        }
        
        self.votesByQueuedTrackId = votesById
        self.votes = allVotes
        
        self.strip = (
            playing: tracks.first,
            next: tracks.count > 1 ? tracks[1] : nil,
            runnerup: tracks.count > 2 ? tracks[2] : nil
        )
        
        return tracks
    }
    
    public func fetchQueuedTracks(limit: Int? = nil, includePlayed: Bool = false) async -> [QueuedTrack] {
        var uri = "/api/musicrooms/\(musicroom.id)/queued?includePlayed=\(includePlayed)"
        
        if let limit = limit {
            uri = "\(uri)&limit=\(limit)"
        }
        
        do {
            return try await HttpMethod.Fetch.get(url: uri, dataType: [QueuedTrack].self, baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
        } catch {
            logger.error("[fetchTracks] error fetching tracks for \(self.musicroom.name): \(String(describing: error))")
            return []
        }
    }
    
    @MainActor
    public func updateMembership() async {
        
        guard let userIds = entitlements?.compactMap({ $0.userId }), !userIds.isEmpty else { return }
        
        do {
            let users = try await User.findByIds(ids: userIds, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            print("[Playroom] fetched \(users.count) users for \(String(describing: self.entitlements?.count)) entitlements")
            let userMap = Dictionary(uniqueKeysWithValues: users.map() { ($0.id, $0) })
            
            self.membership = (self.entitlements ?? []).compactMap() { entitlement in
                
                guard let user = userMap[entitlement.userId] else {
                    return nil
                }
                
                return PlayroomMembership(inviteStatus: entitlement.acceptedAt == nil ? .pending : .accepted,
                                          activityStatus: self.userStatus[user.email] ?? .offline,
                                          playroom: self.musicroom, user: user)
            }
        } catch {
            self.membership = self.membership.map() { mem in
                return PlayroomMembership(inviteStatus: mem.inviteStatus, activityStatus: .offline, playroom: self.musicroom, user: mem.user)
            }
        }
    }
    
    let queueUpdateRequest = PassthroughSubject<String, Never>()
    
    public init(musicroom: Musicroom, socket: Socket, api: JoliApi){
        self.musicroom = musicroom
        self.entitlements = musicroom.entitlements
        self.name = musicroom.name
        self.api = api
        
        queueUpdateRequest
            .debounce(for: 2.16, scheduler: DispatchQueue.global(qos: .background))
            .sink() { _ in
                Task() { try? await self.updateQueuedTracks() }
            }
            .store(in: &cancellationSet)
        
        
        socket.$isConnected
            .sink() { value in
                guard !value else {
                    return
                }
                
                self.userStatus.removeAll()
                Task() { await self.updateMembership() }
            }
            .store(in: &cancellationSet)
        
        socket
            .deserialize(Entitlement.self)
            .autoconnect()
            .sink() { completion in
                //self.entitlementCancel?.cancel()
            } receiveValue: { value in
                //print("[Playroom#Entitlement] \(value)")
                guard var entitlements = self.entitlements, !entitlements.contains(value) else {
                    return
                }
                
                entitlements.append(value)
                self.entitlements = entitlements
            }
            .store(in: &cancellationSet)
        
        socket
            .deserialize(QueuedTrack.self)
            .autoconnect()
            .sink() { completion in
                //self.queuedTrackCancel?.cancel()
            } receiveValue: { value in
                
                guard value.roomId == musicroom.id else { return }
                
                self.queueUpdateRequest.send("New queued track added")
            }
            .store(in: &cancellationSet)
        
        socket
            .deserialize(QueuedTrackVote.self)
            .autoconnect()
            .sink() { completion in
                //self.queuedTrackCancel?.cancel()
            } receiveValue: { value in
                
                guard self.queue.map({ $0.id }).contains(value.queuedTrackId) else { return }
                
                self.votes.append(value)
                
                self.queueUpdateRequest.send("New vote")
            }
            .store(in: &cancellationSet)
        
        socket
            .deserialize(PlayState.self)
            .autoconnect()
            .sink() { completion in
                //self.playStateCancel?.cancel()
            } receiveValue: { value in
                //print("[Playroom#PlayState] \(value)")
                guard self.membership.contains(where: { $0.emailAddress.email == value.email } ) else {
                    return
                }
                
                let status: PlayroomMembership.ActivityStatus = value.status == "online" ? .online : .offline
                self.userStatus[value.email] = status
                
                self.membership = self.membership.map() { membership in
                    
                    guard membership.emailAddress.email == value.email else {
                        return membership
                    }
                    
                    return PlayroomMembership(inviteStatus: membership.inviteStatus,
                                              activityStatus: status,
                                              playroom: membership.playroom, user: membership.user)
                }
            }
            .store(in: &cancellationSet)
        
        Task() { await updateMembership() }
    }
    
    deinit {
        for sub in self.cancellationSet {
            sub.cancel()
        }
        self.cancellationSet.removeAll()
    }
    
}

public enum SocketMessage {
    case text(type: String?, body: Data, topic: String, subject: String?)
}

public enum SocketError: Error {
    case error(Error?)
    case disconnected(String, UInt16)
}

public class Socket: ObservableObject, ConnectablePublisher, Identifiable {
    
    @Published public var isConnected: Bool = false {
        didSet {
            connecting = false
            self.onConnect?(self, isConnected)
        }
    }
    
    private var connecting = false
    
    var soc: WebSocket
    
    public var request: URLRequest {
        didSet {
            self.soc.request = request
        }
    }
    
    let allowSelfSigned: Bool
    
    public var onConnect: ((Socket, Bool) -> Void)?
    
    private var rawMessage = PassthroughSubject<SocketMessage, SocketError>()
    
    private var completion: Subscribers.Completion<SocketError>? = nil
    
    public init(request: URLRequest, allowSelfSigned: Bool = true, onConnect: ((Socket, Bool) -> Void)? = nil) {
        self.onConnect = onConnect
        self.allowSelfSigned = allowSelfSigned
        self.request = request
        
        let pinner = FoundationSecurity(allowSelfSigned: allowSelfSigned) // don't validate SSL certificates
        self.soc = WebSocket(request: request, certPinner: pinner)
        self.soc.delegate = self
    }
    
    public convenience init(url: URL, timeoutInterval: TimeInterval = 5, allowSelfSigned: Bool = true, onConnect: ((Socket, Bool) -> Void)? = nil) {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        self.init(request: request, allowSelfSigned: allowSelfSigned, onConnect: onConnect)
    }
    
    public func write(string: String, completion: (() -> ())?) {
        self.soc.write(string: string, completion: completion)
    }
    
    public func write(topic: String, body: [String: Any], completion: @escaping (Error?) -> ()) {
        let payload: [String: Any] = [
            "topic": topic,
            "data": body,
            "headers": self.soc.request.allHTTPHeaderFields ?? [:]
        ]
        
        do {
            let res = try JSONSerialization.data(withJSONObject: payload, options: [])
            
            self.soc.write(data: res) {
                completion(nil)
            }
        } catch {
            completion(error)
        }
    }
    
    var disconnectRequestCount = 0
    
    @discardableResult
    public func connect() -> Cancellable {
        logger.debug("[Socket] Connect called")
        
        let cancellable = AnyCancellable() {
            self.disconnectRequestCount += 1
            Swift.print("[Socket] disconnect: \(self.disconnectRequestCount)")
            //self.soc.disconnect()
        }
        
        guard !isConnected && !connecting else { return cancellable }
        
        logger.debug("[Socket] setting up connection")
        
        soc.connect()
        connecting = true
        
        return cancellable
    }
    
}

public extension Socket {
    
    
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        //Swift.print("websocket event: \(event)")
        
        switch event {
            case .connected(let headers):
                isConnected = true
                Swift.print("websocket is connected: \(headers)")
            case .disconnected(let reason, let code):
                isConnected = false
                Swift.print("websocket is disconnected: \(reason) with code: \(code)")
                self.completion = Subscribers.Completion.failure(SocketError.disconnected(reason, code))
                
            case .text(let string):
                //Swift.print("Received text: \(string)")
                
                guard let data = string.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject],
                      let topic = json["topic"] as? String,
                      let bodyJson = json["data"] as? [String: AnyObject],
                      let bodyData = try? JSONSerialization.data(withJSONObject: bodyJson, options: [])
                else {
                    break
                }
                
                
                
                var subject: String? = nil
                
                if let url = URLComponents(string: topic), url.path == "/subscribe" {
                    subject = url.queryItems?.first(where: { i in i.name == "subject"})?.value
                }
                
                
                //Swift.print("Received topic: \(topic), subject: \(subject), displayName: \(bodyJson["displayName"]), status: \(bodyJson["status"])")
                
                self.rawMessage.send(.text(type: json["type"] as? String, body: bodyData, topic: topic, subject: subject))
            case .binary(let data):
                Swift.print("Received data: \(data.count)")
            case .ping(_):
                break
            case .pong(_):
                break
            case .viabilityChanged(_):
                Swift.print("Received data: viabilityChanged")
            case .reconnectSuggested(_):
                Swift.print("Received data: reconnectSuggested")
                
                DispatchQueue.global().async {
                    self.connect()
                }
            case .cancelled:
                isConnected = false
                self.completion = .finished
                Swift.print("websocket is cancelled")
                
            case .error(let error):
                isConnected = false
                Swift.print("websocket is error: \(String(describing: error))")
                self.completion =  Subscribers.Completion.failure(SocketError.error(error))
            case .peerClosed:
                isConnected = false
                Swift.print("websocket peerClosed!")
        }
    }
    
}

extension Socket: Starscream.WebSocketDelegate {
    
}


extension Socket: Publisher {
    
    public typealias Output = SocketMessage
    public typealias Failure = SocketError
    
    public func receive<S>(subscriber: S) where S:Subscriber, Failure == S.Failure, Output == S.Input {
        Swift.print("[Socket] subscribe: \(subscriber.combineIdentifier)")
        self.rawMessage
            .receive(subscriber: subscriber)
    }
    
    
}


public extension JoliApi {
    
    func playTrack(_ track: Playable, device: Spotify.Device? = nil, positionMs: Int? = nil, on: DispatchQueue? = nil) -> AnyPublisher<PlayState?, Error> {
        
        print("[play] playing track: \(track.title)")
        
        return Future<PlayState?, Error>() { promise in
            Task() {
                do {
                    let res = try await track.play(deviceId: device?.id, positionMs: positionMs, baseUrl: self.baseUrl.http, urlSession: self.urlSession)
                    print("[playTrack] \(res)")
                    promise(.success(nil))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
}



public extension Socket {
    
    func deserialize<M: Persisted>(_ modelType: M.Type) -> DbPublisher<M, Socket> {
        return DbPublisher(socket: self)
    }
    
    func publish<M, Id: Hashable>(_ modelType: M.Type, interval: TimeInterval = 0.3, path: Publishers.Smooth<M.Publisher, Id>.ValueKeyPath? = nil, resolver: Publishers.Smooth<M.Publisher, Id>.StateGetter? = nil) -> M.Publisher where M: Persisted {
        
        guard let resolve = resolver, let kp = path else {
            return self.deserialize(modelType.self)
                .multicast() {
                    return PassthroughSubject<M, SocketError>()
                }
                .autoconnect()
                .eraseToAnyPublisher()
        }
        
        return self.deserialize(modelType.self)
            .smooth(kp, resolver: resolve)
            .multicast() {
                return PassthroughSubject<M, SocketError>()
            }
            .autoconnect()
            .eraseToAnyPublisher()
    }
    
}

public extension Persisted {
    typealias Publisher = AnyPublisher<Self, SocketError>
}

public extension Publisher {
    
    func smooth<Id: Hashable>(_ path: Publishers.Smooth<Self, Id>.ValueKeyPath, unit: Int = 1000, duration: TimeInterval? = nil, interval: TimeInterval = 0.3, resolver: @escaping Publishers.Smooth<Self, Id>.StateGetter) -> Publishers.Smooth<Self, Id> {
        return Publishers.Smooth(self, path: path, unit: unit,
                                 duration: duration, interval: interval, resolver: resolver)
    }
    
    func filter<ValueType: Equatable>(_ path: KeyPath<Output, ValueType>, value: ValueType) -> AnyPublisher<Output, Failure> {
        return self.filter() { $0[keyPath: path] == value }
            .eraseToAnyPublisher()
    }
    
}

public extension Publishers {
    
    class Smooth<C: Publisher, Id: Hashable>: Publisher, Identifiable, CustomDebugStringConvertible {
        
        public typealias StateGetter = (C.Output, Date) -> State
        
        public typealias Value = Int?
        
        public typealias IdentityKeyPath = WritableKeyPath<C.Output, Id>
        public typealias ValueKeyPath = WritableKeyPath<C.Output, Int?>
        public typealias CurrentValue = (value: C.Output, ts: Date)
        
        public typealias State = (id: Id?, value: Value, duration: TimeInterval?, idleTimeout: TimeInterval)
        
        public var debugDescription: String {
            return "Smooth<\(C.self), \(Id.self)>(\(id))"
        }
        
        private var timer: Foundation.Timer.TimerPublisher
        public var smoothingOn: Bool = false
        var path: ValueKeyPath
        let duration: TimeInterval?
        let interval: TimeInterval
        
        let resolve: StateGetter
        
        let unit: Int
        
        private var timerCancel: AnyCancellable? = nil
        private var timerConnectCancel: Cancellable? = nil
        private var passthroughCancel: AnyCancellable? = nil
        private var currentValue = CurrentValueSubject<[Id: CurrentValue], C.Failure>([:])
        
        var passthrough = PassthroughSubject<C.Output, C.Failure>()
        
        var connected: Bool = false
        
        public init(_ target: C, path: ValueKeyPath, unit: Int = 1000, duration: TimeInterval? = nil, interval: TimeInterval = 1, tolerance: TimeInterval? = nil, runLoop: RunLoop = .current, mode: RunLoop.Mode = .common, options:  RunLoop.SchedulerOptions? = nil, resolver: @escaping StateGetter){
            self.duration = duration
            timer = Foundation.Timer.TimerPublisher(interval: interval,
                                         tolerance: tolerance,
                                         runLoop: runLoop,
                                         mode: mode,
                                         options: options)
            self.target = target
            self.interval = interval
            self.unit = unit
            self.resolve = resolver
            self.path = path
            
            self.timerConnectCancel = timer.connect()
            
            setupPassthrough()
        }
        
        public func connect() {
            
            guard !connected else {
                return
            }
            
            Swift.print("[\(debugDescription)] connecting timer...")
            self.setupTimer()
            self.connected = true
        }
        
        public func disconnect() {
        
            Swift.print("[\(debugDescription)] cancelled timer")
            self.timerCancel?.cancel()
            self.timerCancel = nil
            self.connected = false
        }
        
        deinit {
            Swift.print("[Smooth] deinit")
            timerCancel?.cancel()
            self.passthroughCancel?.cancel()
        }
        
        private func setupTimer() {
            let start = Date()
            
            self.timerCancel = timer.sink() { timestamp in
                
                var valuesMap = self.currentValue.value
                
                
//                if Int32(Date().timeIntervalSince(start)) % 10 == 0 {
//                    Swift.print("[\(self.debugDescription)] \(valuesMap))")
//                }
                
                guard !valuesMap.isEmpty else {
                    self.disconnect()
                    return
                }
                
                var evictSet: Set<Id> = []
                
                for (id, item) in self.currentValue.value {
                    
                    let state = self.resolve(item.value, timestamp)
                    
                    guard let duration = state.duration,
                          Date().timeIntervalSince(start) < duration, state.id != nil else {
                        evictSet.insert(id)
                        continue
                    }
                    
                    guard Date().timeIntervalSince(item.ts) < state.idleTimeout else {
                        Swift.print("[Timer] timedout - \(id)")
                        evictSet.insert(id)
                        continue
                    }
                    
                    guard let keyValue = state.value else { continue }
                    
                    var lastValue = item.value
                    
                    let interval = abs(self.interval)
                    var addition: Int = 0
                    
                    if interval > 0 && interval < 1 {
                        addition = Int(Double(self.unit) * interval)
                    } else if interval >= 1 {
                        addition = Int(interval) * self.unit
                    }
                    
                    let newQuant = keyValue + addition
                    lastValue[keyPath: self.path] = newQuant
                    
//                    if Int32(Date().timeIntervalSince(start)) % 10 == 0 {
//                        Swift.print("[\(self.debugDescription)] \(keyValue) -> \(newQuant) (\(interval) * \(self.unit)) - \(state)")
//                    }
                    
                    valuesMap[id] = (lastValue, item.ts)
                    
                    self.passthrough.send(lastValue)
                }
                
                if !evictSet.isEmpty {
                    Swift.print("[Timer] removing ids: \(evictSet)")
                    
                    evictSet.forEach() { valuesMap.removeValue(forKey: $0) }
                }
                
                self.currentValue.send(valuesMap)
            }
            
        }
        
        private func setupPassthrough() {
            Swift.print("[Passthrough] setting up...")
            
            //self.passthroughCancel?.cancel()
            
            self.passthroughCancel = target.sink(){ completion in
                Swift.print("[target] cancelled - \(completion)")
                //self.timerCancel?.cancel()
                self.disconnect()
                self.passthrough.send(completion: completion)
                
            } receiveValue: { output in
                //Swift.print("[Passthrough] got - \(output)")
                
                self.passthrough.send(output)
                
                var valuesMap = self.currentValue.value
                
                defer {
                    if !(self.connected || valuesMap.isEmpty) {
                        Swift.print("[Passthrough] auto connecting timer")
                        self.connect()
                    }
                }
                
                let state = self.resolve(output, Date())
                
                guard let id = state.id else {
                    return
                }
                
                if state.duration == nil {
                    valuesMap.removeValue(forKey: id)
                }else {
                    valuesMap[id] = (output, Date())
                }
                
                self.currentValue.send(valuesMap)
            }
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, C.Failure == S.Failure, C.Output == S.Input {
            return passthrough
                .receive(subscriber: subscriber)
        }
        
        public typealias Output = C.Output
        public typealias Failure = C.Failure
        
        private var target: C {
            didSet {
                setupPassthrough()
            }
        }
        
    }
    
}

public struct DbPublisher<M: Persisted, S: ConnectablePublisher>: ConnectablePublisher where S.Failure == SocketError, S.Output == SocketMessage {
    
    public typealias Output = M
    public typealias Failure = S.Failure
    
    private let socket: S
    
    public init(socket: S) {
        self.socket = socket
    }
    
    public func connect() -> Cancellable {
        Swift.print("[DbPublisher] connect")
        return socket.connect()
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        return socket.tryCompactMap() { message throws -> M? in
            
            guard case let SocketMessage.text(typeNameOpt, jsonData, _, _) = message, let typeName = typeNameOpt, typeName == M.className() else {
                return nil
            }
            
            let classes: [Codable.Type] = [
                PlayState.self,
                AuthToken.self,
                Musicroom.self,
                QueuedTrackVote.self,
                QueuedTrack.self,
                Entitlement.self,
            ]
            
            for cls in classes {
                
                guard "\(cls)" == M.className() else {
                    continue
                }
                
                let obj = try Musicroom.jsonDecoder().decode(M.self, from: jsonData)
                return obj
            }
            
            return nil
        }
        .mapError() { error -> Failure in
            
            guard let failure = error as? Failure else {
                return SocketError.error(error)
            }
            
            return failure
        }
        .subscribe(subscriber)
    }
    
}

public final class AutoResetSubject<Output, Failure, S>: Subject where Failure : Error, S : Scheduler {
    
    private let passthroughDelayed = PassthroughSubject<Output, Never>()
    private let passthrough = PassthroughSubject<Output, Failure>()
    private var delayedCancel: AnyCancellable
    
    public let resetValue: Output
    public let delay: S.SchedulerTimeType.Stride
    
    public init(_ resetValue: Output, delay: S.SchedulerTimeType.Stride, scheduler: S) {
        self.resetValue = resetValue
        self.delay = delay
        
        let passthrough = self.passthrough
        self.delayedCancel = passthroughDelayed
            .delay(for: delay, scheduler: scheduler)
            .receive(on: DispatchQueue.main)
            .sink() { value in
                passthrough.send(value)
            }
    }
    
    public func send(_ value: Output) {
        passthrough.send(value)
        passthroughDelayed.send(resetValue)
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        passthrough.send(completion: completion)
    }
    
    public func send(subscription: Subscription) {
        passthrough.send(subscription: subscription)
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        passthrough.receive(subscriber: subscriber)
    }
    
}

@propertyWrapper
public final class Debounced<T: Hashable> {
    
    public let delay: Double
    
    private let publisher: CurrentValueSubject<T, Never>
    private var _value: T
    public var latestValue = PassthroughSubject<T, Never>()
    
    public var wrappedValue: T {
        get {
            return _value
        }
        set(newValue) {
            print("Timer called on main: \(Thread.isMainThread) - \(newValue)")
            latestValue.send(newValue)
        }
    }
    
    public var projectedValue: AnyPublisher<T, Never> {
        return publisher.eraseToAnyPublisher()
    }
    
    private var cancel: AnyCancellable?
    
    deinit {
        self.cancel?.cancel()
        self.cancel = nil
    }
    
    public init(wrappedValue: T, delay debounceDelay: Double) {
        
        self.delay = debounceDelay
        self._value = wrappedValue
        self.publisher = CurrentValueSubject<T, Never>(wrappedValue)
        
        self.cancel = latestValue
            .removeDuplicates()
            .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(){ [weak self] value in
                print("[Debounced] sending value: \(value) - \(String(describing: self))")
                self?._value = value
                self?.publisher.send(value)
            }
        
    }
}
