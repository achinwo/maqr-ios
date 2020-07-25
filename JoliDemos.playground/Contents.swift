//: A UIKit based Playground for presenting user interface
import JoliDemos_Sources
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

protocol LiveObject: ObservableObject {
    associatedtype DataModel
    
    var api: JoliApi { get }
    var lastValue: DataModel? { get }
    var lastUpdatedAt: Date? { get }
    
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
     var body: some View {
        let user = SEED_DATA.users.first!
        //Text("Hello World \(user.name)")//
        return SampleView()
                .addPartialSheet()//UserProfileView2(user: user.builder()).offset(x: 0, y: 1)
     }
}

func uiMain() -> Void {
    let parent = playgroundWrapper(
      child: UIHostingController(rootView: ContentView().environmentObject(PartialSheetManager())),
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

