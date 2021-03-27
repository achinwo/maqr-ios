//
//  PlayroomCreateView.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/03/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI

public struct PlayroomCreateView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public var contentView: some View {
        VStack(alignment: .leading){
            Section(header: Text("Title")){
                Text("room name")
                //TextEditor(text: .constant("some description"))
            }
            
            Section(header: Text("Theme Song")){
                Text("choose theme song")
            }
            
            Section(header: Text("Location")){
                Text("room")
            }
        }
        .background(Color.green)
    }
    
}


struct PlayroomCreateView_Previews: PreviewProvider {
    static var previews: some View {
        PlayroomCreateView()
    }
}
