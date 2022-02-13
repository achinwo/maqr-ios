//
//  ReorderNowView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 13/02/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

public struct ReorderNowView: Experience, JoliView {
    
    public static var title: String = "Re-order Now"
    public static var basePath: String = "p"
    public static var iconName: String = "creditcard"
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State public var dataModel: ExperienceData?
    public let dataModelDefault = ExperienceData.Defaults()
    
    @State public var editMode: EditMode = .inactive
    
    public init(_ data: ExperienceData? = nil) {
        self._dataModel = State(initialValue: data)
    }
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return []
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return []
    }
    
    public var contentView: some View {
        VStack(){
            Text("ReorderNow")
        }
    }
    
}
