//
//  ExperienceView.swift
//  Joli
//
//  Created by Anthony Chinwo on 02/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore
import Combine
import Promises

extension ExperienceItemType: Identifiable {
    public var id: String {
        return self.rawValue
    }
}

public protocol Experience {
    //associatedtype Model: ExperienceData
    var dataModel: ExperienceData? { get nonmutating set }
    var dataModelDefault: ExperienceData.Defaults { get }
    
    var editMode: EditMode { get nonmutating set }
    
    static var title: String { get }
    
    static var dataKeys: [PartialKeyPath<ExperienceData>] { get }
    static var allDataKeys: [PartialKeyPath<ExperienceData>] { get }
    static var supportedItemTypes: Set<ExperienceItemType> { get }
    
    static var basePath: String { get }
    static var className: String { get }
    
    init(_ data: ExperienceData?)
}

public extension Experience {
    
    static var className: String {
        return String(describing: Self.self)
    }
    
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
    @State var editMode: EditMode = .inactive
    
    func body(content: Content) -> some View {
        
        let editOverlay = VStack(){
            HStack(){
                Spacer()
                Group(){
                    if editMode == EditMode.active {
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
                    self.editMode = editMode == EditMode.active ? EditMode.inactive : EditMode.active
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
                    .environment(\.editMode, $editMode)
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

extension Color {
    static func random()->Color {
        let r = Double.random(in: 0 ... 1)
        let g = Double.random(in: 0 ... 1)
        let b = Double.random(in: 0 ... 1)
        return Color(red: r, green: g, blue: b)
    }
}

struct AnimatableGradientView: View {
    @State private var gradientA: [Color] = [.white, .red]
    @State private var gradientB: [Color] = [.white, .blue]
    
    @State private var firstPlane: Bool = true
    
    func setGradient(gradient: [Color]) {
        if firstPlane {
            gradientB = gradient
        }
        else {
            gradientA = gradient
        }
        firstPlane = !firstPlane
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: self.gradientA), startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 1)))
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: self.gradientB), startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 1)))
                .opacity(self.firstPlane ? 0 : 1)
            ///this button just demonstrates the solution
            Button(action:{
                withAnimation(.spring()) {
                    self.setGradient(gradient: [Color.random(), Color.random()])
                }
            })
            {
                Text("Change gradient")
            }
        }
    }
}
