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
import JoliApi
import JoliCore

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
    associatedtype SheetContent: View = Never
    
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
    var availableFontNames: Set<String> { get nonmutating set }
    
}

extension EditContainerView {
    
    var body: some View {
        self.contentView
            .environment(\.viewModeGlobal, viewMode)
            .environment(\.availableFontNames, availableFontNames)
            .overlay() {
                GeometryReader() { proxy in
                    HStack(){
                        Spacer()
                        Button(){
//                            let generator = UINotificationFeedbackGenerator()
//                            generator.notificationOccurred(.warning)
                            
                            self.appCoordinator.withImpact(.light) {
                                viewMode = viewMode == .editing ? .preview : .editing
                            }
                            
                        } label: {
                            Label("\(viewMode == .editing ? "Preview" : "Edit")", systemImage: viewMode == .editing ? "eye" : "pencil")
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
            .task(priority: .userInitiated) {
                let urls = [
                    URL(staticString: "https://fonts.gstatic.com/s/cedarvillecursive/v17/yYL00g_a2veiudhUmxjo5VKkoqA-B_neJbBxw8BeTg.ttf"),
                    URL(staticString: "https://fonts.gstatic.com/s/montserrat/v26/JTUHjIg1_i6t8kCHKm4532VJOt5-QNFgpCtr6Ew-Y3tcoqK5.ttf"),
                    URL(staticString: "https://fonts.gstatic.com/s/outfit/v11/QGYyz_MVcBeNP4NjuGObqx1XmO1I4TC1C4G-EiAou6Y.ttf"),
                    URL(staticString: "https://fonts.gstatic.com/s/dancingscript/v25/If2cXTr6YS-zF4S-kcSWSVi_sxjsohD9F50Ruu7BMSoHTeB9ptDqpw.ttf"),
                ]
                
                for url in urls {
                    let fontLoaded = await FontLoader.remoteFont(url: url)
                    
                    guard let postScriptName = fontLoaded?.postScriptName as? String else {
                        print("Unable to load font")
                        continue
                    }
                    
                    self.availableFontNames =  availableFontNames.union([postScriptName])
                    print("Loaded the font: \(postScriptName) - \(availableFontNames)")
                }
                
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
                                    .frame(height: screenHeight * 0.36)
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
    
    private let height = 32.0
    
    var body: some View {
        
        let button = Button(){
            guard editMode != .transient else {
                print("transient: \(parentViewId)")
                return
            }
            print("toggling: \(parentViewId)")
            editMode.toggle()
        } label: {
            VStack(){
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .foregroundStyle(isEditing ? Color.green : Color.black)
            }
            .frame(width: height, height: height)
        }
            //.disabled(editMode == .transient)
        
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
            
            print("[\(Self.self)] edit mode changed: \(val)")
        }
    }
    
}

struct EditableContentView<Content: View, SheetContent: View>: EditableView {
    
    @State var id: String = UUID().uuidString
    
    @State var editButtonOffset: CGSize = .zero
    @State var attribute: TextAttribute = .empty
    @Environment(\.viewModeGlobal) var viewModeGlobal: ViewMode
    @State var editMode: EditingState = .inactive
    
    @State var editButtonPlacement: Alignment
    var callback: ((_ img: UIImage?) -> Void)?
    
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @EnvironmentObject var appCoordinator: SharedUI.AppCoordinator
    
    private let content: () -> Content
    private let sheetContent: () -> SheetContent
    
    init(editPlacement: Alignment = .topTrailing, editOffset: CGSize = .zero, @ViewBuilder content: @escaping () -> Content, @ViewBuilder sheetContent: @escaping () -> SheetContent) {
        self._editButtonPlacement = State(initialValue: editPlacement)
        self.content = content
        self._editButtonOffset = State(initialValue: editOffset)
        self.sheetContent = sheetContent
    }
    
    var contentView: some View {
        self.content()
    }
    
    func editSheet() -> SheetContent {
        sheetContent()
    }
}


#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
