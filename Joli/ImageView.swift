//
//  ImageView.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI

struct ImageView: View {
    
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
    
    @State var imageChooserPresented = false
    @State var sheetPresented = false
    
    @State var isCircular = true
    @State var title = "Change Image"
    @State var message = "Grab photo from library or camera"
    @State var uiImage: UIImage
    
    @State var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var callback: ((UIImage?, Error?) -> Void)? = nil
    
    init(uiImage: UIImage, isCircular: Bool = true, callback: ((UIImage?, Error?) -> Void)? = nil){
        self._uiImage = State(initialValue: uiImage)
        self.isCircular = isCircular
        self.callback = callback
    }
    
    var body: some View {
        return VStack(alignment: .center) {
                    self.imageView
            }.overlay(
                Group() {
                    if self.callback != nil {
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
        
        let callback: (UIImage?, Error?) -> Void = { (img: UIImage?, error: Error?) in
            self.imageChooserPresented.toggle()
            
            if let error = error {
                self.callback?(nil, error)
                return
            }
            
            guard let image = img else {
                self.callback?(nil, error)
                return
            }
            
            self.uiImage = image
            self.callback?(image, error)
        }
        
        let img = Image(uiImage: uiImage)
            .resizable()
            .renderingMode(.original)
            //.padding()
            .aspectRatio(contentMode: .fit)
            .background(
                EmptyView()
                    .sheet(isPresented: self.$imageChooserPresented) {
                        print("thing is dismissed!")
                    } content: {
                        if sourceType == .camera {
                            CameraImagePicker(callback: callback).edgesIgnoringSafeArea(.bottom)
                        } else {
                            SingleImagePicker(callback: callback).edgesIgnoringSafeArea(.bottom)
                        }
                    }
                    .actionSheet(isPresented: self.$sheetPresented) {
                        ActionSheet(title: Text(self.title),
                                    message: Text(self.message),
                                    buttons: buttons)
                    }
            )
        
        return Group(){
            if self.isCircular {
                img.clipShape(Circle())
            } else {
                img.clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
