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

protocol LiveObject: ObservableObject {
    associatedtype DataModel
    
    var api: JoliApi { get }
    var lastValue: DataModel? { get }
    var lastUpdatedAt: Date? { get }
    
    //var state: DataModel {set}
    
    func connect(_ cancellation: CancellationToken, timeoutAfter: DispatchTimeInterval?) -> Self
}



extension LiveObject where DataModel: Persisted {
    
}

extension LiveObject where DataModel: Playable {
    
}

extension LiveObject where DataModel: Persisted & Playable {
    
}

//extension LiveObject: Playable where DataModel: Playable {
    
//}

class LivePlayroom: LiveObject {
    
    var currentTask: DispatchWorkItem? = nil {
        willSet {
            if newValue == nil {
                currentTask?.cancel()
            }
        }
    }
    
    var timeout: DispatchTimeInterval = .seconds(60 * 2)
    
    func scheduleDisconnect(_ timeoutAt: DispatchTime? = nil) {
        let dispatchTime = timeoutAt ?? DispatchTime.now().advanced(by: self.timeout)
        
        guard let currentTask = self.currentTask else {
            return
        }
        
        currentTask.cancel()
        
        let task = DispatchWorkItem() {
            print("[LivePlayroom] scheduleDisconnect: \(self.initialValue.name)")
//            api.wsClient.unsubscribe(subject) { (res, error) in
//
//            }
        }
        self.currentTask = task
        
        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: task)
    }
    
    func connect(_ cancellation: CancellationToken, timeoutAfter: DispatchTimeInterval? = nil) -> Self {
        self.timeout = timeoutAfter ?? self.timeout
        
        scheduleDisconnect()
        
        let subject = "musicrooms/\(initialValue.id)"
        api.wsClient.subscribe(subject) { (res, error) in
            
        }
        
        cancellation.register {
            logger.debug("[LivePlayroom] unsubscribe: \(self.initialValue.name)")
            self.currentTask = nil
        }
        
        return self
    }
    
    
    var api: JoliApi
    var initialValue: Musicroom
    var lastValue: Musicroom? = nil {
        didSet {
            
        }
    }
    
    var lastUpdatedAt: Date?  = nil
    
    init(api: JoliApi, room: Musicroom) {
        self.api = api
        self.initialValue = room
    }
}
