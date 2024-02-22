//
//  RoundedImageView.swift
//  JsonUI
//
//  Created by Anthony Chinwo on 21/02/2024.
//  Copyright © 2024 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import SharedUI

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
