//
//  ProfileView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi

import UIKit
import PhotosUI

class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate {
    
    var callback: (UIImage?, Error?) -> Void
    
    init(callback: @escaping (UIImage?, Error?) -> Void) {
        self.callback = callback
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // The client is responsible for presentation and dismissal
        
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else {
            print("image: empty!")
            self.callback(nil, nil)
            return
        }
        
        itemProvider.loadObject(ofClass: UIImage.self) { (image: NSItemProviderReading?, error) in
            self.callback(image as? UIImage, error)
        }
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        self.callback(image, nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        callback(nil, nil)
    }
    
}

protocol ImagePickerRepresentable: UIViewControllerRepresentable {
    associatedtype ImagePickerViewController: UIViewController
    
    var callback: (UIImage?, Error?) -> Void { get set }
    func makeUIViewController(context: UIViewControllerRepresentableContext<Self>) -> ImagePickerViewController
}

extension ImagePickerRepresentable {
    
    func updateUIViewController(_ uiViewController: ImagePickerViewController, context: UIViewControllerRepresentableContext<Self>) {
    }
    
    func makeCoordinator() -> ImagePickerCoordinator {
        return ImagePickerCoordinator(callback: callback)
    }
}

struct SingleImagePicker: ImagePickerRepresentable {
    
    var callback: (UIImage?, Error?) -> Void
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SingleImagePicker>) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        // Only wants images
        configuration.filter = .livePhotos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
}

struct CameraImagePicker: ImagePickerRepresentable {
    
    var callback: (UIImage?, Error?) -> Void
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
}

struct GradientBackgroundStyle: ButtonStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(LinearGradient(gradient: Gradient(colors: [Color("DarkGreen"), Color("LightGreen")]), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(40)
            .padding(.horizontal, 20)
    }
}

struct ProfileEditView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var user: UserRecord
    
    var body: some View {
        return VStack() {
            Text("Hello \(user.name!)")
        }.onTapGesture {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct UserProfileView2: View {
    
    var user: UserRecord
    @State var editProfilePresented = false
    @State var sheetPresented = false
    
    @State var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func aSheet() -> ActionSheet {
        
        let save = ActionSheet.Button.default(Text("Photo Library")) {
            self.sourceType = .photoLibrary
            self.editProfilePresented = true
            print("hit save")
        }
        
        let discard = ActionSheet.Button.default(Text("Camera")) {
            self.sourceType = .camera
            self.editProfilePresented = true
            print("hit discard")
        }
        
        // If the cancel label is omitted, the default "Cancel" text will be shown
        let cancel = ActionSheet.Button.cancel(Text("Abort")) {
            print("hit abort")
        }
        
        let buttons: [ActionSheet.Button] = [save, discard, cancel]
        
        return ActionSheet(title: Text("Do Something"),
                           message: Text("A whole bunch of things"),
                           buttons: buttons)
    }
    
    var body: some View {
        
        let callback: (UIImage?, Error?) -> Void = { (img: UIImage?, error: Error?) in
            self.editProfilePresented.toggle()
            print("image: \(img), error: \(error)")
        }
        
        return VStack(alignment: .center) {
            
            Image(uiImage: UIImage.makeLetterAvatar(withUsername: user.name)!)
                .resizable()
                .renderingMode(.original)
                .frame(width: 250, height: 250)
                .clipShape(Circle())
                .padding()
            
            Text(user.name!).font(.headline)
            Text(user.ranking.description.lowercased())
                .font(.footnote)
                .foregroundColor(.gray)
            
            Button() {
                
            } label: {
                HStack() {
                    Image(systemName: "pencil")
                        .font(.title)
                    Text("Change Photo")
                        .fontWeight(.semibold)
                        .font(.title)
                }
            }
            .buttonStyle(GradientBackgroundStyle()).padding()
            
            Spacer()
        }
        .actionSheet(isPresented: self.$sheetPresented) {
            self.aSheet()
        }
        .sheet(isPresented: self.$editProfilePresented) {
            print("thing is dismissed!")
        } content: {
            
            if sourceType == .camera {
                CameraImagePicker(callback: callback).edgesIgnoringSafeArea(.bottom)
            } else {
                SingleImagePicker(callback: callback).edgesIgnoringSafeArea(.bottom)
            }
            
//            NavigationView(){
//                ProfileEditView(user: user)
//            }.navigationBarTitle("Update Photo")
        }
        .onTapGesture {
            self.sheetPresented.toggle()
        }
    }
    
}

struct UserProfileView2_Previews: PreviewProvider {
    
    static var previews: some View {
        let user = SEED_DATA.users.first!
        
        return NavigationView(){
            UserProfileView2(user: user.builder())
        }.navigationTitle(user.name)
    }
    
}
