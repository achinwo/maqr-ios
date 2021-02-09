//
//  Strings.swift
//  Joli
//
//  Created by Anthony Chinwo on 22/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import JoliApi

#if os(OSX)
import AppKit
public typealias UIFont = NSFont
public typealias UIImage = NSImage
#else
import UIKit
#endif
import os

// genstrings -a -o en.lproj ../*.swift && genstrings -a -o fr.lproj ../*.swift
//
internal let logger = Logger(subsystem: "com.jolimc.Joli", category: "global.client")

public enum Strings {
    
    public static let volume = NSLocalizedString("volume", comment: "Sound volume")
    public static let profile = NSLocalizedString("profile", comment: "User Profile Label")
    public static let photoUpload = NSLocalizedString("photoUpload", comment: "Upload picture")
    public static let reallyLogoutTitle = NSLocalizedString("reallyLogoutTitle", comment: "Confirm user really wants to log out")
    public static let reallyLogoutMessage = NSLocalizedString("reallyLogoutMessage", comment: "Confirm user really wants to log out")
    
    public static let appSymbol: Character = "ꚠ"
    
    #if DEBUG
    public static let appName = "Joli (Dev)"
    #else
    public static let appName = "Joli"
    #endif
}

public enum Images: String {
    
    case joliIconRounded = "joli_icon_rounded"
    case joliIcon = "joli_icon"
    case appclipBarcodeClearExample = "appclip_barcode_clear_example"
    case stockPhotoPartyPeople = "party-people"
    
    var image: Image {
        return Image(self.rawValue)
    }
    
    var uiImage: UIImage {
        return UIImage(named: self.rawValue)!
    }
    
}

public enum Sizing {
    
    public static let xxLarge = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
    public static let xLarge = UIFont.preferredFont(forTextStyle: .title1).pointSize
    public static let large = UIFont.preferredFont(forTextStyle: .title2).pointSize
    public static let medium = UIFont.preferredFont(forTextStyle: .headline).pointSize
    public static let small = UIFont.preferredFont(forTextStyle: .body).pointSize
    
    public static let xxxLarge = xxLarge * 2.0
    
}

public enum Colors {
    public static let lightGray = Color("light_gray")
}

public enum Urls {
    public static let appclips = URL(string: "https://developer.apple.com/app-clips/")!
}
