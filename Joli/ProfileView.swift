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

class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @Binding var isShown: Bool
    @Binding var image: Image?
    
    init(isShown: Binding<Bool>, image: Binding<Image?>) {
        _isShown = isShown
        _image = image
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        let uiImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        image = Image(uiImage: uiImage)
        
        print("Here's the image: \(image)")
        
        isShown = false
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        isShown = false
    }
}

struct ImagePickerCamera: UIViewControllerRepresentable {
    
    @Binding var isShown: Bool
    @Binding var image: Image?
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePickerCamera>) {
        uiViewController.view.backgroundColor = .black
    }
    
    func makeCoordinator() -> ImagePickerCoordinator {
        return ImagePickerCoordinator(isShown: $isShown, image: $image)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePickerCamera>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
//        if !UIImagePickerController.isSourceTypeAvailable(.camera){
//            picker.sourceType = .photoLibrary
//        } else {
            picker.sourceType = .camera
        //}
        return picker
    }
    
}

class SingleSelectionPickerViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // The client is responsible for presentation and dismissal
        picker.dismiss(animated: true)
        
        // Get the first item provider from the results, the configuration only allowed one image to be selected
        let itemProvider = results.first?.itemProvider
        
        if let itemProvider = itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                // TODO: Do something with the image or handle the error
                print("image: \(image), error: \(error)")
            }
        } else {
            // TODO: Handle empty results or item provider not being able load UIImage
            print("image: empty!")
        }
    }


}

var pickerDelegate: SingleSelectionPickerViewController? = nil

struct ImagePicker: UIViewControllerRepresentable {
        
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> PHPickerViewController {
        
        var configuration = PHPickerConfiguration()
        // Only wants images
        configuration.filter = .livePhotos
        
        
        let picker = PHPickerViewController(configuration: configuration)
        
        pickerDelegate = SingleSelectionPickerViewController()
        picker.delegate = pickerDelegate
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        print ("Update: \(uiViewController)")
        
    }
    
    
}

//
//
//

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
    
    var body: some View {
        
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
        .sheet(isPresented: self.$editProfilePresented) {
            print("thing is dismissed!")
        } content: {
            ImagePicker()
//            NavigationView(){
//                ProfileEditView(user: user)
//            }.navigationBarTitle("Update Photo")
        }
        .onTapGesture {
            self.editProfilePresented.toggle()
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
