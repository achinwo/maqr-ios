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
    
    init(_ json: Json, fontNames: [String])
    
    func withFonts(_ fontNames: [String]) -> Self
    
    static var empty: Self { get }
}

extension ViewAttribute {
    
    public static var empty: Self {
        Self.init([:] as Json, fontNames: [])
    }
    
}


public struct TextAttribute: ViewAttribute {
    
    let json: Json
    let fontNames: [String]
    
    @State var postscriptName: Font? = nil
    
    public init(_ json: Json, fontNames: [String] = []) {
        self.json = json
        self.fontNames = fontNames
    }
    
    public func withFonts(_ fontNames: [String]) -> TextAttribute {
        return Self.init(json, fontNames: fontNames)
    }
    
    @ViewBuilder
    public func bodyLegacy(content: Content) -> some View {
        content
    }
    
    var font: Font? {
        guard let fontName = json["fontName"] as? String, fontNames.contains(fontName) else {
            return nil
        }
        
        return .custom(fontName, size: json["fontSize"] as? CGFloat ?? Sizing.headline, relativeTo: .headline)
    }
    
    var foregroundColor: Color? {
        guard let color = json["color"] as? String else {
            return nil
        }
        
        return Color.init(hex: color)
    }
    
    @available(iOS 16.0, *)
    @ViewBuilder
    public func bodyContent(_ content: Content) -> some View {
        content
            .bold(json["bold"] as? Bool ?? false)
            .font(self.font)
            .foreground(self.foregroundColor)
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
    
    public func applyAttribute<AttrType: ViewAttribute>(_ attribute: AttrType, availiableFontNames: [String] = []) -> ModifiedContent<Self, AttrType> {
        return .init(content: self, modifier: attribute)
    }
    
    @ViewBuilder
    public func foreground<S>(_ style: S?) -> some View where S: ShapeStyle {
        if let style {
            self.foregroundStyle(style)
        } else {
            self
        }
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
