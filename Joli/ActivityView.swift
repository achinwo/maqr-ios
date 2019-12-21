//
//  ActivityView.swift
//  Joli
//
//  Created by Anthony Chinwo on 20/12/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

protocol ConversationalView: View {
    
    associatedtype View1: View
    associatedtype View2: View
    associatedtype View3: View
    
}

extension ConversationalView {
    
    var body: some View {
        return ZStack() {
            Text("Stacked")
        }
    }
    
}

struct ActivityView: View {
    
    @EnvironmentObject var appState: AppState
    var room: Musicroom
    
    var body: some View {
        VStack(){
            Text("Activity")
        }
    }
}
