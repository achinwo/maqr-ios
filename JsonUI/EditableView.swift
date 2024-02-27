//
//  EditableView.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 21/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import Foundation
import SharedUI
import SwiftUI

#if os(macOS)
public enum EditingState: Hashable, Equatable {
    case active
    case inactive
    case transient
}
#else
public typealias EditingState = EditMode
#endif


extension EditingState {
    
    var isEditing: Bool { self == .active }
    
    mutating func toggle() {
        self = self == .active ? .inactive : .active
    }
    
    var opacity: CGFloat {
        switch self {
            case .active:
                return 0.4
            case .inactive:
                return 0.9
            case .transient:
                fallthrough
            @unknown default:
                return 0
        }
    }
    
}

public struct ExperienceData {
    
}

public protocol Experience {
    
    var dataModel: ExperienceData? { get nonmutating set }
    
    var editMode: EditingState { get nonmutating set }
    
    static var basePath: String { get }
    
    init(_ data: ExperienceData?)
}

extension UIImagePickerController.SourceType: Identifiable {
    
    public var id: Int {
        self.rawValue
    }
    
}

public protocol EditableView: JoliView & Identifiable {
    associatedtype SheetContent: View
    
    
    var viewModeGlobal: ViewMode { get }
    var editMode: EditingState { get nonmutating set }
    var editButtonPlacement: Alignment { get nonmutating set}
    var editButtonOffset: CGSize { get nonmutating set}
    
    var editModeBinding: Binding<EditingState> { get }
    var isEditing: Bool { get }
    var id: String { get nonmutating set }
    
    func editSheet() -> SheetContent
    
}

public extension EditableView {
    
    var isEditing: Bool {
        editMode == .active
    }
    
    var body: some View {
        
        return self.contentView
            //.environment(\.currentEditTarget, isEditing ? .active(id) : nil)
            .overlay(alignment: editButtonPlacement){
                if viewModeGlobal == .editing {
                    PencilButton(editMode: editModeBinding, parentViewId: id, sheetContent: self.editSheet)
                        .offset(editButtonOffset)
                        .shadow(radius: 1)
                        .opacity(editMode.opacity)
                }
            }
            .onReceive(appCoordinator.connectionStateSubject) { state in
                self.onConnectionStateChange(state.state)
            }
            .onChange(of: self.appCoordinator.currentEditTarget) { currentTarget in
                    //print("[\(Self.self)] currentEditTarget: \(String(describing: currentTarget))")
                
                guard case let .active(uid) = currentTarget else {
                    editMode = .inactive
                    return
                }
                
                if uid != id {
                    editMode = .transient
                }
            }
            .onChange(of: self.editMode) { newValue in
                    //print("[\(Self.self)] editMode: \(String(describing: newValue)) - \(String(describing: self.appCoordinator.currentEditTarget)) (\(id))")
                
                if newValue == .active {
                    self.appCoordinator.currentEditTarget = .active(id)
                } else if case let .active(uid) = self.appCoordinator.currentEditTarget, uid == id {
                    self.appCoordinator.currentEditTarget = nil
                }
                
            }
        
    }
    
}

public protocol EditContainerView: JoliView {
    
    var viewMode: ViewMode { get nonmutating set }
    var modals: [EditSheetWrapper] { get nonmutating set }
    var modalViewOffset: CGFloat { get nonmutating set }
    
}

extension EditContainerView {
    
    var body: some View {
        self.contentView
            .environment(\.viewModeGlobal, viewMode)
            .overlay() {
                GeometryReader() { proxy in
                    HStack(){
                        Spacer()
                        Button(){
                            viewMode = viewMode == .editing ? .preview : .editing
                        } label: {
                            Label("\(viewMode == .editing ? "Preview" : "Edit")", systemImage: "\(viewMode == .editing ? "eye" : "pencil")")
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                }
            }
            .onReceive(appCoordinator.connectionStateSubject) { state in
                self.onConnectionStateChange(state.state)
            }
            .onPreferenceChange(EditViewsKey.self) { views in
                self.modals = views
            }
            .overlay(alignment: .init(horizontal: .center, vertical: .bottom)) {
                
                GeometryReader() { proxy in
                    ZStack(){
                        
                        ForEach(self.modals) { modalView in
                            if modalView.active {
                                
                                VStack(spacing: .zero){
                                    Spacer()
                                    
                                    Divider()
                                        .offset(y: modalViewOffset)
                                    
                                    ZStack(alignment: .center){
                                        modalView
                                    }
                                    .frame(minHeight: screenHeight * 0.3)
                                    .frame(width: proxy.frame(in: .global).width)
                                    .background(Color.systemGroupedBackground)
                                    .offset(y: modalViewOffset)
                                    //.offset(y: modalView.active ? 0 : screenHeight * 0.3)
                                }
                                .background(
                                    Color.black.opacity(0.2)
                                        .onTapGesture(){
                                            
                                            withAnimation(){
                                                modalViewOffset = 0
                                                for modal in self.modals {
                                                    guard modal.active else { continue }
                                                    modal.onDismiss()
                                                }
                                            }
                                        }
                                )
                                .onAppear() {
                                    withAnimation(){
                                        modalViewOffset = 0
                                    }
                                }
                                .onDisappear() {
                                    withAnimation(){
                                        modalViewOffset = screenHeight * 0.3
                                    }
                                }
                            }
                            
                        }
                        
                    }
                    .frame(width: proxy.frame(in: .global).width, height: proxy.frame(in: .global).height)
                }
                .edgesIgnoringSafeArea(.top)
                
            }
    }
    
}


struct PencilButton<SheetContent: View>: View {
    
    @Binding var editMode: EditingState
    @State var parentViewId: String
    var sheetContent: () -> SheetContent
    
    var isEditing: Bool {
        editMode == .active
    }
    
    @Namespace var nspace
    @State private var sourceType: UIImagePickerController.SourceType? = nil
    @State var isSheetPresented: Bool = false
    
    private let height = 32.0
    
    var body: some View {
        
        let button = Button(){
            editMode.toggle()
        } label: {
            VStack(){
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .foregroundStyle(isEditing ? Color.green : Color.black)
            }
            .frame(width: height, height: height)
        }
            .disabled(editMode == .transient)
        
        Group(){
            if editMode == .active {
                button
                    .preference(key: EditViewsKey.self, value: [
                        .init(id: parentViewId, active: self.editMode == .active){
                            self.editMode = .inactive
                        } content: {
                            AnyView(self.sheetContent())
                        }
                    ])
            } else {
                button
            }
        }
        .background(Color.white)
        .clipShape(Circle())
        .animation(.smooth, value: editMode)
        .onChange(of: editMode) { val in
            
            guard val == .active else {
                return
            }
            
            print("[\(Self.self)] edit mode changed: \(val) - \(isSheetPresented)")
        }
    }
    
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
