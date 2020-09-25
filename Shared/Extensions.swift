//
//  Extensions.swift
//  Joli
//
//  Created by Anthony Chinwo on 31/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliApi
import SwiftUI
import JoliCore
import Promises
import UIKit
import PartialSheet
import Combine

public extension Builder where T == User {
    
    var ranking: DiscjockeyPosition {
        guard let djPosition = self[.djRanking, Int?.self] as? Int else {
            return DiscjockeyPosition.personal
        }
        
        return DiscjockeyPosition(rawValue: djPosition) ?? DiscjockeyPosition.personal
    }
}


public extension View {
    
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
    
}

public extension Search.Engine {
    
    typealias SearchMethod = (String, Set<Search.Category>, Int) -> AnyPublisher<[Search.ResultView], Never>
    
    func search(_ q: String, _ categories: Set<Search.Category>, limit: Int = 6, search searchFn: SearchMethod) -> AnyPublisher<[Search.ResultView], Never> {
        let supported = categories.filter(){ supportedCategories.contains($0) }
        
        guard !supported.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }
        
        return searchFn(q, supported, limit)
    }
    
}

public extension Search {
    
    struct ResultView: JoliView, Identifiable {
        
        @EnvironmentObject public var appCoordinator: AppCoordinator
        
        public var result: Result
        
        public var id: String {
            return result.id
        }
        
        private let content: () -> GeometryReader<AnyView>
        
        public init(result: Result, @ViewBuilder content: @escaping () -> GeometryReader<AnyView>){
            self.result = result
            self.content = content
        }
        
        public var body: some View {
            content()
        }
    }
}

extension View {
    
    var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    var screenWidth: CGFloat {
        return screenSize.width
    }
    
    var screenHeight: CGFloat {
        return screenSize.height
    }
    
}


extension View {

    
    func onFrameChange(enabled isEnabled: Bool = true, _ frameHandler: @escaping (CGRect)->()) -> some View {

        guard isEnabled else { return AnyView(self) }

        return AnyView(self.background(GeometryReader() { (geometry: GeometryProxy) in

            Color.clear.beforeReturn {

                frameHandler(geometry.frame(in: .global))
            }
        }))
    }

    private func beforeReturn(_ onBeforeReturn: ()->()) -> Self {
        onBeforeReturn()
        return self
    }
}

extension Spotify.Device {
    
    var imageName: String {
        switch type {
            case .smartphone:
                return "iphone"
            case .computer:
                return "laptopcomputer"
            case .automobile:
                return "car"
            case .tablet:
                return "ipad"
            case .tv:
                return "tv"
            default:
                return "hifispeaker"
        }
    }
}


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

extension UIImage {
    
    var noir: UIImage? {
        let context = CIContext(options: nil)
        
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else {
            return nil
        }
        
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        
        guard let output = currentFilter.outputImage, let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    func squared() -> UIImage? {
        guard size.width != size.height else {
            return self
        }

        let cropWidth = min(size.width, size.height)

        let cropRect = CGRect(
            x: (size.width - cropWidth) * scale / 2.0,
            y: (size.height - cropWidth) * scale / 2.0,
            width: cropWidth * scale,
            height: cropWidth * scale
        )

        guard let imageRef = cgImage?.cropping(to: cropRect) else {
            return nil
        }
        //print("[UIImage] new size: \(cropRect)")
        return UIImage(cgImage: imageRef, scale: scale, orientation: imageOrientation)
    }
    
}


public extension String {
    static var empty: String {
        return ""
    }
}

public final class ImageStore {
    typealias _ImageDictionary = [String: CGImage]
    fileprivate var images: _ImageDictionary = [:]

    fileprivate static var scale = 2
    
    public static var shared = ImageStore()
    
    public func image(name: String) -> SwiftUI.Image {
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

extension Data {
    
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else {
          return
        }
        
        self.append(data)
    }
}
