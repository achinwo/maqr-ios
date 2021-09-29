//
//  NetworkImageView.swift
//  Joli
//
//  Created by Anthony Chinwo on 03/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import struct NetworkImage.NetworkImageLoader


#if os(macOS)
extension UIImage {
    
    convenience init?(systemName: String) {
        self.init(systemSymbolName: systemName, accessibilityDescription: nil)
    }
}
#endif

public struct QrCodeImageView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    let targetUrl: URL
    
    public var contentView: some View {
        NetworkImage(imageURL: targetUrl, placeholderImage: UIImage(systemName: "qrcode")!)
    }
}


public struct NetworkImage<PlaceHolderContent: SwiftUI.View>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public typealias Callback = (UIImage?, Error?) -> Void
    
    var callback: Callback?
    
    @State private var image: UIImage? = nil
    @State public var imageURL: URL? = nil
    
    public let placeholderContent: PlaceHolderContent
    public let animation: Animation = .easeInOut
    
    public init(string: String?, onLoaded: Callback? = nil, @ViewBuilder content: () -> PlaceHolderContent) {
        guard let string = string else {
            self.init(url: nil, onLoaded: onLoaded, content: content)
            return
        }
        self.init(url: URL(string: string), onLoaded: onLoaded, content: content)
    }
    
    public init(url: URL? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> PlaceHolderContent) {
        //self.placeholderImage = placeholderImage
        self.callback = onLoaded
        self.placeholderContent = content()
        
        self._imageURL = State(initialValue: url)
    }
    
    public var contentView: some SwiftUI.View {
        
        return ZStack(){
                if let image = image {
                    #if os(macOS)
                    SwiftUI.Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #else
                    SwiftUI.Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    placeholderContent
                }
            }
            .onAppear(perform: loadImage)
            .transition(.opacity)
            .id(image)
    }
    
    @State public var imageSubscription: AnyCancellable? = nil
    
    private func loadImage() {
        guard let imageURL = imageURL, image == nil else { return }
        
        self.imageSubscription = appCoordinator.imageLoader.image(for: imageURL)
            .receive(on: DispatchQueue.main)
            .sink(){ completion in
                switch completion {
                    case .failure(let error):
                        self.callback?(nil, error)
                    case .finished:
                        self.imageSubscription = nil
                }
            } receiveValue: { image in
                withAnimation(self.animation) {
                    self.image = image
                    self.callback?(self.image, nil)
                }
            }
        
            //.retrieveImage(with: imageURL) { result in

//        }
    }
}

extension NetworkImage where PlaceHolderContent == SwiftUI.Image {
    
    public init(imageURL: URL, placeholderImage: UIImage, onLoaded: Callback? = nil) {
        
        #if os(macOS)
        self.placeholderContent = SwiftUI.Image(nsImage: placeholderImage)
        #else
        self.placeholderContent = SwiftUI.Image(uiImage: placeholderImage)
        #endif
        
        self._imageURL = State(initialValue: imageURL)
        self.callback = onLoaded
    }
    
}
