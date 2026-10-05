//
//  Styles.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import MaqrApi

#if os(macOS)
import AppKit
#endif

public struct GradientBackgroundStyle: ButtonStyle {
    
    public var colors: [Color]
    
    public init(colors: [Color]? = nil){
        self.colors = colors ?? [Color.systemBlue, Color.systemGreen]
    }
    
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            //.frame(minWidth: 0, maxWidth: .infinity)
            .foregroundColor(.white)
            .background(LinearGradient(gradient: Gradient(colors: self.colors), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(.percent40)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

public struct BlackWhiteButtonStyle: ButtonStyle {
    
    var white: Color = .systemBackground
    var black: Color = .label
    var isInverted = false
    
    init(white: Color = .systemBackground, black: Color = .label){
        self.white = white
        self.black = black
    }
    
    public init(inverted: Bool) {
        self.init()
        isInverted = inverted
    }
    
    public func makeBody(configuration: Self.Configuration) -> some View {
        let fgColor = isInverted ? self.white : self.black
        return configuration.label
            //.frame(minWidth: 0, maxWidth: .infinity)
            .foregroundColor(fgColor)
            //.cornerRadius(.percent40)
            .overlay(Capsule()
                        .stroke(Colors.lightGray, lineWidth: 1)
                        .clipped())
            .background(isInverted ? self.black : self.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

public struct NeumorphicButtonStyle: ButtonStyle {
    var bgColor: Color

    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .shadow(color: .white, radius: configuration.isPressed ? 7: 10, x: configuration.isPressed ? -5: -15, y: configuration.isPressed ? -5: -15)
                        .shadow(color: .black, radius: configuration.isPressed ? 7: 10, x: configuration.isPressed ? 5: 15, y: configuration.isPressed ? 5: 15)
                        .blendMode(.overlay)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bgColor)
                }
        )
            .scaleEffect(configuration.isPressed ? 0.95: 1)
            .foregroundColor(.primary)
            .animation(.spring())
    }
}

public extension CGFloat {
    static var percent40: CGFloat {
        return 40
    }
    
    static var percent20: CGFloat {
        return 20
    }
}
