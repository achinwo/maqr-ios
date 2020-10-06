//
//  JoliClipTests.swift
//  JoliClipTests
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import XCTest
@testable import JoliClip
@testable import JoliPlayground
@testable import JoliCore
import CancellationToken
import Combine
import Starscream
import JoliApi
//Publishers

public enum SocketMessage {
    case track(Track)
    case empty
    case text(String)
}

public enum SocketError: Error {
    
}

public class Socket: ObservableObject, ConnectablePublisher {
    
    let socket: WebSocket
    var request: URLRequest
    
    @Published var isConnected: Bool = false
    @Published var rawMessage: SocketMessage = .empty
    
    public init(url: URL){
        request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        let pinner = FoundationSecurity(allowSelfSigned: true) // don't validate SSL certificates
        self.socket = WebSocket(request: request, certPinner: pinner)
        self.socket.delegate = self
        
        
        Swift.print("££££££££Creating socket called")
        // 1) what you're about to do 2) Is this your first time? 3)
    }
    
    public func connect() -> Cancellable {
        logger.debug("Connect called")
        socket.connect()
        
        return AnyCancellable() {
            self.socket.disconnect()
        }
    }
    
}

extension Socket: WebSocketDelegate {
    
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        Swift.print("websocket event: \(event)")
        switch event {
        case .connected(let headers):
            isConnected = true
            Swift.print("websocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            isConnected = false
            Swift.print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            Swift.print("Received text: \(string)")
            self.rawMessage = .text(string)
        case .binary(let data):
            Swift.print("Received data: \(data.count)")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            Swift.print("Received data: viabilityChanged")
            break
        case .reconnectSuggested(_):
            Swift.print("Received data: reconnectSuggested")
            break
        case .cancelled:
            isConnected = false
        case .error(let error):
            isConnected = false
            Swift.print("Error: \(error)")
        }
    }
    
}

extension Socket: Publisher {
    
    public func receive<S>(subscriber: S) where S:Subscriber, Failure == S.Failure, Output == S.Input {
        Swift.print("[Socket] subscribe: \(subscriber)")
        self.$rawMessage
            .setFailureType(to: SocketError.self)
            .receive(subscriber: subscriber)
    }
    
    public typealias Output = SocketMessage
    public typealias Failure = SocketError
}

public extension Track {
    
    func toPlayState(_ progressMs: Int? = 0) -> PlayStateRecord {
        return PlayState(accessToken: .empty, country: .empty, createdAt: self.createdAt,
                         createdById: createdById, deletedAt: deletedAt, deletedById: self.deletedById,
                         deviceUid: nil, displayName: .empty, email: .empty,
                         expiresIn: 0, id: 0, playingState: nil,
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



class JoliClipTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    var cancellable: AnyCancellable?
    var api: JoliApi?
    var soc: Socket?
    
    func testExample() throws {
        let expectation = XCTestExpectation(description: self.debugDescription)
        let q = DispatchQueue(label: self.debugDescription)
        
        let TOKEN: String = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpvbGlAam9saW1jLmFwcCIsImNyZWF0ZWRBdCI6IjIwMjAtMDgtMjJUMTM6NDQ6NTUuODY2WiIsImV4cGlyZXNJbiI6MTQ0MDAwMH0.OhxodQ0Zl0E_k_Su8CDwSB2scqteqfmyfUSMHwlfN00"
        
        //URL(string: "wss://192.168.1.173:8080/ws")!
        let baseUrl: JoliApi.BaseUrl = .homeDesktop
        api = JoliApi(baseUrl: baseUrl, authToken: TOKEN, headers: ["X-SESSION-ID": TOKEN])
        
//        let prom = api?.authenticate(token: TOKEN)
//            .then() { auth -> AnyPublisher<PlayState?, Error> in
//                print("[authenticated] playing track...")
//
//
//                return self.api!.playTrack(SEED_DATA.tracks[64 + 10], on: .main)
//            }
//            .then() { pub -> Cancellable in
//                return pub.sink() { completion in
//                    print("[complete] \(completion)")
//                } receiveValue: { value in
//                    print("[value] \(value)")
//                }
//            }
//
//        print("[promise] \(prom)")
//
        
        soc = Socket(url: URL(string: "wss://192.168.1.188:8080/ws")!)
        cancellable = soc?
            .autoconnect()
            .sink(){ completion in
                Swift.print("completion: \(completion)")
            } receiveValue: { value in
                Swift.print("receiveValue: \(value)")
            }
        
        
        let data: [String: Any] = [
            "topic": "/subscribe",
            "data": ["subject": "PLAYER_STATE_NOW_PLAYING"],
        ]
        
        let res = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        let str = String(data: res, encoding: .ascii)!
        
        q.asyncAfter(deadline: .now() + 1) {
            self.soc?.socket.write(string: str) {
                print("The data was sent")
            }
        }
        
        q.asyncAfter(deadline: .now() + 8) {
            self.soc?.socket.disconnect()
            expectation.fulfill()
        }
        
        XCTAssertNotNil(cancellable)
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testHearts() throws {
        // This is an example of a performance test case.
        let x = Hearts(score: 200)
        print("Hearts: \(x)")
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
