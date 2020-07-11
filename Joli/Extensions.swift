//
//  Extensions.swift
//  Joli
//
//  Created by Anthony Chinwo on 31/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import Foundation
import  JoliApi
import SwiftUI
import JoliCore
import Promises

extension JoliApi {
    
    @discardableResult
    func playMusicroom(_ room: Musicroom, device: Spotify.Device, on: DispatchQueue? = nil) -> Promise<Musicroom> {
        return HttpMethod.Fetch.post(url: "/api/musicrooms/\(room.id)/play?deviceId=\(device.id)", dataType: Musicroom.self, baseUrl: self.baseUrl.http, urlSession: self.urlSession, on: on)
    }
    
    //fetch<T: Codable>(urlString: String, dataType: T.Type, baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil)
    
    public func save<T>(_ model: T, on: DispatchQueue? = nil) -> Promise<T.PersistedType> where T: Persistable {
        return model.save(baseUrl: self.baseUrl.rawValue.http, urlSession: urlSession, on: on)
    }
    
    func fetchQueuedTracks(room: Musicroom, on: DispatchQueue? = nil) -> Promise<[QueuedTrack]> {
        return HttpMethod.Fetch.get(url: "/api/musicrooms/\(room.id)/queued", dataType: [QueuedTrack].self, baseUrl: self.baseUrl.http, urlSession: self.urlSession, on: on)
    }
    
}

extension Musicroom {
    
    
}

struct KeyboardAwareModifier: ViewModifier {
    
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(AppState.keyboardHeightPublisher) { self.keyboardHeight = $0 }
    }
}

extension View {
    
    func keyboardAwarePadding() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAwareModifier())
    }
}


extension UIImage {
    var noir: UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
}


typealias Renderable = View


public final class ImageStore {
    typealias _ImageDictionary = [String: CGImage]
    fileprivate var images: _ImageDictionary = [:]

    fileprivate static var scale = 2
    
    public static var shared = ImageStore()
    
    public func image(name: String) -> Image {
        let index = _guaranteeImage(name: name)
        
        return Image(images.values[index], scale: CGFloat(ImageStore.scale), label: Text(verbatim: name))
    }

    public static func loadImage(name: String) -> CGImage {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "jpg") ?? Bundle.main.url(forResource: name, withExtension: "png"),
            let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            fatalError("Couldn't load image \(name).jpg from main bundle.")
        }
        return image
    }
    
    fileprivate func _guaranteeImage(name: String) -> _ImageDictionary.Index {
        if let index = images.index(forKey: name) { return index }
        
        images[name] = ImageStore.loadImage(name: name)
        return images.index(forKey: name)!
    }
}
