//
//  ActivityIndicator.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI

#if os(macOS)
@available(macOS 11, *)
struct ActivityIndicator: NSViewRepresentable {
    
    func makeNSView(context: NSViewRepresentableContext<ActivityIndicator>) -> NSProgressIndicator {
        let nsView = NSProgressIndicator()
        
        nsView.isIndeterminate = true
        nsView.style = .spinning
        nsView.startAnimation(context)
        
        return nsView
    }
    
    func updateNSView(_ nsView: NSProgressIndicator, context: NSViewRepresentableContext<ActivityIndicator>) {
    }
}
#else
@available(iOS 13, *)
public struct ActivityIndicator: UIViewRepresentable {

    public typealias UIView = UIActivityIndicatorView
    public var isAnimating: Bool
    public var configuration = { (indicator: UIView) in }

    public func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView { UIView() }
    public func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
        configuration(uiView)
    }
}

extension View where Self == ActivityIndicator {
    func configure(_ configuration: @escaping (Self.UIView) -> Void) -> Self {
        Self.init(isAnimating: self.isAnimating, configuration: configuration)
    }
}
#endif
