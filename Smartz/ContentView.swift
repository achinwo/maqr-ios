//
//  ContentView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 22/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import AVKit
import JoliPlayground

enum AssetInfo {
    case video(AVPlayer)
    case image(String)
}

struct ProductSection: Identifiable {
    let asset: AssetInfo
    let title: String
    let subtitle: String
    
    var id: String {
        title
    }
}

struct ContentView: JoliView {
    
    enum Tab: Int, Identifiable, CaseIterable {
        case information
        case appClipCreator
//        case gallery
        case feedback
        
        var id: Int {
            rawValue
        }
        
        var label: String {
            switch self {
//                case .gallery:
//                    return "Gallery"
                case .feedback:
                    return "Feedback"
                case .appClipCreator:
                    return "Codes"
                case .information:
                    return "Info"
            }
        }
        
        var color: Color {
            switch self {
//                case .gallery:
//                    return .orange
                case .feedback:
                    return Color.systemIndigo
                case .appClipCreator:
                    return .pink
                case .information:
                    return .green
            }
        }
        
        var emoji: (default: String, active: String) {
            switch self {
//                case .gallery:
//                    return (default: "photo.on.rectangle", active: "photo.on.rectangle.angled")
                case .feedback:
                    return (default: "questionmark.circle", active: "questionmark.circle.fill")
                case .appClipCreator:
                    return (default: "qrcode", active: "qrcode.viewfinder")
                case .information:
                    return (default: "info", active: "info")
            }
        }
    }
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var videoUrl: URL? = nil
    @State var players: [String: AVPlayer] = [:]
    @State var maximised: Bool = false
    
    let sections: [ProductSection] = [
        ProductSection(asset: .video(AVPlayer(url: Bundle.main.url(forResource: "demo_sise_intro", withExtension: "mov")!)),
                       title: "NFC demo",
                       subtitle: "Contactless experience activation"),
        
        ProductSection(asset: .video(AVPlayer(url: Bundle.main.url(forResource: "demo_sise_appclip", withExtension: "mp4")!)),
                       title: "Bespoke Native App Experience",
                       subtitle: "App experiences tailored to your business and customers needs, with seamless Apple Pay integration"),
        
        ProductSection(asset: .image("app_clip_choices"),
                       title: "Custom Designs",
                       subtitle: "App Clip codes as unique as your brand"),
        
    ]
    
    @State var activeSectionIdx: Int? = nil
    
    @Namespace var animation
    
    var mainView: some View {
            VStack(){
                ForEach(sections){ section in
                    Section(header: Text(section.title).font(.title2)){
                        VStack(){
                            Text(section.subtitle)
                                .multilineTextAlignment(.center)
                                .font(.subheadline.weight(.light))
                                .foregroundColor(.secondaryLabel)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Group(){
                                if case let .video(player) = section.asset {
                                    VideoPlayer(player: player)
                                        .frame(height: screenWidth - 100)
                                        .onTapGesture {
                                            print("Tapped Video")
                                            maximised.toggle()
                    
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                if maximised {
                                                    player.play()
                                                } else {
                                                    player.pause()
                                                }
                                            }
                                        }
                                } else if case let .image(imageName) = section.asset {
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.secondaryLabel, lineWidth: 1))
                            .padding(.vertical)
                        }
                    }
                    .padding([.bottom, .horizontal])
                    
                }
                

            }
    }
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @State var selectedTab: Tab = .information
    
    var contentView: some View {
        NavigationView(){
            
                ZStack(){
                    ScrollView(.vertical){
                        if self.selectedTab == .information {
                            self.mainView
                                .padding(.top, safeAreaInsets.top)
                                .padding(.bottom, safeAreaInsets.bottom)
                                .animation(.easeInOut)
                        }
//                        } else if self.selectedTab == .gallery {
//                            galleryView
//                        } else if self.selectedTab == .information {
//                            infoView
//                        } else if self.selectedTab == .help {
//                            helpView
//                        }
                    }
                    
                    VStack(){
                        Spacer()
                        //                Picker(selection: self.$selectedTab, label: Text("Users")) {
                        HStack(){
                            ForEach(Tab.allCases) { tab in
                                Button() {
                                    self.selectedTab = tab
                                } label: {
                                    HStack(){
                                        Image(systemName: selectedTab == tab ? tab.emoji.active : tab.emoji.default)
                                        Text(tab.label).lineLimit(1).fixedSize(horizontal: true, vertical: true)
                                    }
                                    .foregroundColor(selectedTab == tab ? tab.color : .primary)
                                    .padding()
                                }
                                .if(selectedTab == tab){ view in
                                    view.background(BlurView(colorScheme == .dark ? .systemThickMaterialDark : .systemThickMaterialLight))
                                } else: { view in
                                    view.background(Color.clear)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 25.0))
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .light))
                            }
                        }
                        .padding(4)
                        .frame(maxWidth: screenWidth - 50, alignment: .center)
                        .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                        .clipShape(RoundedRectangle(cornerRadius: 25.0))
                        .animation(.easeInOut)
                    }
                    .padding(.bottom, safeAreaInsets.bottom)
                    
                    
                    //            HStack(){
                    //                Button() {
                    //
                    //                }
                    //            }
                }
                   // .navigationBarTitle(Text("Welcome to Smart Stikr"), displayMode: .large)
        }
        .edgesIgnoringSafeArea(.all)
        .frame(minWidth: screenWidth, minHeight: screenHeight)
        .overlay(
            GeometryReader(){ proxy in
                Group(){
//                    if let player = player, maximised {
//                        VideoPlayer(player: player)
//                            .frame(width: proxy.size.width, height: proxy.size.height - proxy.safeAreaInsets.bottom - proxy.safeAreaInsets.top)
//                            //.matchedGeometryEffect(id: "intro-video", in: animation)
//                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 100)
                        .onChanged(){ value in
                            print("dragged: \(value)")
                        }
                        .onEnded() { val in
                            print("ended: \(val)")
                            self.maximised = false
                        }
                )
                
            }
        )
        .animation(.spring())
        .onAppear(){
            self.videoUrl = Bundle.main.url(forResource: "demo_sise_intro", withExtension: "mov")
            
            guard let url = self.videoUrl else { return }
            
            //self.player = AVPlayer(url: url)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
