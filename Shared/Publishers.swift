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
            guard isConnected else {
                return
            }
            
            self.onConnect?(self)
        }
    }
    
    let soc: WebSocket
    var request: URLRequest
    
    public let onConnect: ((Socket) -> Void)?
    
    var rawMessage = PassthroughSubject<SocketMessage, SocketError>()
    
    public init?(url: URL, timeoutInterval: TimeInterval = 5, onConnect: ((Socket) -> Void)? = nil) {
        self.onConnect = onConnect
        
        var ws = URLComponents(url: url, resolvingAgainstBaseURL: false)
        ws?.scheme = "wss"
        
        guard let wsUrl = ws?.url else {
            return nil
        }
        
        request = URLRequest(url: wsUrl)
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
    
    public func connect() -> Cancellable {
        logger.debug("Connect called")
        
        let cancellable = AnyCancellable() {
            Swift.print("[Socket] disconnect")
            self.soc.disconnect()
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
                self.rawMessage.send(completion: Subscribers.Completion.failure(SocketError.disconnected(reason, code)))
                
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
            case .cancelled:
                isConnected = false
                self.rawMessage.send(completion: .finished)
                
            case .error(let error):
                isConnected = false
                self.rawMessage.send(completion: Subscribers.Completion.failure(SocketError.error(error)))
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



extension Socket {
    
    func deserialize<M: Persisted>(_ modelType: M.Type) -> DbPublisher<M, Socket> {
        return DbPublisher(socket: self)
    }
    
}

public extension Persisted {
    typealias Publisher = AnyPublisher<Self, SocketError>
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
