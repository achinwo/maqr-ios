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
import JoliCore
import CancellationToken
import Combine
import JoliApi

class JoliClipTests: XCTestCase {
    
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
        soc = Socket(url: URL(string: "https://192.168.1.188:8080/ws")!)
        
        let cast = soc!
            .deserialize(PlayState.self)
            .autoconnect()
            .multicast() {
                return PassthroughSubject<PlayState, SocketError>()
            }
            .autoconnect()
        
        cancellable = cast
            .sink() { completion in
                    switch completion {
                        case .failure(let error): print("Error1 \(error)")
                        case .finished: print("Publisher is finished")
                    }
                } receiveValue: { playState in
                    print("[PlayState1] \(playState)")
                }
        
        print("[Subscribed] two=\(cancellable)")
        
        q.asyncAfter(deadline: .now() + 2) {
            self.soc?.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_NOW_PLAYING"]) { error in
                print("The data was sent")
            }
        }
        
        q.asyncAfter(deadline: .now() + 16) {
            expectation.fulfill()
        }
        
        XCTAssertNotNil(cancellable)
        wait(for: [expectation], timeout: 20.0)
        
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
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    var cancellable: AnyCancellable?
    var api: JoliApi?
    var soc: Socket?
    
}
