//
//  EshopView.swift
//  Joli
//
//  Created by Anthony Chinwo on 12/07/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

struct EshopView: JoliView, Experience {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var dataModel: ExperienceData?
    
    var dataModelDefault: ExperienceData.Defaults
    
    @State var editMode: EditingState = .inactive
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    static var title: String = "eShop"
    
    static var subtitle: String = "Mini-ecommerce page to sell products and services"
    
    static var iconName: String = "bag"
    
    static var basePath: String = "eshop"
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
            \ExperienceData.bannerImageUrl,
             \ExperienceData.backgroundImageUrl,
             \ExperienceData.brandContactEmail,
             \ExperienceData.productName,
             \ExperienceData.productDescription,
             \ExperienceData.productImageUrl,
             \ExperienceData.socialInstagramUsername,
             \ExperienceData.socialFacebookPage,
        ]
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return [.product]
    }
    
    public var items: [ExperienceData.Item] = [
//        ExperienceData.Item(experienceItemType: .product, aliasTitle: , defaultPrice: , imageName: ,
//                            itemGrouping: , itemSubgrouping: , subtitle: , title: , uuid: UUID().uuidString),
    ]
    
    init(_ data: ExperienceData?) {
        self._dataModel = State(initialValue: data)
        self.dataModelDefault = ExperienceData.Defaults()
    }
    
    //https://dribbble.com/shots/18733610-TokoMegawa-E-Commerce
    var contentView: some View {
        let columns = [
            GridItem(.adaptive(minimum: screenWidth / 3, maximum: screenWidth / 2), spacing: Sizing.small),
            GridItem(.adaptive(minimum: screenWidth / 3, maximum: screenWidth / 2), spacing: Sizing.small)
        ]
        
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        
        return ScrollView(.vertical) {
            LazyVGrid(columns: columns) {
                ForEach(0..<300) { idx in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(colors[(idx / 8) % 7])
                        .frame(height: 30)
                }
            }
            .padding(.horizontal)
        }
    }
    
}
