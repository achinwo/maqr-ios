import Foundation
import Combine
import Starscream
import CancellationToken
import JoliApi
import JoliCore

protocol Api {
    
}

typealias Locator = URLComponents
typealias Attempt = (locator: Locator, payload: Any)

enum ConnectionState {
    case initiating
    case connected
    case disconnected
    case errored(Error, Attempt?)
}

protocol LiveObject: ObservableObject, ConnectablePublisher {
    
    associatedtype DataModel
    associatedtype ApiObject: Api
    
    var connectionState: ConnectionState { get }
    var api: ApiObject { get }
    var lastValue: DataModel? { get }
    var lastUpdatedAt: Date? { get }
    static func fromUri(_ url: URLComponents) -> Self
    static var cancellableSet: Set<AnyCancellable> { get }
    
    
    
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

