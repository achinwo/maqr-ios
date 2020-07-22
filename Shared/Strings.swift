//
//  Strings.swift
//  Joli
//
//  Created by Anthony Chinwo on 22/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation

// genstrings -o en.lproj ../*.swift && genstrings -o fr.lproj ../*.swift
//

enum Strings: String {
    
    case profile
    case photoUpload
    
    var rawValue: String {
        switch self {
        case .profile:
            return NSLocalizedString("profile", comment: "User Profile Label")
        case .photoUpload:
            return NSLocalizedString("photoUpload", comment: "Upload picture")
        }
    }
    
}
