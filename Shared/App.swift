//
//  App.swift
//  Joli
//
//  Created by Anthony Chinwo on 12/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import UIKit

@main
struct JoliApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        UITableView.appearance().separatorStyle = .none
    }
    
    var body: some Scene {
        WindowGroup {
            Text("App is starting")
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
                case .active:
                    print("App became active")
                case .inactive:
                    print("App became inactive")
                case .background:
                    print("App is running in the background")
                @unknown default:
                // Fallback for future cases
                    print("Unknown scene phase: \(phase)")
            }
        }
    }
}

//struct App_Previews: PreviewProvider {
//    static var previews: some View {
//        App()
//    }
//}
