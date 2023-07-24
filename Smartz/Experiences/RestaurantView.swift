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

struct CustomDisclosureGroupStyle<Label: View>: DisclosureGroupStyle {
    let button: Label
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            button
                .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
        }
        .contentShape(Rectangle())
        
        if configuration.isExpanded {
            configuration.content
                .padding(.leading, 30)
        }
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
    
    let dataModelDefault = ExperienceData.Defaults(logoImageUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/logo_joey_full_dark.png"),
                                                   
                                                   bannerVideoUrl: URL(staticString: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4"),
                                                   brandName: "JOEY Sherway",
                                                   cardTitle: "HELLO & WELCOME",
                                                   cardSubtitle: "restaurant features a warm and modern industrial design and a seasonal rooftop patio in this popular Toronto neighbourhood gathering spot."
    )
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    @State var arrivedAt: Date? = Date()
    
    @State var menu: RestaurantMenu?
    
    var isDefaultView: Bool {
        return self.dataModel == nil
    }
    
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
             \ExperienceData.bannerImageUrl,
             //\ExperienceData.
        ]
        
        return paths
    }
    
    @State var currentTab: Int = 0
    @State var selectedMenuGroup: String? = nil
    
    var groupedItems: [String: [String: [ExperienceData.Item]]] {
        var res: [String: [String: [ExperienceData.Item]]] = [:]
        
        for item in (dataModel?.items ?? []).filter({ $0.experienceItemType == .menuFoodItem }) {
            
            guard let grouping = item.itemGrouping, let subgrouping = item.itemSubgrouping else { continue }
            
            var existing: [String: [ExperienceData.Item]] = res[grouping] ?? [:]
            
            var items = existing[subgrouping] ?? []
            items.append(item)
            
            existing[subgrouping] = items
            res[grouping] = existing
        }
        
        return res
    }
    
    @State private var flag = false
    
    func makeFoodItem(subgroup: String, items: [ExperienceData.Item]) -> some View {
        DisclosureGroup() {
            
            VStack(alignment: .leading){
                ForEach(items.sorted(by: { $0.title! > $1.title! }), id: \.title) { item in
                    HStack(alignment: .top, spacing: Sizing.small){
                        AsyncImage(url: URL.fromString(item.imageName)){ image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } placeholder: {
                            ProgressView()
                        }
                        .clipped()
                        .id(item.imageName)
                        
                        VStack(alignment: .leading){
                            HStack(){
                                Text(item.title ?? "").font(.headline)
                                
                                Spacer()
                                
                                if let price = item.defaultPrice {
                                    Text(String(format: "£%.2f", Double(price) / 100.0)).font(.subheadline.bold())
                                }
                            }
                            
                            
                            Text(item.subtitle ?? "").font(.subheadline).padding(.top, Sizing.small)
                            
                            if appCoordinator.activeAuth?.user.id == dataModel?.stored?.createdById {
                                HStack(){
                                    Spacer()
                                    
                                    VStack(alignment: .leading){
                                        Toggle(flag ? "Soldout" : "Available", isOn: $flag)
                                            .labelsHidden()
                                            .tint(flag ? Color.red : Color.fixedGreen)
                                        Text(flag ? "Soldout" : "Available").font(.caption.weight(.light))
                                    }
                                }
                            }
                        }
                        
                    }
                    
                    Spacer()
                }
                
            }
            .padding()
        } label: {
            HStack(){
                Text(subgroup)
                Spacer()
            }
            .padding()
        }
        .tint(.primary)
        .padding(.horizontal)
    }
    
    var menuView: some View {
        
        ScrollView(.vertical){
            VStack(alignment: .center){
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(){
                        ForEach(Array(self.groupedItems.keys).sorted(), id: \.self) { group in
                            Button() {
                                self.selectedMenuGroup = group
                            } label: {
                                HStack(){
                                    Text(group)
                                        .tag(group)
                                        .font(.subheadline)
                                }
                                .padding()
                            }
                            .buttonStyle(BlackWhiteButtonStyle(inverted: self.selectedMenuGroup == group))
                        }
                    }
                }
                .padding()
                
                
                if let groupName = self.selectedMenuGroup, let subgroupItems = self.groupedItems[groupName] {
                    
                    ForEach(Array(subgroupItems.keys), id: \.self) { subgroup in
                        
                        let items: [ExperienceData.Item] = subgroupItems[subgroup] ?? []
                        
                        Group(){
                            self.makeFoodItem(subgroup: subgroup, items: items)
                        }
                        .backgroundColor(.secondarySystemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding([.horizontal, .top])
                        
                    }
                }
            }
            .padding(.bottom, max(100, safeAreaInsets.bottom))
        }
        .onAppear() {
            self.selectedMenuGroup = self.selectedMenuGroup ?? self.groupedItems.keys.first
        }
        
    }
    
    var tabView: some View {
        VStack(spacing: .zero) {
            TabBarView(currentTab: self.$currentTab, tabNames: .constant(["Menu", "About Us"]))
                .backgroundColor(.fixedWhite)
            
            TabView(selection: self.$currentTab) {
                self.menuView
                .tag(0)
                
                VStack(){
                    Text((try? AttributedString(markdown: dataModel?.landingPageText ?? "")) ?? AttributedString(dataModel?.brandName ?? ""))
                    .multilineTextAlignment(.center)
                    .padding()
                    Spacer()
                }
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    var newView: some View {
        VStack(){
            
            HStack(){
                
                VStack(alignment: .leading, spacing: Sizing.medium){
                    Text(dataModel?.brandName ?? "")
                        .font(.title2)
                    
                    HStack(){
                        Label("22 Dec | 7pm", systemImage: "calendar")
                            .foregroundColor(.secondary)
                            .font(.footnote.weight(.semibold))
                            .padding(.trailing)
                        
                        Label("Grays, Essex", systemImage: "mappin")
                            .foregroundColor(.secondary)
                            .font(.footnote.weight(.semibold))
                    }
                    
                }
                
                Spacer()
                
                VStack(){
                    if let deliverooUrl = dataModel?.storeUbereatsUrl {
                        Link(destination: deliverooUrl) {
                            Image("logo_ubereats")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: Sizing.xxLarge + Sizing.small)
                        }
                    }
                    
                    if let deliverooUrl = dataModel?.storeDeliverooUrl {
                        Link(destination: deliverooUrl) {
                            Image("logo_deliveroo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: Sizing.xxLarge + Sizing.small)
                        }
                    }
                }
            }
            .padding()
            
            HStack(){
                
                if let tel = dataModel?.brandContactPhoneNumber {
                    Label(tel, systemImage: "phone")
                        .padding()
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                
                
                
                Button() {
                    guard let username = dataModel?.socialInstagramUsername else {
                        return
                    }
                    
                    openURL(SocialLink.instagramUser(username).url)
                } label: {
                    HStack(){
                        Image("logo_instagram_white")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: Sizing.small)
                        Text("Follow")
                            .font(.subheadline)
                    }
                    .padding()
                }
                .buttonStyle(BlackWhiteButtonStyle(inverted: true))
                .padding()
            }
            .backgroundColor(.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .padding()
            
            self.tabView
        }
    }
    
    @Environment(\.openURL) var openURL
    
    var contentView: some View {
        NavigationView(){
            ZStack(){
                ScrollViewReader() { proxy in
                    ScrollView(showsIndicators: false){
                        VStack(spacing: .zero){
                            
                            VStack(alignment: .center){
                                
                                
                                HStack(){
                                    Spacer()
                                    Button(){
                                        
                                    } label: {
                                        Image(systemName: "heart")
                                            .font(.title3)
                                    }
                                    .padding()
                                    .foregroundColor(.primary)
                                    .backgroundColor(.fixedWhite)
                                    .clipShape(Circle())
                                }
                                .padding(.horizontal)
                                .padding(.top, safeAreaInsets.top)
                                Spacer()
                            }
                            .background(
                                Group(){
                                    if let bannerImgUrl = self.dataModel?.bannerImageUrl {
                                        AsyncImage(url: bannerImgUrl)
                                            .clipped()
                                    } else {
                                        PlayerView(url: dataModel?.bannerVideoUrl ?? dataModelDefault.bannerVideoUrl)
                                    }
                                }
                            )
                            .frame(width: screenWidth, height: screenWidth / 1.6)
                            .clipped()
                            
                            
                            if self.isDefaultView {
                                self.legacyView
                            } else {
                                self.newView
                            }
                            
                            Spacer()
                        }
                        .frame(minHeight: screenHeight * 1.2)
                            //.padding(.top, safeAreaInsets.top)
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
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
    
    var legacyView: some View {
        VStack(){
            AsyncImage(url: dataModel?.logoImageUrl ?? dataModelDefault.logoImageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: screenWidth * 0.7)
                    .padding()
                    .padding(.vertical)
            } placeholder: {
                ProgressView()
            }
            .id("brand")
            
            VStack(){
                Section(header: Text(dataModel?.cardTitle ?? dataModelDefault.cardTitle).font(.title3)) {
                    (Text("\(dataModel?.brandName ?? dataModelDefault.brandName) ").font(.subheadline.weight(.semibold))
                     + Text(dataModel?.cardSubtitle ?? dataModelDefault.cardSubtitle)
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
        }
    }
    
}

struct RestaurantProxyView: View {
    public var body: some View {
        return RestaurantView()
    }
}



struct Previews_RestaurantView_Previews: PreviewProvider {
    static var previews: some View {
        let defaults = ExperienceData.Defaults(logoImageUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/logo_joey_full_dark.png"),
                                               bannerVideoUrl: URL(staticString: "https://joeyrestaurants.com/assets/craftAssets/Joey-Restaurants-Welcome-Back-With-Audio.mp4"),
                                               brandName: "JOEY Sherway",
                                               cardTitle: "HELLO & WELCOME",
                                               cardSubtitle: "restaurant features a warm and modern industrial design and a seasonal rooftop patio in this popular Toronto neighbourhood gathering spot.",
                                               items: [
                                                .makeFookItem("Dumplings", description: "The dish typically consists of chicken, dumplings, and vegetables.", imageName: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Xiaolongbao-breakfast.jpg/640px-Xiaolongbao-breakfast.jpg",
                                                    grouping: "Suya", subgrouping: "Beef")
                                               ]
        )
        let restaurantData = ExperienceData.fromDefaults(defaults, type: .restaurant)
        
        return RestaurantView(restaurantData)
            .environmentObject(AppCoordinator())
    }
}
