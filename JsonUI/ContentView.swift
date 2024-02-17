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


extension EditingState {
    
    mutating func toggle() {
        self = self == .active ? .inactive : .active
    }
    
    var opacity: CGFloat {
        switch self {
            case .active:
                return 1
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


struct TestExperience: Experience {
    
    
    @State var dataModel: ExperienceData? = nil
    
    @State var editMode: EditingState = .inactive
    
    
    static var basePath: String = "test-ui"
    
    init(_ data: ExperienceData?) {
        
    }
    
}

protocol EditableView: JoliView & Identifiable {
    
    var editMode: EditingState { get nonmutating set }
    var editButtonPlacement: Alignment { get nonmutating set}
    var editButtonOffset: CGSize { get nonmutating set}
    
    var editModeBinding: Binding<EditingState> { get }
    var isEditing: Bool { get }
    var id: UUID { get nonmutating set }
    
    func onValue(image: UIImage?)
    
}



extension EditableView {
    
    var isEditing: Bool {
        editMode == .active
    }
    
    func onValue(image: UIImage?) {
        print("Wrong 'onValue'!! \(String(describing: image))")
    }
    
    var body: some View {
        
        return self.contentView
            //.environment(\.currentEditTarget, isEditing ? .active(id) : nil)
            .overlay(alignment: editButtonPlacement){
                PencilButton(editMode: editModeBinding, onValue: self.onValue(image:))
                    .offset(editButtonOffset)
                    .shadow(radius: 1)
                    .opacity(editMode.opacity)
                    .zIndex(999)
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

extension UIImagePickerController.SourceType: Identifiable {
    
    public var id: Int {
        self.rawValue
    }
    
}

struct PencilButton: View {
    
    @Binding var editMode: EditingState
    var onValue: (_ image: UIImage?) -> Void
    
    var isEditing: Bool {
        editMode == .active
    }
    
    @Namespace var nspace
    @State private var sourceType: UIImagePickerController.SourceType? = nil
    
    var body: some View {
        let height = 32.0
        
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
            if isEditing {
                HStack(){
                    
                    Button(){
                        sourceType = .camera
                    } label: {
                        Image(systemName: "camera.viewfinder")
                        .frame(width: height, height: height)
                    }
                    .padding(.horizontal)
                    
                    Button(){
                        sourceType = .photoLibrary
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                        .frame(width: height, height: height)
                    }.padding(.vertical)
                    
                    button.padding(.horizontal)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 10)))
                .matchedGeometryEffect(id: "group1", in: nspace, properties: .frame, isSource: false)
            } else {
                button
                    .background(Color.white)
                    .clipShape(Circle())
                    .matchedGeometryEffect(id: "group1", in: nspace, properties: .frame, isSource: false)
            }
        }
        .animation(.smooth, value: editMode)
        .sheet(item: $sourceType) { item in
            if item == .camera{
                CameraImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                    self.sourceType = nil
                    self.onValue(img)
                }
                    .edgesIgnoringSafeArea(.bottom)
            } else {
                SingleImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                    self.sourceType = nil
                    print("image: \(String(describing: img)), assestName: \(String(describing: assetName)), error: \(String(describing: error))")
                    self.onValue(img)
                }
                    .edgesIgnoringSafeArea(.bottom)
            }
        }
        
    }
    
}

struct RoundedImageView: EditableView {
    
    @State var id: UUID = UUID()
    
    @Environment(\.currentEditTarget) var currentEditTarget: EditTarget?
    @State var editMode: EditingState = .inactive
    @State var editButtonOffset: CGSize = .init(width: 0, height: 50)
    
    @State var editButtonPlacement: Alignment = .topTrailing
    
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @EnvironmentObject var appCoordinator: SharedUI.AppCoordinator
    
    @State var imageUrl = URL(string: "https://images.unsplash.com/photo-1521510186458-bbbda7aef46b?q=80&w=480&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")
    @State var uiImage: UIImage? = nil
    
    func onValue(image: UIImage?){
        self.uiImage = image
        print("[\(Self.self)] Setting image: \(String(describing: image))")
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

struct EditableContentView<Content: View>: EditableView {
    
    @State var id: UUID = UUID()
    
    @State var editButtonOffset: CGSize = .zero
    
    @Environment(\.currentEditTarget) var currentEditTarget: EditTarget?
    @State var editMode: EditingState = .inactive
    
    @State var editButtonPlacement: Alignment
    var callback: ((_ img: UIImage?) -> Void)?
    
    var editModeBinding: Binding<EditingState> { $editMode }
    
    @EnvironmentObject var appCoordinator: SharedUI.AppCoordinator
    
    private let content: () -> Content
    
    init(editPlacement: Alignment = .topTrailing, editOffset: CGSize = .zero, @ViewBuilder content: @escaping () -> Content, onValue: ((_ img: UIImage?) -> Void)? = nil) {
        self._editButtonPlacement = State(initialValue: editPlacement)
        self.content = content
        self._editButtonOffset = State(initialValue: editOffset)
        self.callback = onValue
    }
    
    func onValue(image: UIImage?) {
        self.callback?(image)
    }
    
    var contentView: some View {
        self.content()
    }
    
}

struct ContentView: EditableView {
    
    @State var id: UUID = UUID()
    
    var editModeBinding: Binding<EditingState> {
        $editMode
    }
    
    @Environment(\.currentEditTarget) var currentEditTarget: EditTarget?
    
    @State var editMode: EditingState = .inactive
    @State var editButtonOffset: CGSize = .init(width: 0, height: 0)
    
    @State var editButtonPlacement: Alignment = .init(horizontal: .center, vertical: .bottom)
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @State var imageUrl = URL(string: "https://images.unsplash.com/photo-1707922172778-c59c96446d76?q=80&w=600&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")
    @State var uiImage: UIImage? = nil
    
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
            } onValue: { image in
                self.uiImage = image
            }
            
            ScrollView(.vertical){
                
                VStack {
                    EditableContentView(editPlacement: .topTrailing, editOffset: .init(width: 10, height: 0)){
                        Text("Esther & Jide")
                            .font(.title.weight(.light))
                            .padding()
                    }
                    .padding(.top, 60)
                    
                    EditableContentView(editPlacement: .topTrailing, editOffset: .init(width: 10, height: -5)){
                        Text("Hello & Welcome!")
                            .font(.subheadline.weight(.light))
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
                            }
                            
                        }
                        
                    }
                    .padding(.top)
                }
                .padding(.bottom, 50)
            }
        }
        .edgesIgnoringSafeArea(.vertical)
        .background(Color.teal.opacity(0.1))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        //.edgesIgnoringSafeArea(.vertical)
}
