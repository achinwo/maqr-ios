//
//  LiveObject.swift
//  Joli
//
//  Created by Anthony Chinwo on 23/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import MaqrApi
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
                AuthToken.self,
                Entitlement.self,
            ]
            
            for cls in classes {
                
                guard "\(cls)" == M.className() else {
                    continue
                }
                
                let obj = try JSONCoding.decoder().decode(M.self, from: jsonData)
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
