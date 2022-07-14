//
//  JoeyRestuarantView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/06/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import AlertToast
import JoliCore

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

struct RestaurantView: Experience, JoliView {
    
    static var title: String = "Restaurant"
    static var subtitle: String = "Seamless restaurant check-ins and menu browser"
    static var basePath = "emeal"
    public static var iconName: String = "menucard"
    
    @Binding var editMode: EditingState
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @State var dataModel: ExperienceData?
    
    let dataModelDefault = ExperienceData.Defaults(bannerVideoUrl: URL(staticString: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4"))
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    @State var arrivedAt: Date? = Date()
    
    @State var menu: RestaurantMenu?
    
    public init(_ data: ExperienceData? = nil, editMode: Binding<EditingState> = .constant(.inactive)){
        self._dataModel = State(initialValue: data)
        self._editMode = editMode
    }
    
    init(_ data: ExperienceData?) {
        self.init(data, editMode: .constant(.inactive))
    }
    
    static var supportedItemTypes: Set<ExperienceItemType> {
        return [.menuDrinkItem, .menuFoodItem, .menuFoodNutrition]
    }
    
    static var dataKeys: [PartialKeyPath<ExperienceData>] {
        let paths: [PartialKeyPath<ExperienceData>] = [
            \ExperienceData.socialInstagramUsername,
        ]
        
        return paths
    }
    
    var infoView: some View {
        ScrollViewReader() { proxy in
            ScrollView(showsIndicators: false){
                VStack(spacing: .zero){
                    
                    //VideoPlayer(player: joeyVideo)
                    PlayerView(url: dataModel?.bannerVideoUrl ?? dataModelDefault.bannerVideoUrl)
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
                        
                        NavigationLink(destination: RestaurantWalkinView(menu: $menu, arrivedAt: $arrivedAt).navigationTitle(Text("Walk-In"))){
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
                        
                        NavigationLink(destination: RestaurantReservationView(menu: $menu).navigationTitle(Text("Reservation"))) {
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
                        .padding(.bottom)
                        
                        RestaurantMenuButtonView(menu: $menu)
                            .frame(width: screenWidth - 100, height: 60)
                    }
                    
                    Spacer()
//                    Link("Restaurant Menu Icon by Icons8", destination: URL(string: "https://icons8.com/icon/tmr075NtT7e6/restaurant-menu")!)
//                        .font(.caption)
                }
                .frame(minHeight: screenHeight * 1.2)
                .padding(.bottom, max(100, safeAreaInsets.bottom))
                //.padding(.top, safeAreaInsets.top)
            }
            .background(Image("bg_white")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
            )
        }
    }
    
    
    var contentView: some View {
        NavigationView(){
            ZStack(){
                infoView
                    .frame(width: screenWidth, height: screenHeight)
                    .onAppear(){
                    }
            }
            .edgesIgnoringSafeArea(.vertical)
            #if !os(macOS)
            .navigationBarHidden(true)
            #endif
        }
        .edgesIgnoringSafeArea(.vertical)
        .showEditPencil(.constant(.readonly))
        .onAppear() {
            self.menu = RestaurantMenu.getDefaultMenu()
        }
    }
    
}

struct RestaurantMenuButtonView: JoliView {
    
    @Binding var menu: RestaurantMenu?
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    var contentView: some View {
        Button(){
            
            guard let menu = self.menu else {
                
                print("Unable to load menu")
                return
            }
            
            appCoordinator.modal.present() {
                return .view2(){
                    RestaurantMenuView(menu: menu)
                        .frame(width: screenWidth)
                        .eraseToAnyView()
                }
            }
        } label: {
            Label("View our menu", systemImage: "menucard")
                .font(.title3)
        }
    }
    
}

struct RestaurantReservationView: View {
    
    @Binding var menu: RestaurantMenu?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView(){
            VStack(){
                VStack(){ //
                    NetworkImage(string: "https://joeyrestaurants.com/assets/craftAssets/JOEY-HIRING-DAY-Hi-res.jpg"){
                        ProgressView()
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: screenWidth / 3)
                    
                    Text("You're one step away from the finest in morden dinning")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding()
                    Text("Sign in with us below to find your reservation")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.subheadline)
                        .foregroundColor(.secondaryLabel)
                        .padding([.horizontal, .bottom])
                    
                    Button(){
                        
                    } label: {
                        Image("logo_opentable")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                    }
                    .padding(.horizontal)
                    .background(Color.fixedWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack(alignment: .center){
                        Rectangle()
                            .frame(height: 1)
                            .padding(.leading)
                        Text("Or")
                            .font(.subheadline)
                        Rectangle()
                            .frame(height: 1)
                            .padding(.trailing)
                    }
                    .foregroundColor(.secondaryLabel)
                    .padding()
                    
                    SignInWithApple()
                        .frame(height: 60)
                        .padding(.horizontal)
                    
                    Divider().padding(.vertical)
                    RestaurantMenuButtonView(menu: $menu)
                        .padding(.bottom)
                }
                .frame(width: screenWidth - 100)
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.bottom)
                .padding(.bottom)
                .padding(.top)
            }
        }
        #if !os(macOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Image(colorScheme == .dark ? "logo_joey_full_white" : "logo_joey_full_black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: screenWidth / 2)
                                .onTapGesture {
                                    presentationMode.wrappedValue.dismiss()
                                }
        )
        #endif
        //.background(AnimatableGradientView())
    }
    
    @Environment(\.presentationMode) var presentationMode
}

struct RestaurantWalkinView: View {
    
    @Binding var menu: RestaurantMenu?
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var arrivedAt: Date?
    
    static var formatter: RelativeDateTimeFormatter {
        let fmt = RelativeDateTimeFormatter()
        fmt.dateTimeStyle = .named
        fmt.unitsStyle = .abbreviated
        //fmt.formattingContext
        return fmt
    }
    
    var formatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        return dateFormatter
    }
    
    var body: some View {
        ScrollView(){
            VStack(){
                VStack(){
                    NetworkImage(string: "https://joeyrestaurants.com/assets/craftAssets/MB_Panel5b.jpg"){
                        ProgressView()
                    }
                    .overlay(
                        Image(systemName: "timer")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: screenWidth / 4)
                            .padding()
                    )
                    .frame(minHeight: screenWidth / 3)
                    
                    HStack(alignment: .top){
                        VStack(alignment: .leading){
                            Text("Estimated wait time")
                                .font(.title.weight(.light))
                            
                            if let arrivedAt = arrivedAt {
                                Label(){
                                        Text("You arrived ")
                                            + Text(arrivedAt, formatter: RestaurantWalkinView.formatter)
                                } icon: {
                                    Image(systemName: "timer")
                                }
                                .foregroundColor(.tertiaryLabel)
                                .font(.caption)
                            }
                            
                            //Text(Date().addingTimeInterval(600), style: .timer)
                        }
                        .padding(.leading)
                        Spacer()
                        VStack(){
                            Text("3")
                                .font(.largeTitle.weight(.ultraLight))
                                .foregroundColor(.primary)
                            Text("mins")
                                .font(.caption)
                                .foregroundColor(.secondaryLabel)
                        }
                        .padding(.trailing)
                    }
                    
                    Text("Would you like us to notify you instead when your table is ready?")
                        .padding()
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundColor(.secondaryLabel)
                    
                    Button(){
                    } label: {
                        Label("Notify Me", systemImage: "bell.circle.fill")
                            .font(.title3)
                            .foregroundColor(.label)
                            
                    }
                    .padding(.horizontal)
                    .background(Color.systemIndigo)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    ))
                    //.frame(width: screenWidth - 100, height: 60)
                    .accentColor(.systemIndigo)
                    .buttonStyle(OutlineButton())
                    .padding(.bottom)
                    
                    Divider().padding(.vertical)
                    RestaurantMenuButtonView(menu: $menu)
                        .padding(.bottom)
                }
                .frame(width: screenWidth - 100)
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.bottom)
                .padding(.bottom)
                .padding(.top)
            }
        }
        #if !os(macOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Image(colorScheme == .dark ? "logo_joey_full_white" : "logo_joey_full_black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: screenWidth / 2)
                                .onTapGesture {
                                    presentationMode.wrappedValue.dismiss()
                                }
        )
        #endif
        .onAppear(){
            
        }
        
        //.background(AnimatableGradientView())
    }
}

struct RestaurantMenuView: View {
    
    @State var menu: RestaurantMenu
    @State private var selectedTab: Int = 0
    
    var tabNames: [String] {
        let drinks: [String] = RestaurantDrink.Category.allCases.map() { "Drink - \($0.rawValue)" }
        return ["Food"] + drinks
    }
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    func drinkView(_ category: RestaurantDrink.Category) -> some View {
        
        return VStack(alignment: .leading){
                Text("Drink - \(category.rawValue)".uppercased())
                    .lineLimit(2)
                    .font(.largeTitle.weight(.ultraLight))
                    .fixedSize(horizontal: true, vertical: true)
                    .padding()
                    .padding(.top, safeAreaInsets.top)
                ForEach(menu.drinks, id: \.id) { drinkGroup in
                    
                    if let drinks = drinkGroup.items.filter() { $0.category == category }, !drinks.isEmpty {
                        
                        if let url = drinkGroup.imageUrl {
                            NetworkImage(url: url){
                                ProgressView()
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: screenWidth, height: screenWidth / 2)
                            .clipped()
                        }
                        
                        Section(header: Text(drinkGroup.title).font(.title.weight(.light)).padding()){
                            VStack(){
                                ForEach(drinks) { itm in
                                    self.drinkView(itm)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                }
            }
            .padding(.horizontal)
    }
    
    func drinkView(_ itm: RestaurantDrink) -> some View {
        HStack(){
            VStack(alignment: .leading) {
                Text(itm.title)
                    .fontWeight(.light)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.subheadline)
                
//                if let subtitle = itm.subtitle {
//                    Text(subtitle)
//                        .fontWeight(.light)
//                        .multilineTextAlignment(.leading)
//                        .fixedSize(horizontal: false, vertical: true)
//                        .foregroundColor(.secondaryLabel)
//                }
            }
            Spacer()
            
            Text(itm.price)
                .font(.title3.weight(.light))
                .foregroundColor(.secondaryLabel)
                .padding()
        }
        
    }
    
    func itemView(_ itm: RestaurantMeal) -> some View {
        HStack(){
            
            Text(itm.dietary ?? " ")
                .frame(minWidth: 5)
                .font(.caption)
                .foregroundColor(.tertiaryLabel)
            
            VStack(alignment: .leading) {
                Text(itm.title).font(.title3)
                
                if let subtitle = itm.subtitle {
                    Text(subtitle)
                        .fontWeight(.light)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.secondaryLabel)
                }
            }
            Spacer()
            
            Text(itm.price)
                .font(.title3.weight(.light))
        }
        
    }
    
    var foodView: some View {
            VStack(alignment: .leading){
                ForEach(menu.foods, id: \.id) { foodGroup in
                    
                    
                    if let url = foodGroup.imageUrl {
                        NetworkImage(url: url){
                            ProgressView()
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(height: screenWidth / 2)
                        .clipped()
                    }
                    
                    Section(header: Text(foodGroup.title).font(.title.weight(.semibold)).padding()){
                        VStack(){
                            ForEach(foodGroup.items) { itm in
                                self.itemView(itm)
                                    .padding([.bottom, .horizontal])
                            }
                        }
                    }
                    .padding(.bottom)
                }
                
            }
    }
    
    var body: some View {
        ZStack(){
            TabView(selection: $selectedTab) {
                
                ScrollView(.vertical){
                    foodView
                }
                .frame(maxWidth: screenWidth)
                .tag(0)
                
                ForEach(Array(RestaurantDrink.Category.allCases.enumerated()), id: \.offset) { item in
                    
                    ScrollView(.vertical){
                        self.drinkView(item.element)
                    }
                    .frame(maxWidth: screenWidth)
                    .tag(item.offset + 1)
                }
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            #endif
            .navigationTitle(Text(tabNames.count > selectedTab ? tabNames[selectedTab] : ""))
            
            VStack(){
                Color.white.opacity(0.2).frame(width: screenWidth, height: 50)
                Spacer()
            }
        }
        .frame(width: screenWidth)
    }
}


struct RestaurantProxyView: View {
    public var body: some View {
        return RestaurantView()
    }
}

