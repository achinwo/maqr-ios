//
//  NetworkImageView.swift
//  Joli
//
//  Created by Anthony Chinwo on 03/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Kingfisher

public struct NetworkImage: SwiftUI.View {
    
    var callback: ((UIImage?) -> Void)?
    
    @State private var image: UIImage? = nil
    
    public let imageURL: URL?
    public let placeholderImage: UIImage
    public let animation: Animation = .easeInOut
    
    init(imageURL: URL, placeholderImage: UIImage, onLoaded: ((UIImage?) -> Void)? = nil) {
        self.imageURL = imageURL
        self.placeholderImage = placeholderImage
        self.callback = onLoaded
    }
    
    public var body: some SwiftUI.View {
        SwiftUI.Image(uiImage: image ?? placeholderImage)
            .resizable()
            .frame(width: 64, height: 64, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
            .onAppear(perform: loadImage)
            .transition(.opacity)
            .id(image ?? placeholderImage)
    }
    
    private func loadImage() {
        guard let imageURL = imageURL, image == nil else { return }
        
        KingfisherManager.shared.retrieveImage(with: imageURL) { result in
            switch result {
                case .success(let imageResult):
                    withAnimation(self.animation) {
                        self.image = imageResult.image
                        self.callback?(self.image)
                    }
                case .failure:
                    break
            }
        }
    }
}
