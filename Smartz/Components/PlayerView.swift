//
//  PlayerView.swift
//  Joli
//
//  Created by Anthony Chinwo on 28/05/2023.
//  Copyright © 2023 Anthony Chinwo. All rights reserved.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import SharedUI
import AVKit
#endif

import AVFoundation

struct PlayerView: UIViewRepresentable {
    
    var url: URL
    var isMuted = true
    var size: CGSize
    
    init(url: URL, isMuted: Bool = true, size: CGSize? = nil){
        self.url = url //??
        self.isMuted = isMuted
        self.size = size ?? .init(width: Self.bounds.width, height: Self.bounds.width / 1.2)
    }
    
    static var bounds: CGRect {
#if os(macOS)
        return NSScreen.main?.frame ?? .init(origin: .zero, size: .init(width: 600, height: 400))
#else
        return UIScreen.main.bounds
#endif
    }
    
    func updateView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
        print("[updateUIView] Is Vides muted: \(isMuted)")
        guard let loopingView = uiView as? LoopingPlayerUIView,
              loopingView.url != url ||
                loopingView.isMuted != isMuted else { return }
        
        print("[updateUIView] updating Video mute: \(loopingView.isMuted) -> \(isMuted) | \(loopingView.url) -> \(url)")
        loopingView.isMuted = isMuted
        
        guard let loopingView = uiView as? LoopingPlayerUIView, loopingView.url != url else { return }
        
        print("[updateUIView] updating Video url: \(url)")
        loopingView.url = url
    }
    
    func makeView(context: Context) -> UIView {
        print("[makeUIView] Is Vides muted: \(isMuted)")
        let size = self.size == .zero ? .init(width: Self.bounds.width, height: Self.bounds.width / 1.2) : self.size
        return LoopingPlayerUIView(frame: CGRect.init(origin: .zero, size: size), url: url, isMuted: isMuted)
    }
    
#if os(macOS)
    func updateNSView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
        updateView(uiView, context: context)
    }
    
    func makeNSView(context: Context) -> UIView {
        return makeView(context: context)
    }
    
#else
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
        updateView(uiView, context: context)
    }
    
    func makeUIView(context: Context) -> UIView {
        return makeView(context: context)
    }
#endif
    
}


class LoopingPlayerUIView: UIView {
    
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    public var playerQueue = AVQueuePlayer()
    
    private var audioSessionSet: Bool = false
    
    public var url: URL = URL(string: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4")! {
        didSet {
            playerLooper = nil
            initWithItem(AVPlayerItem(url: self.url))
        }
    }
    
    public var isMuted: Bool = true {
        didSet {
            playerQueue.isMuted = isMuted
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(frame: CGRect, url: URL? = nil, isMuted: Bool = true) {
        super.init(frame: frame)
        
        self.isMuted = isMuted
        self.url = url ?? URL(string: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4")!
        initWithItem(AVPlayerItem(url: self.url))
    }
    
    public func initWithItem(_ item: AVPlayerItem){
            // Setup the player
        playerLayer.player = playerQueue
        playerLayer.videoGravity = .resizeAspectFill
        
#if !os(macOS)
        layer.addSublayer(playerLayer)
#endif
        
        playerQueue.pause()
        
            // Create a new player looper with the queue player and template item
        playerLooper = AVPlayerLooper(player: playerQueue, templateItem: item)
        
        print("[init] Is Vides muted: \(isMuted)")
            // Start the movie
        playerQueue.isMuted = isMuted
        playerQueue.play()
    }
    
#if !os(macOS)
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        guard !audioSessionSet else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            audioSessionSet = true
        }
        catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
#endif
    
}
