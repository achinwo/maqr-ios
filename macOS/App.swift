//
//  App.swift
//  Joli (macOS)
//
//  Created by Anthony Chinwo on 06/10/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

@main
struct Joli: App {
    
    var body: some Scene {
        WindowGroup {
            ZStack(){
                Text("Hello Mac!").font(.largeTitle)
            }
            .frame(width: 500, height: 300, alignment: .center)
        }
    }
}
