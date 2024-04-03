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
    
    static func remoteFont(url: URL, priority: TaskPriority = .userInitiated) async -> CGFont? {
        
        guard loaded[url] == nil else {
            return loaded[url]
        }
        
        let font: CGFont? = await Task<CGFont?, Never>(priority: priority) {
            
            let request = URLRequest(url: url)
    
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let dataProvider = CGDataProvider(data: data as CFData) else {
            //guard let dataProvider = CGDataProvider(url: url as CFURL) else {
                print("ERROR: Unable to create CGDataProvider")
                return nil
            }
            
            guard let font = CGFont(dataProvider) else {
                print("ERROR: Unable to create font from data provider")
                return nil
            }
            
            CTFontManagerRegisterGraphicsFont(font, nil)
            
            return font
        }.value
        
        loaded[url] = font
        
//        var request = URLRequest(url: url)
//        
//        
//        
//        guard let (data, _) = try? await URLSession.shared.data(for: request),
//              let dataProvider = CGDataProvider(data: data as CFData) else {
//        
        return font
    }
    
}

extension Never: CodingKey {
    
}

//public protocol ViewAttributeEdit: View {
//    associatedtype ViewAttributeType: ViewAttribute
//    
//    init(_ stateObject: ViewAttributeType.Model)
//}

public protocol ViewAttribute: ViewModifier {
    
    associatedtype CodingKeys: CodingKey & Hashable = Never
    //associatedtype Model: ObservableObject = Never
    //associatedtype EditView: ViewAttributeEdit
    
    var attribute: ContentAttributeData { get }
    
    init(_ attribute: ContentAttributeData)
    
    static var empty: Self { get }

}

extension ViewAttribute {
    
    public static var empty: Self {
        Self.init(ContentAttributeData([:]))
    }
    
}

public struct BackgroundAttribute: ViewAttribute {
    
//    public final class Model: ObservableObject {
//        
//    }
//    
//    public struct EditView: ViewAttributeEdit {
//        public typealias ViewAttributeType = BackgroundAttribute
//        
//        
//        
//        public init(_ stateObject: ViewAttributeType.Model) {
//            
//        }
//        
//        public var body: some View {
//            EmptyView()
//        }
//        
//    }
    
    public enum Mode: String, CaseIterable, Identifiable {
        
        case solid
        case gradient
        case image
        case none
        
        public var id: String {
            return self.rawValue
        }
    }
    
    public let attribute: ContentAttributeData
    
    public init(_ attribute: ContentAttributeData) {
        self.attribute = attribute
    }
    
    public var imageUrl: URL? {
        guard let urlString = attribute.backgroundImageUrl else { return nil }
        
        return URL(string: urlString)
    }
    
    public var mode: Mode {
        guard let mode = attribute.backgroundMode else {
            return .solid
        }
        
        return Mode.init(rawValue: mode) ?? .solid
    }
    
    public var color: Color? {
        guard let bgColor = attribute.backgroundColor else {
            return nil
        }
        
        return Color(hex: bgColor)
    }
    
    public var backgroundImage: some View {
        AsyncImage(url: imageUrl) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            self.color
        }
    }
    
    @ViewBuilder
    public func background() -> some View {
        switch mode {
            case .image:
                backgroundImage
            case .gradient:
                gradient()
            case .solid:
                color
            case .none:
                EmptyView()
        }
    }
    
    public var opacity: CGFloat {
        return 1
    }
    
    @ViewBuilder
    public func gradient() -> some View {
        if let colorStart = color,
           let colorEndHex = attribute.backgroundColor2 {
            LinearGradient(colors: [colorStart, Color(hex: colorEndHex)], startPoint: .top, endPoint: .bottom)
        } else {
            backgroundImage
        }
    }
    
    @ViewBuilder
    public func body(content: Content) -> some View {
        content
            .background(background().opacity(opacity))
    }
    
}


public struct TextAttribute: ViewAttribute {
    
    public final class Model: ObservableObject {
        
    }
    
    public enum CodingKeys: String, CodingKey {
        case fontName = "fontName"
        case fontSize = "fontSize"
        case color = "color"
        case bold = "bold"
    }
    
    public let attribute: ContentAttributeData
    @Environment(\.availableFontNames) var availableFontNames: Set<String>
    
    public init(_ attribute: ContentAttributeData) {
        self.attribute = attribute
    }
    
    var defaultFont: Font? {
        guard let fontSize = attribute.fontSize else {
            return nil
        }
        
        return .system(size: fontSize)
    }
    
    var font: Font? {
        guard let fontName = attribute.fontName, availableFontNames.contains(fontName) else {
            return defaultFont
        }
        
        return .custom(fontName, size: attribute.fontSize ?? Sizing.headline, relativeTo: .headline)
    }
    
    var foregroundColor: Color? {
        guard let color = attribute.color else {
            return nil
        }
        
        return Color.init(hex: color)
    }
    
    @available(iOS 16.0, *)
    @ViewBuilder
    public func bodyContent(_ content: Content) -> some View {
        content
            .bold(attribute.bold ?? false)
            .font(self.font)
            .foreground(self.foregroundColor)
    }
    
    @ViewBuilder
    public func bodyLegacy(content: Content) -> some View {
        content
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
