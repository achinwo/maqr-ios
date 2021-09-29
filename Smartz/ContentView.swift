//
//  ContentView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 22/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import AVKit
import SharedUI
import JoliApi
import JoliCore
import AlertToast
import Combine

enum AssetInfo {
    case video(AVPlayer)
    case image(String)
    case symbol(String)
}


extension Strings {
    
    internal static var appSupportEmail: String {
        return "smartstikr@gmail.com"
    }
    
}

struct ProductSection: Identifiable {
    
    internal init(asset: AssetInfo, title: String, subtitle: String, subtitle2: String? = nil, bulletpoints: [String]? = nil, learnMore: URL? = nil) {
        self.asset = asset
        self.title = title
        self.subtitle = subtitle
        self.bulletpoints = bulletpoints
        self.subtitle2 = subtitle2
        self.learnMore = learnMore
    }
    
    let subtitle2: String?
    let bulletpoints: [String]?
    let asset: AssetInfo
    let title: String
    let subtitle: String
    let learnMore: URL?
    
    var id: String {
        title
    }
}

public struct Product: Identifiable {
    public let companyName: String
    public let name: String
    public let description: String
    public let location: AppLocation
    public let companyLogoName: String?
    public let companyDescription: String
    public let isComingSoon: Bool
    public let experienceCls: Experience.Type
    public var iconName: String? = nil
    
    public var id: String { name }
}

public struct ReorderNowView: Experience, JoliView {
    
    public static var title: String = "Re-order Now"
    public static var basePath: String = "p"
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State public var dataModel: ExperienceData?
    public let dataModelDefault = ExperienceData.Defaults()
    
    @State public var editMode: EditMode = .inactive
    
    public init(_ data: ExperienceData? = nil) {
        self._dataModel = State(initialValue: data)
    }
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return []
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return []
    }
    
    public var contentView: some View {
        VStack(){
            Text("ReorderNow")
        }
    }
    
}

public let products: [Product] = [
    Product(companyName: "Receipe Instructions", name: "Meal Preparations", description: "Interactive meal preparation guides", location: .product("sise", "ofada"), companyLogoName: nil, companyDescription: "Meal box delivery", isComingSoon: false, experienceCls: MealboxView.self, iconName: "list.bullet.rectangle"),
    Product(companyName: "The Restaurant", name: "Reservation Check-in", description: "Seamless restaurant check-ins and menu browser", location: .product("joey", "sherman"), companyLogoName: nil, companyDescription: "Restaurant", isComingSoon: false, experienceCls: RestaurantView.self, iconName: "calendar.circle.fill"),
    Product(companyName: "Portal", name: "Brand Promotion", description: "Your frontpage for promoting brands such as products, movies and tv shows", location: .product("shows", "iacw"), companyLogoName: nil, companyDescription: "Brand", isComingSoon: false,
            experienceCls: TvShowPromoView.self, iconName: "film.fill"),
    Product(companyName: "Re-order Now!", name: "Restock Essentials Instantly", description: "Household inventory management made effortless", location: .product("stikr", "sherman"), companyLogoName: nil, companyDescription: "Ecommerce", isComingSoon: true,
            experienceCls: ReorderNowView.self, iconName: "creditcard.fill"),
    Product(companyName: "Playlist Sharing", name: "ꚠoli - Listen Together", description: "Enꚠoy music in groups with real-time voting", location: .product("joli", "joli"), companyLogoName: "logo_joli", companyDescription: "Entertainment", isComingSoon: true,
            experienceCls: ReorderNowView.self)
]

struct ContentView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
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
                    return "Welcome"
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
    
    @Binding var trialInfo: TrialInfo?
    
    var localPlaybackController: PlaybackControllerType
    
    var websocket: Socket
    
    @State var websocketCancel: AnyCancellable?
    
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    
    @Binding var currentUser: User?
    
    public init(currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType, trialInfo: Binding<TrialInfo?>){
        self._trialInfo = trialInfo
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
    }
    
    public init(currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType){
        self.init(currentUser: currentUser, websocket: websocket, localPlaybackController: localPlaybackController, trialInfo: .constant(nil))
    }
    
    let sections: [ProductSection] = [
        ProductSection(asset: .image("sise_box_ofada"),
                       title: "Services",
                       //subtitle: "Reasons To Choose SmartStikr",
                       subtitle: "No matter your e-commerce business type, SmartStikr has an innovative solution for you. Our App clips can be used for anything from welcoming guests to your restaurant or business place, providing options for customers to reach waiting staff during the dine-in process and check out with apple pay, providing interactive step by step instructions for your meal prep boxes and even up to solutions for AirBnB and Uber guests and many more. There is no limit to our innovative and interactive solutions for SmartStikr. In all of these we limit and sometimes eliminate the need for paper and we streamline the process of doing business with your business, ultimately saving you money, time and eliminating redundancy.",
                       bulletpoints: [
                        "Organised and Impressive dine-In check in processes",
                        "Seamlessly Interact with customers",
                        "Curate more intimate relationships with customers",
                        "Easily direct and improve re-order percentage",
                        "Easy & Quick “jump-to” opportunities for specific product categories that can be tailored to different groups",
                        "AirBnB Check-in and Check out processes",
                       ]
                       ),
        
        ProductSection(asset: .image("app_clip_choices"),
                       title: "The Technology - Automatically Downloading Codes",
                       subtitle: "Apple’s App Clips technology was introduced to the world in May 2020. The technology behind these scannable codes give them a notable advantage over traditional QR codes. Whereas QR Codes redirect customers to the App Store to download the app, App Clip codes take customers directly to the experience by automating the download step on the customers behalf, significantly improving convenience, driving engagement and reducing session abandonment.",
                       learnMore: URL(string: "https://developer.apple.com/app-clips/")!
                       ),
        
        ProductSection(asset: .video(AVPlayer(url: Bundle.main.url(forResource: "demo_sise_appclip", withExtension: "mp4")!)),
                       title: "Rich Customer Experience",
                       subtitle: "Our mission here at SmartStikr is simple. We want to give e-commerce businesses the ability to seamlessly organise, market and streamline their business processes and interact with customers in the language they speak using impressive user friendly technology while saving our planet at the same time."),
        
        ProductSection(asset: .video(AVPlayer(url: Bundle.main.url(forResource: "demo_sise_intro", withExtension: "mov")!)),
                       title: "Go Contactless",
                       subtitle: "Stikrs support NFC for a contactless experience."),
        
        ProductSection(asset: .symbol("leaf.fill"),
                       title: "Want to Help go Sustainable",
                       subtitle: "SmartStikr is committed to creating a greener planet by reducing paper waste and taking advantage of technology that will propel e-commerce industry to the future and forefront of technological advancement. Join us in our green earth commitment"),
        
        
        
    ]
    
    @State var activeSectionIdx: Int? = nil
    
    @Namespace var animation
    
    func sectionView(_ section: ProductSection) -> some View {
        let groupView = Group(){
            if case let .video(player) = section.asset {
                VideoPlayer(player: player)
                    .frame(height: screenWidth - 100)
                    //                                        .onTapGesture {
                    //                                            print("Tapped Video")
                    //                                            maximised.toggle()
                    //
                    //                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    //                                                if maximised {
                    //                                                    player.play()
                    //                                                } else {
                    //                                                    player.pause()
                    //                                                }
                    //                                            }
                    //                                        }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.secondaryLabel, lineWidth: 1))
            } else if case let .image(imageName) = section.asset {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: screenWidth - 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else if case let .symbol(systemName) = section.asset {
                Image(systemName: systemName)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .font(.largeTitle)
                    .frame(maxWidth: screenWidth / 2)
            }
        }
        .padding(.vertical)
        
        return Section(header: Text(section.title).font(.title2)){
            VStack(){
                Text(section.subtitle)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.light))
                    .foregroundColor(.secondaryLabel)
                    .lineLimit(nil)
                    //.fixedSize(horizontal: false, vertical: true)
                
                if let learnMore = section.learnMore {
                    Link("Learn More...", destination: learnMore).padding()
                }
                
                if let bullets = section.bulletpoints {
                    VStack(alignment: .leading) {
                        ForEach(bullets, id: \.self) { bulletpoint in
                            HStack(){
                                Image(systemName: "circlebadge.fill").renderingMode(.original)
                                Text(bulletpoint)
                            }
                            .font(Font.subheadline)
                            .padding(.vertical, 2)
                            .padding(.leading, Sizing.small)
                        }
                    }
                    .padding(.vertical)
                }
                
                groupView
                
                if let subtitle2 = section.subtitle2 {
                    Text(subtitle2)
                        .multilineTextAlignment(.center)
                        .font(.subheadline.weight(.light))
                        .foregroundColor(.secondaryLabel)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    var mainView: some View {
        VStack(){
            ForEach(sections){ section in
                self.sectionView(section)
                .padding([.bottom, .horizontal])
                
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @AppStorage("active-tab") var selectedTab: Tab = .information
    
    @State var feebackText: String = .empty
    
    @State var experienceType: Experience.Type?
    
    @State var experienceData: ExperienceData?
    
    var appclipsCodesView: some View {
        CodeDesignerView($experienceType, $experienceData) {
            
            guard let data = experienceData else {
                return
            }
            
            switch experienceType?.title {
                case MealboxView.title:
                    self.trialInfo = (.mealboxPrep, data)
                case RestaurantView.title:
                    self.trialInfo = (.restaurantCheckin, data)
                case TvShowPromoView.title:
                    self.trialInfo = (.brandPromotion, data)
                default:
                    print("Unknown")
            }
            
        }
        //.padding()
        //.padding(.top, safeAreaInsets.top)
        //.padding(.bottom, safeAreaInsets.bottom * 4)
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

                
            }
            .frame(width: screenWidth - 100)
            .padding(.top, safeAreaInsets.top * 2)
        }
        .frame(minWidth: screenWidth, minHeight: screenHeight)
        
    }
    
//    var whoWeAreText: String {
//        """
//Ditch all that paper & give your customers a more customised and streamlined experience for their meal prep boxes by digitizing through Smart Stikr App clip. The experience will be completely customised to your company style and offerings and your customers will have options to reorder or just browse your menu for other ideas and seamlessly place the order from you directly with one click through apple pay.
//
//By simply attaching one or few of the below app clips on the box delivered to the clients, you take away the need for paper instructions and
//give your customers a more involved experience to Meal Prep with you and your company.
//"""
//    }
    
    var whoWeAreText: String {
        """
SmartStikr was created with the end user in mind, to fill a gaping hole in the e-commerce consumer experience by streamlining inefficient processes to create futuristic and seamless experiences. Our App clips curates novel experiences for your business which allows customers to interact with your business on an intimate level designed to nurture that customer service relationship from a different angle that is guaranteed to expand your business reach and make your customers Stik with you.
"""
    }
    
    @Namespace var namespace
    
    var tabView: some View {
        let keyboardHidden = keyboardHeight == 0
        return HStack(){
            if keyboardHidden {
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
                            .matchedGeometryEffect(id: "tab-title", in: namespace)
                    } else: { view in
                        view.background(Color.clear)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                    .font(.subheadline.weight(selectedTab == tab ? .semibold : .light))
                    .onTapGesture {
                        self.selectedTab = tab
                    }
                }
                .opacity(keyboardHidden ? 1 : 0)
                
            } else {
                Spacer()
                Button() {
                    appCoordinator.dismissKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .padding()
                        .foregroundColor(.primary)
                        .font(.headline.weight(.light))
                }
                .matchedGeometryEffect(id: "tab-title", in: namespace)
                .opacity(keyboardHeight < 100 ? 0 : 1)
            }
        }
        .padding(keyboardHidden ? 4 : .zero)
        .frame(maxWidth: keyboardHidden ? screenWidth - 50 : nil, alignment: .center)
        .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
        .clipShape(RoundedRectangle(cornerRadius: keyboardHeight < 100 ? 25.0 : 0))
//        .if(keyboardHidden){ view in
//            view.clipShape(RoundedRectangle(cornerRadius: 25.0))
//        }
        .animation(.easeInOut)
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
                                    Text("Smart Stikr").font(.headline.weight(.light)).foregroundColor(.tertiaryLabel).padding([.bottom])
                                    (Text("Welcome to the ").font(.title.weight(.light)).foregroundColor(.tertiaryLabel)
                                        + Text("Paperless ").font(.title.weight(.light)).foregroundColor(.secondaryLabel)
                                        + Text("Future").font(.title.weight(.light)).foregroundColor(.tertiaryLabel)).multilineTextAlignment(.center)
                                    Text(whoWeAreText)
                                        .multilineTextAlignment(.center)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding()
                                    
                                    VideoPlayer(player: AVPlayer(url: Bundle.main.url(forResource: "demo_sise_code_scan", withExtension: "mov")!))
                                        .frame(height: screenWidth - 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.secondaryLabel, lineWidth: 1))
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
                                    
                                    HStack(){
                                        Spacer()
                                        
                                        Link(destination: URL(string: "https://www.instagram.com/smartstikr/")!) {
                                            VStack(){
                                                Image("instagram_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                                                Text("Follow Us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                                                Text("@smartstikr").font(.body.weight(.semibold)).foregroundColor(.primary)
                                            }
                                            .padding()
                                        }
                                        
//                                        VStack(){
//                                            Image("fbk_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
//                                            Text("Share us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
//                                            Text("#madewithsise").font(.body.weight(.semibold)).foregroundColor(.primary)
//                                        }
//                                        .padding()
                                        
                                        Spacer()
                                    }
                                    .padding(.top, safeAreaInsets.top)
                                    .padding(.bottom, safeAreaInsets.bottom * 4)
                                    .animation(.easeInOut)
                                }
                                .navigationBarTitleDisplayMode(.inline)
                                //.navigationBarTitle(Text(String.empty))
                                .navigationBarHidden(true)
                                .toolbar() {
                                    EmptyView()
                                }
                            } else if self.selectedTab == .feedback {
                                ScrollView(.vertical){
                                    feedbackView
                                }
                                .navigationBarHidden(true)
                                .toolbar() {
                                    EmptyView()
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
                        self.tabView
                    }
                    .frame(maxHeight: screenHeight - safeAreaInsets.top)
                    //.padding(.bottom, safeAreaInsets.bottom)
                    
                    
                    //            HStack(){
                    //                Button() {
                    //
                    //                }
                    //            }
                }
                   // .navigationBarTitle(Text("Welcome to Smart Stikr"), displayMode: .large)
        }
        .edgesIgnoringSafeArea(.bottom)
        .onReceive(appCoordinator.$keyboardHeight, assign: \.keyboardHeight, target: self)
        .frame(minWidth: screenWidth, idealHeight: screenHeight - safeAreaInsets.top)
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
//                .simultaneousGesture(
//                    DragGesture(minimumDistance: 100)
//                        .onChanged(){ value in
//                            print("dragged: \(value)")
//                        }
//                        .onEnded() { val in
//                            print("ended: \(val)")
//                            self.maximised = false
//                        }
//                )
                
            }
        )
        .animation(.spring())
        .onAppear(){
            self.videoUrl = Bundle.main.url(forResource: "demo_sise_intro", withExtension: "mov")
            
            guard let url = self.videoUrl else { return }
            
            //self.player = AVPlayer(url: url)
        }
    }
    
    @State var keyboardHeight: CGFloat = 0
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
