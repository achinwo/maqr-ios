//
//  ExperienceView.swift
//  Joli
//
//  Created by Anthony Chinwo on 02/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground

public protocol ExperienceKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

struct ExperienceValues {
    
    var values: [String: AnyObject] = [:]
    
    public subscript<K>(key: K.Type) -> K.Value where K : ExperienceKey {
        get {
            return values[String(describing: key)] as? K.Value ?? K.defaultValue
        }
        
        set {
            values[String(describing: key)] = newValue as AnyObject
        }
    }
    
}

protocol ExperienceInfo: CaseIterable {
    
}

protocol ExperienceView: JoliView {
    
    associatedtype Info: ExperienceInfo
    
    
}

struct RestaurantView: ExperienceView {
    
    enum Keys: String, CaseIterable {
        case companyName
        case companyId
    }
    
    struct Info: ExperienceInfo {
        static var allCases: [RestaurantView.Info] {
            return []
        }
        
        let companyName: String
    }
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let info: Info?
    
    public init(info: Info? = nil){
        self.info = info
    }
    
    var contentView: some View {
        Text("Hello, World!")
    }
    
}
