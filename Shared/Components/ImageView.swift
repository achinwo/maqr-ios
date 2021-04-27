//
//  ImageView.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI

public struct ImageView<Content: View>: View {
    
    public typealias Callback = (UIImage?, Error?) -> Void
    
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
            .cancel(Text("Cancel"))
        ]
        return buttons
    }
    
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
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
    
    init(url: String, onSelected: Callback? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        //self.placeholderImage = placeholderImage
        self.init(url: URL(string: url), onLoaded: onLoaded, content: content)
    }
    
    init(url: URL? = nil, onSelected: Callback? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        //self.placeholderImage = placeholderImage
        self.onLoaded = onLoaded
        self.onSelected = onSelected
        self.placeholderContent = content()
        self._imageURL = State(initialValue: url)
    }
    
//    public init(url: URL, isCircular: Bool = true, callback: ((UIImage?, Error?) -> Void)? = nil){
//        self._uiImage = State(initialValue: nil)
//        self.isCircular = isCircular
//        self.callback = callback
//    }
    
    public var body: some View {
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
    
    var imageView: some View {
        
        let onSelectedCb: (UIImage?, Error?) -> Void = { (img: UIImage?, error: Error?) in
            self.imageChooserPresented.toggle()
            
            if let error = error {
                self.onSelected?(nil, error)
                return
            }
            
            guard let image = img else {
                self.onSelected?(nil, error)
                return
            }
            
            self.uiImage = image
            self.onSelected?(image, error)
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
                self.onLoaded?(image, error)
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
                } content: {
                    #if os(macOS)
                    Text("Unsupported!")
                    #else
                    
                    if sourceType == .camera {
                        CameraImagePicker(callback: onSelectedCb)
                            .edgesIgnoringSafeArea(.bottom)
                    } else {
                        SingleImagePicker(callback: onSelectedCb)
                            .edgesIgnoringSafeArea(.bottom)
                    }
                    #endif
                }
                .if(!isMacOs){ view in
                    #if os(macOS)
                    view
                    #else
                    view.actionSheet(isPresented: self.$sheetPresented) {
                        ActionSheet(title: Text(self.title),
                                    message: Text(self.message),
                                    buttons: buttons)
                    }
                    #endif
                }
                
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
