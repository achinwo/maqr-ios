//
//  ImageView.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI

public struct ImageView<Content: View>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public typealias Callback = (UIImage?, String?, Error?) -> Void
    
    
    @State var imgUrlString: String = .empty
    
    #if !os(macOS)
    var buttons: [ActionSheet.Button] {
        let buttons: [ActionSheet.Button] = [
            .default(Text("🌄 Photo Library")) {
                self.sourceType = .photoLibrary
                self.imageChooserPresented = true
                print("[ImageView] sourceType: \(self.sourceType)")
            },
            .default(Text("📷 Camera")) {
                self.sourceType = .camera
                self.imageChooserPresented = true
                print("[ImageView] sourceType: \(self.sourceType)")
            },
            .default(Text("🔗 From URL")) {
                self.isLocalSheetPresenting = true
                self.imageChooserPresented = true
                print("[ImageView] fetch from link!")
            },
            .cancel(Text("Cancel"))
        ]
        return buttons
    }
    
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isLocalSheetPresenting = false
    
    #endif
    
    @State var imageChooserPresented = false
    @State var sheetPresented = false
    
    @State var isCircular = true
    @State var title = "Change Image"
    @State var message = "Grab photo from library or camera"
    
    @State var uiImage: UIImage? = nil
    @State public var imageURL: URL? = nil
    public var placeholderContent: Content? = nil
    
    
    var onSelected: Callback? = nil
    var onLoaded: Callback? = nil
    
    public init(urlString: String?, isCircular: Bool = true, onSelected: Callback? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        
        guard let string = urlString, let url = URL(string: string) else {
            self.init(url: nil, isCircular: isCircular, onSelected: onSelected, onLoaded: onLoaded, content: content)
            return
        }
        
        self.init(url: url, isCircular: isCircular, onSelected: onSelected, onLoaded: onLoaded, content: content)
    }
    
    public init(url: String, isCircular: Bool = true, onSelected: Callback? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        //self.placeholderImage = placeholderImage
        self.init(url: URL(string: url), isCircular: isCircular, onSelected: onSelected, onLoaded: onLoaded, content: content)
    }
    
    public init(url: URL? = nil, isCircular: Bool = true, onSelected: Callback? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        //self.placeholderImage = placeholderImage
        self.onLoaded = onLoaded
        self.onSelected = onSelected
        self.placeholderContent = content()
        self._imageURL = State(initialValue: url)
        self._isCircular = State(initialValue: isCircular)
    }
    
//    public init(url: URL, isCircular: Bool = true, callback: ((UIImage?, Error?) -> Void)? = nil){
//        self._uiImage = State(initialValue: nil)
//        self.isCircular = isCircular
//        self.callback = callback
//    }
    
    public var contentView: some View {
        return VStack(alignment: .center) {
                    self.imageView
            }.overlay(
                Group() {
                    if self.onSelected != nil {
                        VStack() {
                            Spacer()
                            HStack() {
                                Spacer()
                                Image(systemName: "camera")
                                    .padding(.all, 20)
                                    //.font(.system(size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize, weight: .ultraLight))
                                    .font(Font.largeTitle.weight(.ultraLight))
                                    .background(Color.gray.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        self.sheetPresented.toggle()
                                    }
                            }
                        }
                        .padding([.trailing, .bottom], 20)
                    } else {
                        EmptyView()
                    }
                }
            )
        
    }
    
    @State var imageFromWeb: UIImage? = nil
    
    var imageView: some View {
        
        let onSelectedCb: (UIImage?, String?, Error?) -> Void = { (img: UIImage?, assetName: String?, error: Error?) in
            self.imageChooserPresented.toggle()
            
            if let error = error {
                self.onSelected?(nil, nil, error)
                return
            }
            
            guard let image = img else {
                self.onSelected?(nil, nil, error)
                return
            }
            
            self.uiImage = image
            self.onSelected?(image, assetName, error)
        }
        
        let img: AnyView
        
        if let uiImage = uiImage {
            img = AnyView(
                Image(platformImage: uiImage)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
            )
        } else {
            let network = NetworkImage(url: imageURL) { (image, error) in
                uiImage = image
                self.onLoaded?(image, imageURL?.lastPathComponent, error)
            } content: {
                return placeholderContent
            }
            img = AnyView(network)
        }
        
        return Group(){
            if self.isCircular {
                img.clipShape(Circle())
            } else {
                img.clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .background(
            EmptyView()
                .sheet(isPresented: self.$imageChooserPresented) {
                    print("thing is dismissed!")
                    self.isLocalSheetPresenting = false
                } content: {
                    #if os(macOS)
                    Text("Unsupported!")
                    #else
                    if isLocalSheetPresenting {
                        NavigationView(){
                            VStack(){
                                
                                //Text("Enter Image URL").font(.title).padding()
                                let url = URL(string: imgUrlString)
                                
                                if let url = url, !imgUrlString.isEmpty {
                                    NetworkImage(url: url) { img, error in
                                        self.imageFromWeb = img
                                    } content: {
                                        ProgressView()
                                    }
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: screenWidth - 100, maxHeight: screenHeight / 2)
                                }
                                TextField("Image URL", text: $imgUrlString)
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondaryLabel, lineWidth: 1)
                                            .allowsHitTesting(false)
                                    )
                                Button() {
                                    onSelectedCb(self.imageFromWeb, url?.lastPathComponent, nil)
                                } label: {
                                    Label("Use Image", systemImage: "hand.thumbsup")
                                }
                                //.buttonStyle()
                                .disabled(imageFromWeb == nil)
                                .padding()
                                Spacer()
                            }
                            .padding()
                            .navigationTitle("Fetch Image from URL")
                            .navigationBarTitleDisplayMode(.large)
                            .navigationViewStyle(.stack)
                        }
                        .id(imgUrlString)
                    } else if sourceType == .camera {
                        CameraImagePicker(callback: onSelectedCb)
                            .edgesIgnoringSafeArea(.bottom)
                    } else {
                        SingleImagePicker(callback: onSelectedCb)
                            .edgesIgnoringSafeArea(.bottom)
                    }
                    #endif
                }
                #if !os(macOS)
                .actionSheet(isPresented: self.$sheetPresented) {
                    ActionSheet(title: Text(self.title),
                                message: Text(self.message),
                                buttons: buttons)
                }
                #endif
                
        )
    }
}

extension ImageView where Content == Never {
    
    public init(uiImage: UIImage, isCircular: Bool = true, callback: Callback? = nil){
        self._uiImage = State(initialValue: uiImage)
        self.isCircular = isCircular
        self.onSelected = callback
    }
    
}
