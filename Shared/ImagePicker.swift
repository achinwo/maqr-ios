//
//  ImagePicker.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
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
            self.callback(nil, nil)
            return
        }
        
        itemProvider.loadObject(ofClass: UIImage.self) { (image: NSItemProviderReading?, error) in
            self.callback((image as? UIImage)?.squared(), error)
        }
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        self.callback(image?.squared(), nil)
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
