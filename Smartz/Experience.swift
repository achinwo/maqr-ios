//
//  ExperienceView.swift
//  Joli
//
//  Created by Anthony Chinwo on 02/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
//import SharedUI
import JoliCore
import Combine

extension ExperienceItemType: Identifiable {
    public var id: String {
        return self.rawValue
    }
}

#if os(macOS)
public enum EditingState: Hashable, Equatable {
    case active
    case inactive
    case transient
    var isEditing: Bool { self == .active }
}
#else
public typealias EditingState = EditMode
#endif

public protocol Experience {
    //associatedtype Model: ExperienceData
    var dataModel: ExperienceData? { get nonmutating set }
    var dataModelDefault: ExperienceData.Defaults { get }
    
    var editMode: EditingState { get nonmutating set }
    
    static var title: String { get }
    static var iconName: String { get }
    
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

public enum Experiences: RawRepresentable, CaseIterable {
    
    case recipe
    case brandPromo
    case restaurant
    
    public init?(rawValue: Experience.Type) {
        switch rawValue {
        case is MealboxView.Type:
            self = .recipe
        case is TvShowPromoView.Type:
            self = .brandPromo
        case is RestaurantView.Type:
            self = .restaurant
        default:
            return nil
        }
    }
    
    public init?(typeName: String) {
        for caz in Self.allCases {
            guard caz.rawValue.className.lowercased() == typeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { continue }
            
            self = caz
            return
        }
        return nil
    }
    
    public var rawValue: Experience.Type {
        switch self {
        case .recipe:
            return MealboxView.self
        case .brandPromo:
            return TvShowPromoView.self
        case .restaurant:
            return RestaurantView.self
        }
    }
    
    func toView(_ data: ExperienceData) -> some View {
        switch self {
            case .recipe:
                return MealboxView(data).eraseToAnyView()
            case .restaurant:
                return RestaurantView(data).eraseToAnyView()
            case .brandPromo:
                return TvShowPromoView(data).eraseToAnyView()
        }
    }
    
}

extension Experiences {
    
    public static func fromTypeName(_ typeName: String?) -> Experiences? {
        guard let typeName = typeName, let typeInfo = Experiences(typeName: typeName) else {
            //print("No type info: \(typeName)")
            return nil
        }
        
        return typeInfo
    }
    
}

extension StikrExperienceData {
    
    var type: Experience.Type? {
        return typeInfo?.rawValue
    }
    
    var typeInfo: Experiences? {
        return Experiences(typeName: self.experienceTypeName)
    }
    
}

extension Color {
    static func random() -> Color {
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
            Button(){
                withAnimation(.spring()) {
                    self.setGradient(gradient: [Color.random(), Color.random()])
                }
            } label: {
                Text("Change gradient")
            }
        }
    }
}
