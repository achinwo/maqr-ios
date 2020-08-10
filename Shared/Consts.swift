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
import JoliApi
// genstrings -a -o en.lproj ../*.swift && genstrings -a -o fr.lproj ../*.swift
//
public let logger = JoliApi.getLogger()

public enum Strings {
    
    public static let volume = NSLocalizedString("volume", comment: "Sound volume")
    public static let profile = NSLocalizedString("profile", comment: "User Profile Label")
    public static let photoUpload = NSLocalizedString("photoUpload", comment: "Upload picture")
    public static let reallyLogoutTitle = NSLocalizedString("reallyLogoutTitle", comment: "Confirm user really wants to log out")
    public static let reallyLogoutMessage = NSLocalizedString("reallyLogoutMessage", comment: "Confirm user really wants to log out")
    
}

public enum Images: String {
    case joliIconRounded = "joil_icon_rounded"
    
    var image: Image {
        return Image(self.rawValue)
    }
    
    var uiImage: UIImage? {
        return UIImage(named: self.rawValue)
    }
    
}

public enum Sizing {
    
    public static let large = UIFont.preferredFont(forTextStyle: .title1).pointSize
    public static let medium = UIFont.preferredFont(forTextStyle: .headline).pointSize
    public static let small = UIFont.preferredFont(forTextStyle: .body).pointSize
    
}

public enum Colors {
    public static let lightGray = Color("light_gray")
}
