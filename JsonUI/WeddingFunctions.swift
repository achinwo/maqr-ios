//
//  WeddingFunctions.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 21/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import SharedUI

//WeddingFunctionView(imageName: "book.fill", title: "Our Story"),
//WeddingFunctionView(imageName: "chair.lounge", title: "Seating"),
//WeddingFunctionView(imageName: "list.bullet", title: "Order of Events"),
//WeddingFunctionView(imageName: "gift.fill", title: "Gift"),
//WeddingFunctionView(imageName: "fork.knife.circle.fill", title: "Food Menu"),
//WeddingFunctionView(imageName: "photo.on.rectangle.angled", title: "Photos"),
//WeddingFunctionView(imageName: "trophy.fill", title: "Thanks & Credits"),

public protocol WeddingItemView: EditableView, Identifiable {
    
    associatedtype NavButtonView: View
    
    var title: String { get nonmutating set }
    var systemImage: String { get nonmutating set }
    
    var navButton: NavButtonView { get }
}

struct WeddingStoryView: WeddingItemView {
    
    @Environment(\.viewModeGlobal) var viewModeGlobal: ViewMode
    
    @State var editMode: EditingState = .inactive
    @State var editButtonPlacement: Alignment = .topTrailing
    @State var editButtonOffset: CGSize = .zero
    @State public var active: Bool = false
    
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @State public var id = UUID()
    @State var title: String = "Our Story"
    @State var systemImage: String = "book.fill"
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    init(editPlacement: Alignment = .topTrailing, editOffset: CGSize = .zero) {
        self._editButtonPlacement = State(initialValue: editPlacement)
        self._editButtonOffset = State(initialValue: editOffset)
    }
    
    var navButton: some View {
        VStack(){
            
            Image(systemName: systemImage)
                .renderingMode(.original)
                .font(.title)
            Text(title)
                .font(.subheadline)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize()
                .padding(.top)
            
        }
    }
    
    var contentView: some View {
        VStack(){
            Text(title)
        }
    }
    
    func editSheet() -> some View {
        VStack(){
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            Toggle("Active", isOn: $active)
        }
        .padding()
    }
    
}
