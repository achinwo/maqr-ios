//
//  ContentView.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 16/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Starscream
import SharedUI
import SheeKit

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

protocol EditableView: JoliView & Identifiable {
    associatedtype SheetContent: View
    
    
    var viewModeGlobal: ViewMode { get }
    var editMode: EditingState { get nonmutating set }
    var editButtonPlacement: Alignment { get nonmutating set}
    var editButtonOffset: CGSize { get nonmutating set}
    
    var editModeBinding: Binding<EditingState> { get }
    var isEditing: Bool { get }
    var id: UUID { get nonmutating set }
    
    func editSheet() -> SheetContent
    
}

extension EditableView {
    
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


protocol EditContainerView: JoliView {
    
    var viewMode: ViewMode { get nonmutating set }
    var modals: [EditSheetWrapper] { get nonmutating set }
    
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
                        
//                    }
//                    .frame(width: proxy.frame(in: .global).width, height: proxy.frame(in: .global).height)
//                    .background(Color.green.opacity(0.3))
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
                            
                                //if modalView.active {
                            
                            VStack(spacing: .zero){
                                Spacer()
                                    .onTapGesture(){
                                        print("Tapped Spacer!")
                                    }
                                
                                Divider()
                                
                                ZStack(alignment: .center){
                                    modalView
                                }
                                .frame(minHeight: screenHeight * 0.3)
                                .frame(width: proxy.frame(in: .global).width)
                                .background(Color.systemGroupedBackground)
                                    //.padding(.bottom, appCoordinator.keyboardHeight)
                                    //.background(BlurView(.systemUltraThinMaterialLight))
                                
                            }
                            .background(
                                Color.systemGroupedBackground.opacity(0.2)
                                    .onTapGesture(){
                                        print("Tapped Background!")
                                        
                                        withAnimation(){
                                            modalView.onDismiss()
                                        }
                                    }
                            )
                            
                        }
                    }
                    .frame(width: proxy.frame(in: .global).width, height: proxy.frame(in: .global).height)
                }
                .edgesIgnoringSafeArea(.top)
                
            }
    }
    
}

extension UIImagePickerController.SourceType: Identifiable {
    
    public var id: Int {
        self.rawValue
    }
    
}

struct PencilButton<SheetContent: View>: View {
    
    @Binding var editMode: EditingState
    @State var parentViewId: UUID
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
                isSheetPresented = false
                return
            }
            
            isSheetPresented = true
            print("[\(Self.self)] edit mode changed: \(val) - \(isSheetPresented)")
        }
    }
    
}

struct RoundedImageView: EditableView {
    
    @State var id: UUID = UUID()
    
    @Environment(\.viewModeGlobal) var viewModeGlobal: ViewMode
    @State var editMode: EditingState = .inactive
    @State var editButtonOffset: CGSize = .init(width: 0, height: 50)
    
    @State var editButtonPlacement: Alignment = .topTrailing
    
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @EnvironmentObject var appCoordinator: SharedUI.AppCoordinator
    
    @State var imageUrl = URL(string: "https://images.unsplash.com/photo-1521510186458-bbbda7aef46b?q=80&w=480&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")
    @State var uiImage: UIImage? = nil
    @State var sourceType: UIImagePickerController.SourceType? = nil
    
    @ViewBuilder
    func editSheet() -> some View {
        HStack(){
            Button("Camera", systemImage: "camera.viewfinder"){
                sourceType = .camera
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Button("Gallery", systemImage: "photo.on.rectangle.angled"){
                sourceType = .photoLibrary
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(item: $sourceType) { item in
            if item == .camera {
                CameraImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                    self.sourceType = nil
                    self.uiImage = img
                }
                .edgesIgnoringSafeArea(.bottom)
            } else {
                SingleImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                    self.sourceType = nil
                    self.uiImage = img
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
    }
    
    var contentView: some View {
        Group(){
            if let image = self.uiImage {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AsyncImage(url: imageUrl) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 4))
        .offset(editButtonOffset)
    }
}

struct EditableContentView<Content: View, SheetContent: View>: EditableView {
    
    @State var id: UUID = UUID()
    
    @State var editButtonOffset: CGSize = .zero
    
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

struct ContentView: EditContainerView {
    
    @State var viewMode: ViewMode = .editing
    @Environment(\.viewModeGlobal) var viewModeGlobal: ViewMode
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @State var imageUrl = URL(string: "https://images.unsplash.com/photo-1707922172778-c59c96446d76?q=80&w=600&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")
    @State var uiImage: UIImage? = nil
    
    @State var weddingTitle = "Esther & Jide"
    @State var weddingSubtitle = "Hello & Welcome!"
    
    @State private var sourceType: UIImagePickerController.SourceType? = nil
    
    @State var keyboardHeight: CGFloat = 0
    
    @State var modals: [EditSheetWrapper] = []
    
    var contentView: some View {
        
        VStack(spacing: .zero) {
            
            EditableContentView(editPlacement: .bottomTrailing, editOffset: .init(width: 0, height: -5)){
                Group(){
                    if let image = uiImage {
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        AsyncImage(url: imageUrl) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
                .frame(maxHeight: screenHeight * 0.25)
                .clipped()
                .overlay(alignment: .init(horizontal: .center, vertical: .bottom)) {
                    RoundedImageView()
                }
            } sheetContent: {
                HStack(){
                    Button("Camera", systemImage: "camera.viewfinder"){
                        print("open camera!")
                        sourceType = .camera
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                    Button("Gallery", systemImage: "photo.on.rectangle.angled"){
                        print("open Gallery!")
                        sourceType = .photoLibrary
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .sheet(item: $sourceType) { item in
                    if item == .camera {
                        CameraImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                            self.sourceType = nil
                            print("CAM| image: \(String(describing: img)), assestName: \(String(describing: assetName)), error: \(String(describing: error))")
                                //self.onValue(img)
                            self.uiImage = img
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    } else {
                        SingleImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                            self.sourceType = nil
                            print("image: \(String(describing: img)), assestName: \(String(describing: assetName)), error: \(String(describing: error))")
                                //self.onValue(img)
                            self.uiImage = img
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    }
                }
            }
            
            ScrollView(.vertical){
                
                VStack {
                    EditableContentView(editPlacement: .topTrailing, editOffset: .init(width: 10, height: 0)){
                        Text(self.weddingTitle)
                            .font(.title.weight(.light))
                            .padding()
                    } sheetContent: {
                        TextField("Title", text: self.$weddingTitle).textFieldStyle(.roundedBorder).padding()
                    }
                    .padding(.top, 60)
                    
                    EditableContentView(editPlacement: .topTrailing, editOffset: .init(width: 10, height: -5)){
                        Text(self.weddingSubtitle)
                            .font(.subheadline.weight(.light))
                    } sheetContent: {
                        TextField("Subtitle", text: self.$weddingSubtitle).textFieldStyle(.roundedBorder).padding()
                    }
                    
                    let pairs: [(imageName: String, title: String)] = [
                        ("book.fill", "Our Story"),
                        ("chair.lounge", "Seating"),
                        ("list.bullet", "Order of Events"),
                        ("gift.fill", "Gift"),
                        ("menucard.fill", "Food Menu"),
                        ("photo.on.rectangle.angled", "Photos"),
                        ("trophy.fill", "Thanks & Credits"),
                    ]
                    
                    let columns = [
                        GridItem(.fixed(screenWidth / 2.5), spacing: 10),
                        GridItem(.fixed(screenWidth / 2.5), spacing: 10)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(pairs, id: \.title) { pair in
                            EditableContentView(editPlacement: .topTrailing){
                                Button(){
                                        //self.editMode = editMode == .active ? .inactive : .active
                                } label: {
                                    
                                    VStack(){
                                        Image(systemName: pair.imageName)
                                            .renderingMode(.original)
                                            .font(.title)
                                        Text(pair.title)
                                            .font(.subheadline)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.center)
                                            .fixedSize()
                                            .padding(.top)
                                    }
                                    .frame(width: screenWidth / 4, height: screenWidth / 6)
                                    .padding()
                                    
                                }
                                .buttonStyle(.bordered)
                            } sheetContent: {
                                Toggle("Active", isOn: .constant(true))
                            }
                            
                        }
                        
                    }
                    .padding(.top)
                }
                .padding(.bottom, 50)
            }
            
        }
        .edgesIgnoringSafeArea(.vertical)
        .onChange(of: appCoordinator.keyboardHeight) { keyboardHeight in
            print("Keyboard height: \(keyboardHeight)")
            self.keyboardHeight = keyboardHeight
        }
        .background(Color.teal.opacity(0.1))
        
    }
}

struct EditSheetWrapper: View, Identifiable, Equatable {
    
    let id: UUID
    let active: Bool
    let onDismiss: () -> Void
    let content: () -> AnyView
    
    static func == (lhs: EditSheetWrapper, rhs: EditSheetWrapper) -> Bool {
        lhs.id == rhs.id //&& lhs.active == rhs.active
    }
    
    var body: some View {
        content()
    }
    
}

struct EditViewsKey: PreferenceKey {
    
    static func reduce(value: inout [EditSheetWrapper], nextValue: () -> [EditSheetWrapper]) {
        value = value + nextValue()
    }
    
    static var defaultValue: [EditSheetWrapper] = []
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
