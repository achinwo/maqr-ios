//
//  ImagePicker.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import PhotosUI

public class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate {
    
    var callback: (UIImage?, String?, Error?) -> Void
    
    public init(callback: @escaping (UIImage?, String?, Error?) -> Void) {
        self.callback = callback
    }
    
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // The client is responsible for presentation and dismissal
        
        guard let result = results.first, result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
            self.callback(nil, nil, nil)
            return
        }
        
        
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { (image: NSItemProviderReading?, error) in
            
            guard error == nil else {
                self.callback(image as? UIImage, result.assetIdentifier, error)
                return
            }
            
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.item"){ imgUrl, _ in
                self.callback(image as? UIImage, imgUrl?.lastPathComponent ?? result.assetIdentifier, error)
            }
        }
        
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        let imageUrl = info[UIImagePickerController.InfoKey.imageURL] as? URL
        self.callback(image, imageUrl?.lastPathComponent, nil)
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        callback(nil, nil, nil)
    }
    
}

public protocol ImagePickerRepresentable: UIViewControllerRepresentable {
    associatedtype ImagePickerViewController: UIViewController
    
    var callback: (UIImage?, String?, Error?) -> Void { get set }
    func makeUIViewController(context: UIViewControllerRepresentableContext<Self>) -> ImagePickerViewController
}

extension ImagePickerRepresentable {
    
    public func updateUIViewController(_ uiViewController: ImagePickerViewController, context: UIViewControllerRepresentableContext<Self>) {
    }
    
    public func makeCoordinator() -> ImagePickerCoordinator {
        return ImagePickerCoordinator(callback: callback)
    }
}

public struct SingleImagePicker: ImagePickerRepresentable {
    
    public var callback: (UIImage?, String?, Error?) -> Void
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<SingleImagePicker>) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .livePhotos])
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
}

public struct CameraImagePicker: ImagePickerRepresentable {
    
    public var callback: (UIImage?, String?, Error?) -> Void
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<CameraImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
}
