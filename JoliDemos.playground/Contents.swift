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
//Publishers
protocol LiveObject: ObservableObject, ConnectablePublisher {
    
    typealias Locator = URLComponents
    typealias Attemp = (locator: Locator, payload: Any)
    
    enum ConnectionState {
        case initiating
        case connected
        case disconnected
        case errored(Error, Attempt?)
    }

    protocol Api {
        
    }
    
    associatedtype DataModel
    associatedtype ApiObject: Api
    
    var connectionState: Publisher<ConnectionState, Never>
    var api: ApiObject { get }
    var lastValue: DataModel? { get }
    var lastUpdatedAt: Date? { get }
    static func fromUri(_ url: URLComponents) -> Self
    static var cancellableSet: Set<AnyCancellable>
    
    
    
    //var state: DataModel {set}
    
    func connect(_ cancellation: CancellationToken, timeoutAfter: DispatchTimeInterval?) -> Self
}



extension LiveObject where DataModel: Persisted {
    
//    var currentTask: DispatchWorkItem? = nil {
//        willSet {
//            if newValue == nil {
//                currentTask?.cancel()
//            }
//        }
//    }
//
//    var timeout: DispatchTimeInterval = .seconds(60 * 2)
    
//    func scheduleDisconnect(_ timeoutAt: DispatchTime? = nil) {
//        let dispatchTime = timeoutAt ?? DispatchTime.now().advanced(by: self.timeout)
//
//        guard let currentTask = self.currentTask else {
//            return
//        }
//
//        currentTask.cancel()
//
//        let task = DispatchWorkItem() {
//            print("[LivePlayroom] scheduleDisconnect: \(self.initialValue.id)")
////            api.wsClient.unsubscribe(subject) { (res, error) in
////
////            }
//        }
//        self.currentTask = task
//
//        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: task)
//    }
    
//    func connect(_ cancellation: CancellationToken, timeoutAfter: DispatchTimeInterval? = nil) -> Self {
//        self.timeout = timeoutAfter ?? self.timeout
//
//        scheduleDisconnect()
//
//        let subject = "musicrooms/\(initialValue.id)"
//        api.wsClient.subscribe(subject) { (res, error) in
//
//        }
//
//        cancellation.register {
//            //logger.debug("[LivePlayroom] unsubscribe: \(self.initialValue.name)")
//            self.currentTask = nil
//        }
//
//        return self
//    }
    
    
//    var api: JoliApi
//    var initialValue: Persisted
//    var lastValue: Persisted? = nil {
//        didSet {
//
//        }
//    }
//
//    var lastUpdatedAt: Date?  = nil
    
//    init(api: JoliApi, initialValue: Persisted) {
//        self.api = api
//        self.initialValue = initialValue
//    }
}

extension LiveObject where DataModel: Playable {
    
}

extension LiveObject where DataModel: Persisted & Playable {
    
}

//extension LiveObject: Playable where DataModel: Playable {
    
//}

//extension Track {
//
//    func playLive() -> LiveTrack? {
//        self.play()
//        return nil
//    }
//
//}
//
//class LiveTrack<T: Playable>: LiveObject {
//    typealias DataModel = T
//
//    var initialValue: T
//
//    init(_ playable: T) {
//        self.initialValue = playable
//    }
//}

func logicMain() -> Void {
    print("Logic main triggered")
    let track:Track = SEED_DATA.tracks.first!
    
//    print("Live track: \(LiveTrack(track))")
//    let liveTrack: LiveTrack = track.play()
    
}

struct ContentView: View {
    
    @EnvironmentObject var partial: PartialSheetManager
    
     var body: some View {
        let user = SEED_DATA.users.first!
        print("partial: \(partial)")
        //Text("Hello World \(user.name)")//
        return DevicesSampleView()
            .addPartialSheet()
        
            //
        //        .addPartialSheet()
        //UserProfileView2(user: user.builder()).offset(x: 0, y: 1)
     }
}



func uiMain() -> Void {
    
    let view = NavigationView(){
        ContentView()
    }.environmentObject(PartialSheetManager())
    
    let parent = playgroundWrapper(
        child: UIHostingController(rootView: view),
        device: .phone4inch,
        orientation: .portrait,
        contentSizeCategory: .large)
    
    PlaygroundPage.current.liveView = parent
}

let main: () -> Void = uiMain

main()

//hello()
// Present the view controller in the Live View window
//UIHostingController(rootView: ContentView())//

