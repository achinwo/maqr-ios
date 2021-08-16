//
//  BlurView.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SwiftUI
import JoliCore
import AlertToast

#if os(macOS)
import AppKit

public typealias UIVisualEffectView = NSVisualEffectView
#else
//import LetterAvatarKit
#endif

//protocol User {
//    var name: String { get }
//}
//
//extension JoliCore.User: User {
//
//}




#if os(macOS)


public enum BlurEffectStyle {
    case systemMaterial
    case systemThickMaterialDark
    case systemThickMaterialLight
    
    case systemUltraThinMaterialDark
    case systemUltraThinMaterialLight
    
    case systemThinMaterialDark
    case prominent
}

public struct BlurView: NSViewRepresentable {
    public typealias NSViewType = NSVisualEffectView
    
    let style: BlurEffectStyle
    
    init(_ style: BlurEffectStyle = .systemMaterial) {
        self.style = style
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .withinWindow
        effectView.state = NSVisualEffectView.State.active
        return effectView
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .withinWindow
    }
}

#else

public typealias BlurEffectStyle = UIBlurEffect.Style

public struct BlurView: UIViewRepresentable {
    
    let style: BlurEffectStyle
    
    public init(_ style: BlurEffectStyle = .systemMaterial) {
        self.style = style
    }
    
    public func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: self.style))
    }
    
    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: self.style)
        uiView.isUserInteractionEnabled = false
    }
    
}

#endif
