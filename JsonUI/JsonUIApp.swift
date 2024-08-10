//
//  JsonUIApp.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 16/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliApi
import JoliCore

@main
struct JsonUIApp: App {
    
    var coordinator: AppCoordinator
    var api: JoliApi
    
    static var defaultHeaders: [String: String] {
        
        let appInfo = resolveAppInfo()
        
        var headers = [
            "X-PLATFORM": "ios",
            "X-PLATFORM-VERSION": appInfo.systemVersion,
            "X-DEVICE-UUID": appInfo.uuid ?? "",
            "X-DEVICE-MODEL": appInfo.model,
            "X-DEVICE-NAME": appInfo.name,
        ]
        
        if let displayName = appInfo.appName {
            headers["X-APP-NAME"] = displayName
        }
        
        if let appId = appInfo.appId {
            headers["X-APP-ID"] = appId
        }
        
        return headers
    }
    
    static var wssUrlRequest: URLRequest {
        let url = JoliApi.Environment.current.baseUrl.ws
        var request = URLRequest(url: url.appendingPathComponent(Self.debug ? "/api/ws" : "/ws"), cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5)
        request.allHTTPHeaderFields = Self.defaultHeaders
        return request
    }
    
    static var debug: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }
    
    init() {
        JoliApi.BaseUrl.defaultDevUrl = URL(staticString: "https://maqr.co")
        JoliApi.BaseUrl.defaultProdUrl = URL(staticString: "https://maqr.co")
        
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let baseUrls = JoliApi.Environment.current.baseUrl
        
        self.api = JoliApi(baseUrl: baseUrls, headers: Self.wssUrlRequest.allHTTPHeaderFields ?? [:])
        
        self.coordinator.api = api
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(self.coordinator)
        }
    }
}
