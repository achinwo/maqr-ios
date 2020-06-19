//
//  UserSettings.swift
//  Joli
//
//  Created by Anthony Chinwo on 18/06/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import Combine

@propertyWrapper
struct UserDefault<T: Codable> {
    
    enum Key: String {
        case authToken
        case activeRoom
    }
    
    let key: Key
    let defaultValue: T
    
    init(_ key: Key, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            let data = UserDefaults.standard.data(forKey: key.rawValue)
            let value = data.flatMap { try? JSONDecoder().decode(T.self, from: $0) }
            return value ?? defaultValue
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: key.rawValue)
        }
    }
}

final class UserSettings: ObservableObject {

    var objectWillChange = PassthroughSubject<UserSettings, Never>()

    @UserDefault(.authToken, defaultValue: nil)
    var authToken: String? {
        willSet {
            objectWillChange.send(self)
        }
    }
}
