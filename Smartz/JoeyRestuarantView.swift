//
//  JoeyRestuarantView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/06/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import Combine
import AlertToast
import JoliCore
import AVKit
import AVFoundation

struct PlayerView: UIViewRepresentable {
    
    var url: URL
    var isMuted = true
    var size: CGSize
    
    init(url: URL, isMuted: Bool = true, size: CGSize? = nil){
        self.url = url //?? 
        self.isMuted = isMuted
        self.size = size ?? .init(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width / 1.2)
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
        
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

    func makeUIView(context: Context) -> UIView {
        print("[makeUIView] Is Vides muted: \(isMuted)")
        let size = self.size == .zero ? .init(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width / 1.2) : self.size
        return LoopingPlayerUIView(frame: CGRect.init(origin: .zero, size: size), url: url, isMuted: isMuted)
    }
    
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
        layer.addSublayer(playerLayer)
        
        playerQueue.pause()
        
        // Create a new player looper with the queue player and template item
        playerLooper = AVPlayerLooper(player: playerQueue, templateItem: item)
        
        print("[init] Is Vides muted: \(isMuted)")
        // Start the movie
        playerQueue.isMuted = isMuted
        playerQueue.play()
    }
    
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
}

struct JoeyRestuarantView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    var localPlaybackController: PlaybackControllerType
    
    var websocket: Socket
    
    @State var websocketCancel: AnyCancellable?
    
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    
    @Binding var currentUser: User?
    
    @Environment(\.colorScheme) var colorScheme
    //@AppStorage("active-tab-mealprep") var selectedTab = Tab.information
    
    
    public init(currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType){
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
    }
        
    var contentView: some View {
        RestaurantProxyView()
    }
}
