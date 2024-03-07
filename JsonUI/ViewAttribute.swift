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
    
    static func remoteFont(url: URL) async -> CGFont? {
        
        guard loaded[url] == nil else {
            return loaded[url]
        }
        
        let font: CGFont? = await Task<CGFont?, Never> {
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
            return font
        }.value
        
        loaded[url] = font
        
        return font
    }
    
}

public protocol ViewAttribute: ViewModifier {
    
    associatedtype CodingKeys = Never
    
    init()
    
    static var empty: Self { get }
}

public extension ViewAttribute where CodingKeys: Hashable {
    
    typealias PropertiesDict = [Self.CodingKeys: Codable]
    
}

extension ViewAttribute {
    
    public static var empty: Self {
        Self.init()
    }
    
}


public struct TextAttribute: ViewAttribute {
    
    public enum CodingKeys: String, CodingKey {
        case fontName = "fontName"
        case fontSize = "fontSize"
        case color = "color"
        case bold = "bold"
    }
    
    let json: PropertiesDict
    @Environment(\.availableFontNames) var availableFontNames: Set<String>
    
    public init(_ json: PropertiesDict) {
        self.json = json
    }
    
    public init() {
        self.json = [:]
    }
    
    @ViewBuilder
    public func bodyLegacy(content: Content) -> some View {
        content
    }
    
    var defaultFont: Font? {
        guard let fontSize = json[.fontSize] as? CGFloat else {
            return nil
        }
        
        return .system(size: fontSize)
    }
    
    var font: Font? {
        guard let fontName = json[.fontName] as? String, availableFontNames.contains(fontName) else {
            return defaultFont
        }
        
        return .custom(fontName, size: json[.fontSize] as? CGFloat ?? Sizing.headline, relativeTo: .headline)
    }
    
    var foregroundColor: Color? {
        guard let color = json[.color] as? String else {
            return nil
        }
        
        return Color.init(hex: color)
    }
    
    @available(iOS 16.0, *)
    @ViewBuilder
    public func bodyContent(_ content: Content) -> some View {
        content
            .bold(json[.bold] as? Bool ?? false)
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

public struct FontNamesKey: EnvironmentKey {
    public static let defaultValue: Set<String> = []
}

extension EnvironmentValues {
    
    var availableFontNames: Set<String> {
        get { self[FontNamesKey.self] }
        set { self[FontNamesKey.self] = newValue }
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
