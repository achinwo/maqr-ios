//
//  NetworkImageView.swift
//  Joli
//
//  Created by Anthony Chinwo on 03/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Kingfisher

public struct NetworkImage<Content: SwiftUI.View>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public typealias Callback = (UIImage?, Error?) -> Void
    
    var callback: Callback?
    
    @State private var image: UIImage? = nil
    @State public var imageURL: URL? = nil
    
    public let placeholderContent: Content
    public let animation: Animation = .easeInOut
    
    init(string: String?, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        guard let string = string else {
            self.init(url: nil, onLoaded: onLoaded, content: content)
            return
        }
        self.init(url: URL(string: string), onLoaded: onLoaded, content: content)
    }
    
    init(url: URL? = nil, onLoaded: Callback? = nil, @ViewBuilder content: () -> Content) {
        //self.placeholderImage = placeholderImage
        self.callback = onLoaded
        self.placeholderContent = content()
        
        self._imageURL = State(initialValue: url)
    }
    
    public var body: some SwiftUI.View {
        
        return ZStack(){
                if let image = image {
                    SwiftUI.Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderContent
                }
            }
            .onAppear(perform: loadImage)
            .transition(.opacity)
            .id(image)
    }
    
    private func loadImage() {
        guard let imageURL = imageURL, image == nil else { return }
        
        if appCoordinator.api != nil, let host = appCoordinator.api.baseUrlHttp.host {
            KingfisherManager.shared.downloader.trustedHosts = Set([host])
        }
        
        KingfisherManager.shared.retrieveImage(with: imageURL) { result in
            switch result {
                case .success(let imageResult):
                    withAnimation(self.animation) {
                        DispatchQueue.main.async {
                            self.image = imageResult.image
                            self.callback?(self.image, nil)
                        }
                    }
                case .failure(let error):
                    self.callback?(nil, error)
            }
        }
    }
}

extension NetworkImage where Content == SwiftUI.Image {
    
    init(imageURL: URL, placeholderImage: UIImage, onLoaded: Callback? = nil) {
        self.placeholderContent = SwiftUI.Image(uiImage: placeholderImage)
        self._imageURL = State(initialValue: imageURL)
        self.callback = onLoaded
    }
    
}
