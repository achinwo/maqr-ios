//
//  JsonUIApp.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 16/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI

@main
struct JsonUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppCoordinator())
        }
    }
}
