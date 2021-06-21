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
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
    }

    func makeUIView(context: Context) -> UIView {
        let width = UIScreen.main.bounds.width
        return LoopingPlayerUIView(frame: CGRect.init(origin: .zero, size: .init(width: width, height: width / 1.2)))
    }
}


class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        let item = AVPlayerItem(url: URL(string: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4")!)
        
        // Setup the player
        let player = AVQueuePlayer()
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
         
        // Create a new player looper with the queue player and template item
        playerLooper = AVPlayerLooper(player: player, templateItem: item)

        // Start the movie
        player.isMuted = true
        player.play()
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
    
    let joeyVideo = AVPlayer(url: URL(string: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4")!)
    
    var infoView: some View {
        ScrollViewReader() { proxy in
            ScrollView(showsIndicators: false){
                VStack(spacing: .zero){
                    
                    //VideoPlayer(player: joeyVideo)
                    PlayerView()
                        .frame(width: screenWidth, height: screenWidth / 1.6)
                        .clipped()
                        
                        .background(
                            BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
                                .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle()))
                        )
                    
                    Image(colorScheme == .dark ? "logo_joey_full_white" : "logo_joey_full_black")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: screenWidth * 0.7)
                        .padding()
                        .padding(.vertical)
                        //.offset(x: 0, y: -200)
                        .id("brand")
                    //
                    
                    VStack(){
                        Section(header: Text("HELLO & WELCOME").font(.title3)) {
                            (Text("JOEY Sherway ").font(.subheadline.weight(.semibold))
                            + Text("restaurant features a warm and modern industrial design and a seasonal rooftop patio in this popular Toronto neighbourhood gathering spot.")
                                .font(.body.weight(.light))
                            )
                            .padding(.bottom)
                            .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .frame(width: screenWidth - 100)
                    .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.bottom)
                    .padding(.bottom)
                    .id("body")
                    
                    VStack(){
                        Text("How can we be of service?")
                            .font(.title2.weight(.light))
                            .padding(.bottom)
                        
                        Button(){
                        } label: {
                            Text("I'd like to walk in")
                                .font(.title3)
                                .foregroundColor(.label)
                        }
                        .frame(width: screenWidth - 100, height: 60)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        ))
                        //.frame(width: screenWidth - 100, height: 60)
                        .accentColor(.blue)
                        .buttonStyle(OutlineButton())
                        .padding(.bottom)
                        
                        Button(){
                        } label: {
                            Text("I have a reservation")
                                .font(.title3)
                                .foregroundColor(.label)
                        }
                        .frame(width: screenWidth - 100, height: 60)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        ))
                        //.frame(width: screenWidth - 100, height: 60)
                        .accentColor(.green)
                        .buttonStyle(OutlineButton())
                    }
                    
                    Spacer()
                    Link("Restaurant Menu Icon by Icons8", destination: URL(string: "https://icons8.com/icon/tmr075NtT7e6/restaurant-menu")!)
                        .font(.caption)
                }
                .frame(minHeight: screenHeight * 1.2)
                .padding(.bottom, max(100, safeAreaInsets.bottom))
                //.padding(.top, safeAreaInsets.top)
            }
            .background(Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
            )
        }
    }
    
    
    var contentView: some View {
        ZStack(){
            infoView
                .frame(width: screenWidth, height: screenHeight)
                .onAppear(){
                }
        }
        .frame(width: screenWidth, height: screenHeight)
        .edgesIgnoringSafeArea(.vertical)
        
    }
}
