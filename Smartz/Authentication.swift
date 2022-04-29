//
//  Authentication.swift
//  Joli
//
//  Created by Anthony Chinwo on 29/04/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import JoliApi

public protocol AppAuthentication {
    
    //func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool) async -> Auth?
    
}

public extension AppAuthentication {
    
    @discardableResult
    @MainActor
    func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool) async -> Auth? {
        print("[authenticate] authenticating cred \(credentials)")
        return nil
    }
    
}
