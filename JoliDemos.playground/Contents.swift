//: A UIKit based Playground for presenting user interface
import Foundation
import UIKit
import PlaygroundSupport
import SwiftUI
import JoliPlayground
import JoliCore
import JoliApi
@testable import Promises
import PartialSheet
import CancellationToken
import Combine
import Starscream
//Publishers


public enum SocketMessage {
    case track(Track)
}

public enum SocketError: Error {
    
}

public class Socket: ObservableObject, ConnectablePublisher {
    
    let socket: WebSocket
    var request: URLRequest
    
    @Published var isConnected: Bool = false
    
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
            socket.write(string: "{\"topic\": \"Test\", data: {}}") {
                Swift.print("Sent something")
            }
        case .disconnected(let reason, let code):
            isConnected = false
            Swift.print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            Swift.print("Received text: \(string)")
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
    }
    
    public typealias Output = SocketMessage
    public typealias Failure = SocketError
}


var soc: Socket!
var cancellable: AnyCancellable? = nil

func logicMain() -> Void {
    print("Logic main triggered")
    let track:Track = SEED_DATA.tracks.first!
    
    soc = Socket()
    soc.connect()
    cancellable = soc
        .sink(){ completion in
            print("completion: \(completion)")
        } receiveValue: { value in
            print("value: \(value)")
        }
    
    print("Cancellable: \(cancellable)")
//    let liveTrack: LiveTrack = track.play()
    PlaygroundPage.current.needsIndefiniteExecution = true
}

struct ContentView: View {
    
    //@EnvironmentObject var partial: PartialSheetManager
    
     var body: some View {
        let user = SEED_DATA.users.first!
        //print("partial: \(partial)")
        Text("Hello World \(user.name)")//
        //return DevicesSampleView()
            //.addPartialSheet()
        //UserProfileView2(user: user.builder()).offset(x: 0, y: 1)
     }
}

func uiMain() -> Void {
    
    let view = NavigationView(){
        ExploreView()
    }//.environmentObject(PartialSheetManager())
    
    let parent = playgroundWrapper(
        child: UIHostingController(rootView: view),
        device: .phone4inch,
        orientation: .portrait,
        contentSizeCategory: .large)
    
    PlaygroundPage.current.liveView = parent
}


let main: () -> Void = logicMain

main()

//hello()
// Present the view controller in the Live View window
//UIHostingController(rootView: ContentView())//

