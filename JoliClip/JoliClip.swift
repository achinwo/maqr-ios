//
//  JoliClipApp.swift
//  JoliClip
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground

@main
struct JoliClip: AppClip {
    
    var coordinator = AppCoordinator()
    @Environment(\.scenePhase) var scenePhase
    @AppStorage(key: .authToken, store: .groupContainer) var authToken: String = .empty
    
    @AppStorage(key: .location, store: .groupContainer) var currentLocation: AppLocation = .home {
        didSet {
            logger.debug("[\(Self.self)] \(currentLocation)")
        }
    }
    
    var contentView: some View {
        ContentView()
    }
    
}
