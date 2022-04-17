//
//  EventView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 15/04/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI

#if !os(macOS)
import SharedUI
#endif

struct WeddingEventView: JoliView, Experience {
    
    
    @State var dataModel: ExperienceData?
    
    var dataModelDefault: ExperienceData.Defaults
    
    @State var editMode: EditingState = .inactive
    
    static var title: String = "Wedding"
    
    static var subtitle: String = "Guest organiser for marriage ceremony"
    
    static var iconName: String = "person.2.circle"
    
    static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return []
    }
    
    static var basePath: String = "ewed"
    
    init(_ data: ExperienceData?) {
        self._dataModel = State(initialValue: data)
        self.dataModelDefault = ExperienceData.Defaults()
    }
    
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var contentView: some View {
        VStack(){
            Spacer()
            Text("Wedding Guest Experience").font(.title)
            Text("Coming soon!").foregroundColor(.secondaryLabel)
            Spacer()
            Spacer()
        }
        .frame(minWidth: screenWidth, minHeight: screenHeight, alignment: .center)
        .backgroundColor(.fixedWhite)
    }
}

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        WeddingEventView(nil)
    }
}
