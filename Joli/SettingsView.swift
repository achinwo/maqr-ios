//
//  SettingsView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        return GeometryReader() { geometry in
            VStack {
                Button(action: {
                    self.appState.isSettingsPresented.toggle()
                }) {
                    Image(systemName: "xmark")
                    Text("Close")
                }
                .padding()
                VStack {
                    Text("Home").background(Color.red)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topTrailing)
            .background(Color.yellow)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
