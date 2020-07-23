//
//  Strings.swift
//  Joli
//
//  Created by Anthony Chinwo on 22/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
// genstrings -o en.lproj ../*.swift && genstrings -o fr.lproj ../*.swift
//

enum Strings: String {
    
    case profile
    case photoUpload
    case reallyLogoutTitle
    case reallyLogoutMessage
    
    var rawValue: String {
        switch self {
        case .profile:
            return NSLocalizedString("profile", comment: "User Profile Label")
        case .photoUpload:
            return NSLocalizedString("photoUpload", comment: "Upload picture")
        case .reallyLogoutTitle:
            return NSLocalizedString("reallyLogoutTitle", comment: "Confirm user really wants to log out")
        case .reallyLogoutMessage:
            return NSLocalizedString("reallyLogoutMessage", comment: "Confirm user really wants to log out")
        }
    }
    
}

enum Sizing: RawRepresentable {
    
    init?(rawValue: CGFloat) {
        self = .literal(rawValue)
    }
    
    case large
    case medium
    case literal(CGFloat)
    
    static func fromFont(_ font: UIFont.TextStyle) -> CGFloat {
        return UIFont.preferredFont(forTextStyle: font).pointSize
    }
    
    var rawValue: CGFloat {
        switch self {
        case .large:
            return Sizing.fromFont(.title1)
        case .medium:
            return Sizing.fromFont(.headline)
        case .literal(let raw):
            return raw
        }
    }
    
}

enum NamedColor: String {
    case lightGray = "light_gray"
}

extension Color {
    init(named: NamedColor) {
        self.init(named.rawValue)
    }
}
