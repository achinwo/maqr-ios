//
//  InventoryView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 19/03/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI

struct InventoryView: JoliView, Experience {
    
    @State var dataModel: ExperienceData?
    var dataModelDefault: ExperienceData.Defaults
    
    @State var editMode: EditingState = .inactive
    
    static var title: String = "Inventory"
    static var subtitle: String = "Inventory management made effortless"
    
    static var iconName: String = "tray.full"
    
    static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return []
    }
    
    static var basePath: String = "erecord"
    
    init(_ data: ExperienceData?) {
        self._dataModel = State(initialValue: data)
        self.dataModelDefault = ExperienceData.Defaults()
    }
    
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    
    var contentView: some View {
        Text("Inventory View!")
    }
}
