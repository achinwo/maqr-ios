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

struct ActivityView: MusicroomTabView {
    init(room: Musicroom) {
        self.room = room
    }
    
    @EnvironmentObject var appState: AppState
    var room: Musicroom
    
    var body: some View {
        ScrollView(.vertical){
            if room.createdById != nil && self.appState.usersById[room.createdById!] != nil {
                HStack(){
                    UserProfileView(user: self.appState.usersById[room.createdById!]!.builder()).padding()
                    Spacer()
                    Text("host").padding([.leading, .trailing], 4)
                        .foregroundColor(.white).background(Color.gray).cornerRadius(12).padding()
                }
                Divider()
            } else {
                Text("Activity")
            }
        }//.frame(width: appState.screen.width, height: appState.screen.height, alignment: .center)
    }
}
