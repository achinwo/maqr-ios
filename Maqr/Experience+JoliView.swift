//
//  Experience+JoliView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 19/12/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import MaqrApi

#if !os(macOS)
import SharedUI
#endif

public typealias MultilineString = String

public extension Product.Identifier {
    // <app>_<price>_<duration>_<intro duration><intro price>
    static let prefix: String = "com.smartstickr.Smartz"

    static let sticker4Pack = Product.Identifier(.fixed(prefix: prefix, name: "pack4_399"))
    static let subscriptionBasic1m = Product.Identifier(.subscription(prefix: prefix, name: "basic_399_1m"))
    static let subscriptionBasic1y = Product.Identifier(.subscription(prefix: prefix, name: "basic_3799_1y"))
    
    static let oneoff24h = Product.Identifier(.oneoff(prefix: prefix, name: "199_7d", period: .period(.day, numberOfUnits: 7)))
    static let oneoff3d = Product.Identifier(.oneoff(prefix: prefix, name: "599_2w", period: .period(.week, numberOfUnits: 2)))
    static let oneoff1w = Product.Identifier(.oneoff(prefix: prefix, name: "999_4w", period: .period(.week, numberOfUnits: 4)))
    
    static let stikrProductIds: Set<Product.Identifier> = [
                sticker4Pack,
                subscriptionBasic1m,
                subscriptionBasic1y,
                oneoff3d,
                oneoff24h,
                oneoff1w
            ]
}

public extension JoliView where Self: Experience {
    
    static var supportedItemTypes: Set<ExperienceItemType> {
        return []
    }
    
    static var allDataKeys: [PartialKeyPath<ExperienceData>] {
        return Self.primaryDataKeys + Self.dataKeys
    }
    
    static var primaryDataKeys: [PartialKeyPath<ExperienceData>] {
        let paths: [PartialKeyPath<ExperienceData>] = [
            \ExperienceData.brandName,
            \ExperienceData.logoImageUrl,
            \ExperienceData.landingPageText,
            \ExperienceData.socialInstagramUsername,
            
            \ExperienceData.brandColorPrimary,
            \ExperienceData.brandColorSecondary,
            \ExperienceData.brandColorAccent,
        ]
        
        return paths
    }
    
    var body: some View {
        return self.contentView
            .onReceive(appCoordinator.connectionStateSubject) { state in
                self.onConnectionStateChange(state.state)
            }
            .ifLet(dataModel?.$editStartedAt) { view, editStartedAt in
                view.onReceive(editStartedAt) { dt in
                    self.editMode = dt != nil ? .active : .inactive
                }
            }
    }
}

struct EditPencilViewModifier: ViewModifier {
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Binding var displayMode: ViewDisplayMode
    @State var editMode: EditingState = .inactive
    
    func body(content: Content) -> some View {
        
        let editOverlay = VStack(){
            HStack(){
                Spacer()
                Group(){
                    if editMode == .active {
                        Text("Save")
                            .fixedSize()
                            .frame(width: 32, height: 32)
                            .padding()
                    } else {
                        Image(systemName: "pencil")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .padding()
                    }
                }
                .onTapGesture {
                    self.editMode = editMode == .active ? .inactive : .active
                }
                .foregroundColor(.primary)
                .background(Circle().foregroundColor(.blue).opacity(0.6))
                .padding(.top, safeAreaInsets.top)
                .padding(.trailing)
            }
            Spacer()
        }
        
        return Group(){
            if displayMode != .readonly {
                content
                #if !os(macOS)
                    .environment(\.editMode, $editMode)
                #endif
                    .overlay(editOverlay)
            } else {
                content
            }
        }
    }
}

extension View {
    func showEditPencil(_ displayMode: Binding<ViewDisplayMode>) -> some View {
        self.modifier(EditPencilViewModifier(displayMode: displayMode))
    }
}

enum ViewDisplayMode {
    case preview
    case readonly
}
