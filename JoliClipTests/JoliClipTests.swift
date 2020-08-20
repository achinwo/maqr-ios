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
    
    public init(){
        request = URLRequest(url: URL(string: "wss://192.168.1.173:8080/ws")!)
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

class JoliClipTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        let expectation = XCTestExpectation(description: self.debugDescription)
        let q = DispatchQueue(label: self.debugDescription)
        
        let soc = Socket()
        let cancellable = soc
            .autoconnect()
            .sink(){ completion in
                Swift.print("completion: \(completion)")
            } receiveValue: { value in
                Swift.print("value: \(value)")
            }
        
        let data: [String: Any] = [
            "topic": "/test",
            "data": [:],
        ]
        
        let res = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        let str = String(data: res, encoding: .ascii)!
        
        q.asyncAfter(deadline: .now() + 1) {
            soc.socket.write(string: str) {
                print("The data was sent")
            }
        }
        
        q.asyncAfter(deadline: .now() + 4) {
            expectation.fulfill()
        }
        
        XCTAssertNotNil(cancellable)
        wait(for: [expectation], timeout: 5.0)
        
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
