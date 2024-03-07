//
//  ContentView.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 16/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

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
    @State var modalViewOffset: CGFloat = 0
    @State var modals: [EditSheetWrapper] = []
    
    @State var availableFontNames: Set<String> = []
    
    var columns: [GridItem] {
        [
            GridItem(.fixed(screenWidth / 2.5), spacing: 10),
            GridItem(.fixed(screenWidth / 2.5), spacing: 10)
        ]
    }
    
    @State var title: String = "Our Story"
    @State var systemImage: String = "book.fill"
    
    var contentView: some View {
        NavigationView(){
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
                                self.uiImage = img
                            }
                            .edgesIgnoringSafeArea(.bottom)
                        } else {
                            SingleImagePicker() {(img: UIImage?, assetName: String?, error: Error?) in
                                self.sourceType = nil
                                print("image: \(String(describing: img)), assestName: \(String(describing: assetName)), error: \(String(describing: error))")
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
                                .applyAttribute(TextAttribute([
                                    .fontName: "Cedarville-Cursive",
                                    .fontSize: Sizing.largeTitle]))
                                //.font(fontLoaded == nil ? .title.weight(.light) : .custom(self.fontLoaded!.postScriptName! as String, size: Sizing.largeTitle))
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
                        
                        self.bodyGridView
                        .padding(.top)
                    }
                    .padding(.bottom, 50)
                }
                
                
            }
            .edgesIgnoringSafeArea(.vertical)
            
        }
        .onChange(of: appCoordinator.keyboardHeight) { keyboardHeight in
            self.keyboardHeight = keyboardHeight
        }
        .background(Color.teal.opacity(0.1))
    }
    
    var bodyGridView: some View {
        //
        LazyVGrid(columns: columns, spacing: 15) {
            
            let functionViews: [any WeddingItemView] = [
                
                //WeddingFunctionView(title: "Our Story", systemImage: "book.fill"),
                WeddingFunctionView(title: "Seating", systemImage: "chair.lounge"),
                WeddingFunctionView(title: "Order of Events", systemImage: "list.bullet"),
                WeddingFunctionView(title: "Gift", systemImage: "gift.fill"),
                WeddingFunctionView(title: "Food Menu", systemImage: "fork.knife.circle.fill"),
                WeddingFunctionView(title: "Photos", systemImage: "photo.on.rectangle.angled"),
                WeddingFunctionView(title: "Thanks & Credits", systemImage: "trophy.fill"),
            ]
            
            WeddingStoryView(title: $title, systemImage: $systemImage)
            
//            EditableContentView(editPlacement: .topTrailing){
//                Button() {
//                    WeddingStoryView(title: $title, systemImage: $systemImage)
//                        //.navigationTitle(storyView.title)
//                } label: {
//                    WeddingStoryView(title: $title, systemImage: $systemImage).navButton
//                        .frame(width: screenWidth / 4, height: screenWidth / 6)
//                        .padding()
//                }
//                .buttonStyle(.bordered)
//                
//            } sheetContent: {
//                WeddingStoryView(title: $title, systemImage: $systemImage).editSheet()
//            }
            
            ForEach(functionViews, id: \.id) { fnView in
                
                EditableContentView(editPlacement: .topTrailing){
                    NavigationLink() {
                        AnyView(fnView)
                            .navigationTitle(fnView.title)
                    } label: {
                        AnyView(fnView.navButton)
                            .frame(width: screenWidth / 4, height: screenWidth / 6)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    
                } sheetContent: {
                    AnyView(fnView.editSheet())
                }
                
            }
        }
    }
    
}



public struct EditSheetWrapper: View, Identifiable, Equatable {
    
    public let id: String
    let active: Bool
    let onDismiss: () -> Void
    let content: () -> AnyView
    
    public static func == (lhs: EditSheetWrapper, rhs: EditSheetWrapper) -> Bool {
        lhs.id == rhs.id && lhs.active == rhs.active
    }
    
    public var body: some View {
        content()
    }
    
}

public struct EditViewsKey: PreferenceKey {
    
    public static func reduce(value: inout [EditSheetWrapper], nextValue: () -> [EditSheetWrapper]) {
        value = value + nextValue()
    }
    
    public static var defaultValue: [EditSheetWrapper] = []
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
}
