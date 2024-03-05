//
//  ViewAttribute.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 04/03/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import SwiftUI
import SharedUI

final class FontLoader: ObservableObject {
    
    static var loaded: [URL: CGFont] = [:]
    
    static func remoteFont(url: URL) -> CGFont? {
        
        guard loaded[url] == nil else {
            return loaded[url]
        }
        
        guard let dataProvider = CGDataProvider(url: url as CFURL) else {
            //assertionFailure("Unable to create CGDataProvider")
            print("ERROR: Unable to create CGDataProvider")
            return nil
        }
        
        guard let font = CGFont(dataProvider) else {
            //assertionFailure("Unable to create font from data provider")
            print("ERROR: Unable to create font from data provider")
            return nil
        }
        
        CTFontManagerRegisterGraphicsFont(font, nil)
        loaded[url] = font
        
        return font
    }
    
}

public protocol ViewAttribute: ViewModifier {
    
    init(_ json: Json)
    
    static var empty: Self { get }
}

extension ViewAttribute {
    
    public static var empty: Self {
        Self.init([:] as Json)
    }
    
}


public struct TextAttribute: ViewAttribute {
    
    let json: Json
    
    @State var postscriptName: Font? = nil
    
    public init(_ json: Json) {
        self.json = json
    }
    
    @ViewBuilder
    public func bodyLegacy(content: Content) -> some View {
        content
    }
    
    @available(iOS 16.0, *)
    @ViewBuilder
    public func bodyContent(_ content: Content) -> some View {
        let view = content
            .bold(json["bold"] as? Bool ?? false)
            .font(.custom("Montserrat-Regular", size: 12))
            .task {
                    // Load font from URL using our FontLoader.
                guard let fontName = json["fontName"] as? String,
                      let fontUrlString = json["fontUrl"] as? String,
                      let fontUrl = URL(string: fontUrlString),
                      let font = FontLoader.remoteFont(url: fontUrl) else {
                    return
                }
                    
                print("Loaded font: \(String(describing: font.postScriptName))")
                
                if let postscriptName = font.postScriptName {
                    withAnimation {
                        self.postscriptName = .custom(postscriptName as String, size: 12)
                    }
                }
            }
        
        
        
        if let color = json["color"] as? String {
            view.foregroundStyle(Color.init(hex: color))
        } else {
            view
        }
    }
    
    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            bodyContent(content)
        } else {
            bodyLegacy(content: content)
        }
    }
    
}

extension View {
    
    public func applyAttribute<AttrType: ViewAttribute>(_ attribute: AttrType) -> ModifiedContent<Self, AttrType> {
        return .init(content: self, modifier: attribute)
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
