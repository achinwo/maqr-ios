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
                    return (default: "envelope", active: "envelope.fill")
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
    @AppStorage("active-tab") var selectedTab: Tab = .information
    
    @State var feebackText: String = .empty
    
    var appclipsCodesView: some View {
        VStack(){
            Image("appclipcode_with_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: screenWidth / 2)
                .overlay(
                    GeometryReader() { proxy in
                        Text("Coming Soon")
                            .fixedSize(horizontal: true, vertical: true)
                            .font(.title)
                            .foregroundColor(.fixedWhite)
                            .padding()
                            .padding(.horizontal, proxy.size.height / 8)
                            .background(Color.fixedGray)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .offset(x: proxy.size.width / 2 * -1, y: proxy.size.height / 4)
                            .rotationEffect(.degrees(-45), anchor: .leading)
                    }
                )
                .clipped()
            Text("App Clip Code Generator").font(.largeTitle).multilineTextAlignment(.center).foregroundColor(.primary).padding()
            Text("Design and download custom auto-downloading App Clip codes for your brand!").font(.title2).foregroundColor(.secondaryLabel).padding(.horizontal).multilineTextAlignment(.center)
        }
        .padding()
        .padding(.top, safeAreaInsets.top)
    }
    
    var feedbackView: some View {
        ScrollView(){
            VStack(){
                VStack(){
                    
                    
                    Section(header: Text("Get in Touch").font(.largeTitle)) {
                        Text("We'd love to hear from you!").font(.subheadline.weight(.light)).padding(.bottom).multilineTextAlignment(.center).lineLimit(5)
                        
                        TextEditor(text: self.$feebackText)
                            .frame(height: screenWidth / 2)
                            .overlay(
                                VStack(alignment: .leading){
                                    if feebackText.isEmpty {
                                        Text("Enter your message here").padding().foregroundColor(.tertiaryLabel)
                                        Spacer()
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                    }
                    .padding()
                    
                    Button(){
                        print("submitted help!")
                        let subject = "SmartStikr iOS App Feedback - \(AppCoordinator.version)"
                        self.appCoordinator.mailOptions = .init(subject: subject, recipients: [Strings.appSupportEmail], body: feebackText)
                    } label: {
                        HStack(){
                            Spacer()
                            Text("Send Message")
                                .font(.title3)
                                .foregroundColor(.label)
                            Spacer()
                        }
                    }
                    .background(Color.systemIndigo)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    ))
                    .frame(width: screenWidth - 150, height: 60)
                    .accentColor(.white)
                    .buttonStyle(OutlineButton())
                    .padding()
                }
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.bottom)
                .overlay(
                    GeometryReader(){ _ in
                        VStack(){
                            Image("smartz_logo")
                                .resizable()
                                .frame(width: screenWidth / 6, height: screenWidth / 6)
                                .clipShape(Circle())
                                .offset(x: 0, y: (screenWidth / 24) * -1)
                                .shadow(radius: 1)
                            Spacer()
                        }
                    }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded() { value in
                            
                            guard appCoordinator.keyboardHeight > 0 else {
                                return
                            }
                            
                            appCoordinator.dismissKeyboard()
                        }
                )
                
            }
            .frame(width: screenWidth - 100)
            .padding(.top, safeAreaInsets.top * 2)
        }
        .frame(minWidth: screenWidth, minHeight: screenHeight)
        
    }
    
    
    var contentView: some View {
        NavigationView(){
            
                ZStack(){
                    
                        VStack(){
                            if self.selectedTab == .information {
                                ScrollView(.vertical){
                                    Image("smartz_logo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: screenWidth / 3, maxHeight: screenWidth / 3)
                                    Text("Smart Stikr").font(.caption).foregroundColor(.tertiaryLabel).padding([.bottom])
                                    (Text("Welcome to the ").font(.title.weight(.light)).foregroundColor(.tertiaryLabel)
                                        + Text("Paperless ").font(.title.weight(.light)).foregroundColor(.secondaryLabel)
                                        + Text("Future").font(.title.weight(.light)).foregroundColor(.tertiaryLabel)).multilineTextAlignment(.center)
                                    Text("""
                                    Ditch all that paper & give your customers a more customised and streamlined experience for their meal prep boxes by digitizing through Smart Stikr App clip. The experience will be completely customised to your company style and offerings and your customers will have options to reorder or just browse your menu for other ideas and seamlessly place the order from you directly with one click through apple pay.
                                    
                                    By simply attaching one or few of the below app clips on the box delivered to the clients, you take away the need for paper instructions and
                                    give your customers a more involved experience to Meal Prep with you and your company.
                                """)
                                        .multilineTextAlignment(.center)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding()
                                    Divider().padding()
                                    self.mainView
                                    Divider().padding()
                                    
                                    Button(){
                                        self.selectedTab = .appClipCreator
                                    } label: {
                                        HStack(){
                                            Spacer()
                                            HStack(){
                                                Text("Create & Download Codes")
                                                Image(systemName: "qrcode")
                                            }
                                            .font(.title3)
                                            .foregroundColor(.label)
                                            Spacer()
                                        }
                                    }
                                    .background(Color.pink)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .overlay(
                                        GeometryReader() { proxy in
                                            HStack(){
                                                Spacer()
                                                Text("Coming Soon")
                                                    .fixedSize(horizontal: true, vertical: true)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundColor(.fixedWhite)
                                                    .padding(2)
                                                    .background(Color.fixedGray)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    .offset(x: proxy.size.height / 4, y: proxy.size.height / 12 * -1)
                                                    .rotationEffect(.degrees(15))
                                                //.rotationEffect(.degres(15))
                                            }
                                        }
                                    )
                                    .frame(width: screenWidth - 100, height: 60)
                                    .accentColor(.orange)
                                    .buttonStyle(OutlineButton())
                                    .padding(.top, safeAreaInsets.top)
                                    .padding(.bottom, safeAreaInsets.bottom)
                                    .animation(.easeInOut)
                                }
                            } else if self.selectedTab == .feedback {
                                ScrollView(.vertical){
                                    feedbackView
                                }
                            } else if self.selectedTab == .appClipCreator {
                                ScrollView(.vertical){
                                    appclipsCodesView
                                }
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
                                .onTapGesture {
                                    self.selectedTab = tab
                                }
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
        .background(
            Group(){
                if self.selectedTab == .feedback {
                    Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    EmptyView()
                }
            }
        )
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
