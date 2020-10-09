//
//  LiveObject.swift
//  Joli
//
//  Created by Anthony Chinwo on 23/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import JoliApi
import CancellationToken
import Combine
import Starscream

public enum SocketMessage {
    case text(type: String?, body: Data)
}

public enum SocketError: Error {
    case error(Error?)
    case disconnected(String, UInt16)
}

public class Socket: ObservableObject, ConnectablePublisher, Identifiable {
    
    @Published var isConnected: Bool = false {
        didSet {
            self.onConnect?(self, isConnected)
        }
    }
    
    let soc: WebSocket
    var request: URLRequest
    
    public var onConnect: ((Socket, Bool) -> Void)?
    
    private var rawMessage = PassthroughSubject<SocketMessage, SocketError>()
    
    private var completion: Subscribers.Completion<SocketError>? = nil {
        didSet {
            
            guard let completion = completion else {
                return
            }
            
            rawMessage.send(completion: completion)
            self.rawMessage = PassthroughSubject<SocketMessage, SocketError>()
        }
    }
    
    public init(url: URL, timeoutInterval: TimeInterval = 5, onConnect: ((Socket, Bool) -> Void)? = nil) {
        self.onConnect = onConnect
        request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        
        let pinner = FoundationSecurity(allowSelfSigned: true) // don't validate SSL certificates
        self.soc = WebSocket(request: request, certPinner: pinner)
        self.soc.delegate = self
    }
    
    public func write(string: String, completion: (() -> ())?) {
        self.soc.write(string: string, completion: completion)
    }
    
    public func write(topic: String, body: [String: Any], completion: @escaping (Error?) -> ()) {
        let payload: [String: Any] = [
            "topic": topic,
            "data": body
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
        logger.debug("Connect called")
        
        let cancellable = AnyCancellable() {
            self.disconnectRequestCount += 1
            Swift.print("[Socket] disconnect: \(self.disconnectRequestCount)")
            //self.soc.disconnect()
        }
        
        guard !isConnected else { return cancellable }
        
        soc.connect()
        
        return cancellable
    }
    
}

extension Socket: WebSocketDelegate {
    
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
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
                      let bodyJson = json["data"] as? [String: AnyObject],
                      let bodyData = try? JSONSerialization.data(withJSONObject: bodyJson, options: [])
                else {
                    break
                }
                
                self.rawMessage.send(.text(type: json["type"] as? String, body: bodyData))
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
                
            case .error(let error):
                isConnected = false
                self.completion =  Subscribers.Completion.failure(SocketError.error(error))
        }
    }
    
}


extension Socket: Publisher {
    
    public typealias Output = SocketMessage
    public typealias Failure = SocketError
    
    public func receive<S>(subscriber: S) where S:Subscriber, Failure == S.Failure, Output == S.Input {
        Swift.print("[Socket] subscribe: \(subscriber)")
        self.rawMessage
            .receive(subscriber: subscriber)
    }
    
    
}

public extension Track {
    
    func toPlayState(_ progressMs: Int? = 0) -> PlayStateRecord {
        return PlayState(accessToken: .empty, country: .empty, createdAt: self.createdAt,
                         createdById: createdById, deletedAt: deletedAt, deletedById: self.deletedById,
                         deviceUid: nil, displayName: .empty, email: .empty,
                         expiresIn: 0, id: 0, playingState: .playing,
                         playingStateChangedAt: nil, playlistUri: nil,
                         product: .empty, progressMs: progressMs, refreshToken: .empty,
                         roomId: nil, scope: .empty, tokenType: .empty, trackUri: uri,
                         updatedAt: updatedAt, updatedById: updatedById, userName: .empty).builder()
    }
    
}


public extension JoliApi {
    
    func playTrack(_ track: Playable, device: Spotify.Device? = nil, positionMs: Int? = nil, on: DispatchQueue? = nil) -> AnyPublisher<PlayState?, Error> {
        
        print("[play] playing track: \(track.title)")
        
        return Future<PlayState?, Error>() { promise in
            track.play(deviceId: device?.id, positionMs: positionMs, baseUrl: self.baseUrl.http, urlSession: self.urlSession, on: on)
                .then() { res in
                    print("[playTrack] \(res)")
                    promise(.success(nil))
                }
                .catch() { error in
                    promise(.failure(error))
                }
        }
        .eraseToAnyPublisher()
    }
    
}



public extension Socket {
    
    func deserialize<M: Persisted>(_ modelType: M.Type) -> DbPublisher<M, Socket> {
        return DbPublisher(socket: self)
    }
    
    func publish<M>(_ modelType: M.Type, smoothKeyPath: Publishers.Smooth<M.Publisher>.ValueKeyPath? = nil, interval: TimeInterval = 0.3) -> M.Publisher where M: Persisted {
        
        guard let kp = smoothKeyPath else {
            return self.deserialize(modelType.self)
                .multicast() {
                    return PassthroughSubject<M, SocketError>()
                }
                .autoconnect()
                .eraseToAnyPublisher()
        }
        
        return self.deserialize(modelType.self)
            .smooth(kp, interval: interval)
            .autoconnect()
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
    
    func smooth(_ path: Publishers.Smooth<Self>.ValueKeyPath, unit: Int = 1000, duration: TimeInterval? = nil, interval: TimeInterval = 0.3) -> Publishers.Smooth<Self> {
        return Publishers.Smooth(self, path: path, unit: unit, duration: duration, interval: interval)
    }
    
}

public extension Publishers {
    
    class Smooth<C: Publisher>: ConnectablePublisher {
        
        public typealias ValueKeyPath = WritableKeyPath<C.Output, Int?>
        public typealias CurrentValue = (value: C.Output, ts: Date)
        
        private var timer: Timer.TimerPublisher
        public var smoothingOn: Bool = false
        var path: ValueKeyPath
        let duration: TimeInterval?
        let interval: TimeInterval
        
        let unit: Int
        
        private var timerCancel: AnyCancellable? = nil
        private var passthroughCancel: AnyCancellable? = nil
        private var currentValue = CurrentValueSubject<CurrentValue?, C.Failure>(nil)
        
        var passthrough = PassthroughSubject<C.Output, C.Failure>()
        
        public init(_ target: C, path: ValueKeyPath, unit: Int = 1000, duration: TimeInterval? = nil, interval: TimeInterval = 1, tolerance: TimeInterval? = nil, runLoop: RunLoop = .current, mode: RunLoop.Mode = .default, options:  RunLoop.SchedulerOptions? = nil){
            self.duration = duration
            timer = Timer.TimerPublisher(interval: interval,
                                         tolerance: tolerance,
                                         runLoop: runLoop,
                                         mode: mode,
                                         options: options)
            self.target = target
            self.path = path
            self.interval = interval
            self.unit = unit
            
            setupPassthrough()
        }
        
        public func connect() -> Cancellable {
            timer.connect()
        }
        
        private func setupPassthrough() {
            Swift.print("[Passthrough] setting up...")
            
            self.passthroughCancel?.cancel()
            
            let start = Date()
            
            self.timerCancel = timer.sink(){ value in
                
                let proceed = self.duration == nil ? true : Date().timeIntervalSince(start) < self.duration!
                
                guard proceed else {
                    Swift.print("[Passthrough] ticker cancelled")
                    self.timerCancel?.cancel()
                    return
                }
                
                guard var (lastValue, _) = self.currentValue.value, let keyValue = lastValue[keyPath: self.path] else {
                    return
                }
                
                let interval = abs(self.interval)
                var addition: Int = 0
                
                if interval > 0 && interval < 1 {
                    addition = Int(Double(self.unit) * interval)
                } else if interval >= 1 {
                    addition = Int(interval) * self.unit
                }
                
                let newQuant = keyValue + addition
                lastValue[keyPath: self.path] = newQuant
                
                //Swift.print("[Timer] \(keyValue) -> \(newQuant) (\(interval) * \(self.unit))")
                
                self.currentValue.send((lastValue, Date()))
                self.passthrough.send(lastValue)
            }
            
            self.passthroughCancel = target.sink(){ completion in
                Swift.print("[Passthrough] cancelled - \(completion)")
                self.timerCancel?.cancel()
                self.passthrough.send(completion: completion)
            } receiveValue: { output in
                Swift.print("[Passthrough] got - \(output)")
                
                guard let outWithTs = self.currentValue.value, output[keyPath: self.path] != nil else {
                    self.currentValue.send((value: output, ts: Date()))
                    self.passthrough.send(output)
                    return
                }
                
                let out = self.applySmooth((output, Date()), outWithTs)
                
                self.currentValue.send(out)
                self.passthrough.send(out.value)
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
        
        func applySmooth(_ newValue: CurrentValue, _ oldValue: CurrentValue) -> CurrentValue {
            
            let vNew = newValue.value[keyPath: path]
            //let vOld = oldValue.value[keyPath: path]
            
            var resObj = newValue.value
            resObj[keyPath: path] = vNew
            
            let result = (resObj, newValue.ts)
            
            return result
        }
        
    }
    
}

public struct DbPublisher<M: Persisted, S: ConnectablePublisher>: ConnectablePublisher where S.Failure == SocketError, S.Output == SocketMessage {
    
    public typealias Output = M
    public typealias Failure = S.Failure
    
    private let socket: S
    
    //
    
    public init(socket: S) {
        self.socket = socket
    }
    
    public func connect() -> Cancellable {
        Swift.print("[DbPublisher] connect")
        return socket.connect()
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        return socket.tryCompactMap() { message throws -> M? in
            
            guard case let SocketMessage.text(typeNameOpt, jsonData) = message, let typeName = typeNameOpt else {
                return nil
            }
            
            switch typeName {
                case "\(PlayState.self)":
                    let obj = try M.jsonDecoder().decode(M.self, from: jsonData)
                    return obj
                default:
                    return nil
            }
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
