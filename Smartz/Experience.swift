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

public protocol ExperinceOptions: Codable {
    
}

public struct EmptyExperinceOptions: ExperinceOptions {
    
}

public protocol Experience {
    //associatedtype Model: ExperienceData
    associatedtype Options: ExperinceOptions = EmptyExperinceOptions
    
    var dataModel: ExperienceData? { get nonmutating set }
    var dataModelDefault: ExperienceData.Defaults { get }
    
    var editMode: EditingState { get nonmutating set }
    
    static var title: String { get }
    static var subtitle: String { get }
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
    case inventory
    case weddingEvent
    case eshop
    
    public init?(rawValue: any Experience.Type) {
        switch rawValue {
            case is MealboxView.Type:
                self = .recipe
            case is TvShowPromoView.Type:
                self = .brandPromo
            case is BrandPromoView.Type:
                self = .brandPromo
            case is RestaurantView.Type:
                self = .restaurant
            case is InventoryView.Type:
                self = .inventory
            case is WeddingEventView.Type:
                self = .weddingEvent
            case is EshopView.Type:
                self = .eshop
            default:
                return nil
        }
    }
    
    public init?(typeName: String) {
        let typeNameLower = typeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard typeNameLower != "tvshowpromoview" else { // backwards compatibility
            self = .brandPromo
            return
        }
        
        for caz in Self.allCases {
            guard caz.rawValue.className.lowercased() == typeNameLower else { continue }
            
            self = caz
            return
        }
        return nil
    }
    
    public var rawValue: any Experience.Type {
        switch self {
            case .recipe:
                return MealboxView.self
            case .brandPromo:
                return BrandPromoView.self
            case .restaurant:
                return RestaurantView.self
            case .inventory:
                return InventoryView.self
            case .weddingEvent:
                return WeddingEventView.self
            case .eshop:
                return EshopView.self
        }
    }
    
    func toView(_ data: ExperienceData) -> some View {
        switch self {
            case .recipe:
                return MealboxView(data).eraseToAnyView()
            case .restaurant:
                return RestaurantView(data).eraseToAnyView()
            case .brandPromo:
                return BrandPromoView(data).eraseToAnyView()
            case .inventory:
                return InventoryView(data).eraseToAnyView()
            case .weddingEvent:
                return WeddingEventView(data).eraseToAnyView()
            case .eshop:
                return EshopView(data).eraseToAnyView()
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
    
    var type: (any Experience.Type)? {
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
