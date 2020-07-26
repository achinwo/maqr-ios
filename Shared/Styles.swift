//
//  Styles.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi

struct GradientBackgroundStyle: ButtonStyle {
    
    var colors: [Color]
    
    init(colors: [Color]? = nil){
        self.colors = colors ?? [Color.blue, Color.green]
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            //.frame(minWidth: 0, maxWidth: .infinity)
            .foregroundColor(.white)
            .background(LinearGradient(gradient: Gradient(colors: self.colors), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(.percent40)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct BlackWhiteButtonStyle: ButtonStyle {
    
    var white: Color = .white
    var black: Color = .black
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            //.frame(minWidth: 0, maxWidth: .infinity)
            .foregroundColor(self.white)
            .background(self.black)
            .cornerRadius(.percent40)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct NeumorphicButtonStyle: ButtonStyle {
    var bgColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {
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

extension CGFloat {
    static var percent40: CGFloat {
        return 40
    }
    
    static var percent20: CGFloat {
        return 20
    }
}
