//
//  MyExperiencesView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 08/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

public struct MyExperiencesView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Binding public var experiences: [StikrExperienceData]
    
    public var contentView: some View {
        VStack(){
            let headerMyExperiences = HStack(){
                Label(){
                    Text("My Experiences")
                } icon: {
                    Image(systemName: "infinity")
                        .font(Font.title.weight(.thin))
                }
                .foregroundColor(.secondary)
                .font(Font.largeTitle.weight(.thin))
                
                Spacer()
            }
            
            Section(header: headerMyExperiences) {
                
            }
            Spacer()
        }
    }

}

//struct MyExperiencesView_Previews: PreviewProvider {
//    static var previews: some View {
//        MyExperiencesView()
//    }
//}
