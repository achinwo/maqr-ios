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
            .padding()
            .foregroundColor(.white)
            .background(LinearGradient(gradient: Gradient(colors: self.colors), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(.percent40)
            .padding(.horizontal, 20)
    }
}

struct BlackWhiteButtonStyle: ButtonStyle {
    
    var white: Color = .white
    var black: Color = .black
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            //.frame(minWidth: 0, maxWidth: .infinity)
            .padding()
            .foregroundColor(self.white)
            .background(self.black)
            .cornerRadius(.percent40)
            .padding(.horizontal, 20)
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
