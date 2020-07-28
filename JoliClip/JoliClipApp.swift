//
//  JoliClipApp.swift
//  JoliClip
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
//NSUserActivity
@main
struct JoliClipApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let incomingUrl = userActivity.webpageURL, let components = URLComponents(url: incomingUrl, resolvingAgainstBaseURL: true) else {
                        logger.info("[JoliAppClip] unable to resolve: \(userActivity)")
                        return
                    }
                    
                    logger.info("[JoliAppClip] got url: \(components), activity: \(userActivity.title), \(userActivity.requiredUserInfoKeys), \(userActivity.keywords)")
                }
                
        }
    }
}
