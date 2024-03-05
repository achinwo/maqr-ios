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
import JoliCore

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
    
    @State var id: String = "wedding/story"
    
    @State var editMode: EditingState = .inactive
    @State var editButtonPlacement: Alignment = .topTrailing
    @State var editButtonOffset: CGSize = .init(width: 0, height: 0)
    @State public var active: Bool = true
    @State var attribute: TextAttribute = .init(["bold": true,
                                                 "color": "#000000",
                                                 "fontUrl": "http://themes.googleusercontent.com/static/fonts/montserrat/v3/zhcz-_WihjSQC0oHJ9TCYC3USBnSvpkopQaUR-2r7iU.ttf",
                                                 //"fontName": "Montserrat-Regular"
    ] as Json)
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @Binding var title: String
    @Binding var systemImage: String
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Environment(\.viewModeGlobal) var viewModeGlobal: ViewMode
    
    init(title: Binding<String>, systemImage: Binding<String>){
        _title = title
        _systemImage = systemImage
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
                .applyAttribute(attribute)
        }
    }
    
    var contentView: some View {
        NavigationLink(){
            contentView2
        } label: {
            navButton
                .frame(width: screenWidth / 4, height: screenWidth / 6)
                .padding()
        }
        .buttonStyle(.bordered)
        .disabled(!active)
    }
    
    var contentView2: some View {
        VStack(){
            Text(title)
                .font(.title.weight(.light))
            Spacer()
        }
        .frame(minWidth: screenWidth * 0.7)
        .padding()
        .padding(.top)
    }
    
    func editSheet() -> some View {
        if #available(iOS 17.1, *) {
#if DEBUG
            Self._logChanges()
            Self._printChanges()
#endif
        }
        return VStack(){
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            Toggle("Active", isOn: $active)
        }
        .padding()
    }
    
}

struct WeddingFunctionView: WeddingItemView {
    
    var id: String {
        get {
            "\(systemImage)/\(title)"
        }
        nonmutating set {}
    }
    
    @State var attribute: TextAttribute = .init(["bold": false] as Json)
    @State var editMode: EditingState = .inactive
    @State var editButtonPlacement: Alignment = .topTrailing
    @State var editButtonOffset: CGSize = .init(width: 0, height: 50)
    @State public var active: Bool = false
    
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @State var title: String //= "Our Story"
    @State var systemImage: String //= "book.fill"
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Environment(\.viewModeGlobal) var viewModeGlobal: ViewMode
    
    init(title: String, systemImage: String, editPlacement: Alignment = .topTrailing, editOffset: CGSize = .zero) {
        self._editButtonPlacement = State(initialValue: editPlacement)
        self._editButtonOffset = State(initialValue: editOffset)
        self._title = State(initialValue: title)
        self._systemImage = State(initialValue: systemImage)
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
                .applyAttribute(attribute)
            
        }
    }
    
    var contentView: some View {
        VStack(){
            Text(title)
                .font(.title.weight(.light))
            Spacer()
        }
        .frame(minWidth: screenWidth * 0.7)
        .padding()
        .padding(.top)
    }
    
    func editSheet() -> some View {
        if #available(iOS 17.1, *) {
#if DEBUG
            Self._logChanges()
            Self._printChanges()
#endif
        } else {
                // Fallback on earlier versions
        }
        return VStack(){
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            Toggle("Active", isOn: $active)
        }
        .padding()
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}

