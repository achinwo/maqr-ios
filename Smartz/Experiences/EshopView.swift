//
//  EshopView.swift
//  Joli
//
//  Created by Anthony Chinwo on 12/07/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

#if !os(macOS)
import SharedUI
import AsyncCompatibilityKit
#endif

struct DummyProduct: Codable {
    let id: Int
    let title: String
    let price: Double
    let dummyProductDescription, category: String
    let image: String
    let rating: Rating

    enum CodingKeys: String, CodingKey {
        case id, title, price
        case dummyProductDescription = "description"
        case category, image, rating
    }
}

// MARK: - Rating
struct Rating: Codable {
    let rate: Double
    let count: Int
}

struct DummyProductResponse: Codable {
    let success: Bool
    let datatype: String
    let numOfResults, lastPage, page: Int
    let data: [DummyProduct]
}

struct EshopView: JoliView, Experience {
    
    enum Tab: Int, Identifiable, CaseIterable {
        case browse
        case orders
        case support
        
        var id: Int {
            rawValue
        }
        
        var label: String {
            switch self {
                case .support:
                    return "Support"
                case .orders:
                    return "Orders"
                case .browse:
                    return "Browse"
            }
        }
        
        var color: Color {
            switch self {
                case .support:
                    return Color.systemIndigo
                case .orders:
                    return .pink
                case .browse:
                    return .green
            }
        }
        
        var emoji: (default: String, active: String) {
            switch self {
                case .support:
                    return (default: "questionmark.circle", active: "questionmark.circle.fill")
                case .orders:
                    return (default: "list.dash", active: "list.number")
                case .browse:
                    return (default: "bag", active: "bag.fill")
            }
        }
    }
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var dataModel: ExperienceData?
    
    var dataModelDefault: ExperienceData.Defaults
    
    @State var editMode: EditingState = .inactive
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    static var title: String = "eShop"
    
    static var subtitle: String = "Mini-ecommerce page to sell products and services"
    
    static var iconName: String = "bag"
    
    static var basePath: String = "eshop"
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
            \ExperienceData.bannerImageUrl,
             \ExperienceData.backgroundImageUrl,
             \ExperienceData.brandContactEmail,
             \ExperienceData.productName,
             \ExperienceData.productDescription,
             \ExperienceData.productImageUrl,
             \ExperienceData.socialInstagramUsername,
             \ExperienceData.socialFacebookPage,
        ]
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return [.product]
    }
    
//   @State public var products: [DummyProduct] = []
//        ExperienceData.Item(experienceItemType: .product, aliasTitle: , defaultPrice: , imageName: ,
//                            itemGrouping: , itemSubgrouping: , subtitle: , title: , uuid: UUID().uuidString),
//    ]
    
    var items: [ExperienceData.Item] {
        return (dataModel?.items ?? []).compactMap() { p in

            guard !searchText.isEmpty else {
                return p
            }

            guard let title = p.title, let desc = p.subtitle,
                  title.lowercased().contains(searchText.lowercased()) || desc.lowercased().contains(searchText.lowercased())
            else { return nil }

            return p
        }
    }
    
    @State var selectedProduct: ExperienceData.Item? = nil
    @State var searchText: String = .empty
    @AppStorage("active-tab-eshop") var selectedTab = Tab.browse
    @AppStorage("onboarding-flag-welcomed") var hasBeenWelcomed = false
    @Environment(\.colorScheme) var colorScheme
    
    init(_ data: ExperienceData?) {
        self._dataModel = State(initialValue: data)
        self.dataModelDefault = ExperienceData.Defaults()
    }
    
    func shopItemView(_ item: ExperienceData.Item) -> some View {
        VStack(alignment: .leading) {
            NetworkImage(string: item.imageName) {
                ProgressView()
            }
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: screenWidth / 2, minHeight: screenWidth / 4)
            .padding()
            .layoutPriority(9)
            .id(item.imageName)
            
            if selectedProducts[item.id] != nil {
                Label(){
                    Text("Added")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundColor(.green)
                .font(.callout)
                .padding(.bottom, 2)
            }
            
            Text(item.title ?? "Product")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 2)
                .layoutPriority(10)
            
            Text(item.subtitle ?? "Product description")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack(){
                Text(item.itemGrouping ?? "Category")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundColor(.white)
                    .background(Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer()
                Text("£\((item.defaultPrice ?? 0) / 100)")
                    .font(.headline.weight(.thin))
                    .foregroundColor(.primary)
                    //.fontWeight(.semibold)
            }
            .multilineTextAlignment(.leading)
            .font(.subheadline)
            .padding(2)
            .layoutPriority(8)
        }
    }
    
    var contentView: some View {
        ZStack(){
            contentView2
        }
        .frame(maxWidth: screenWidth, maxHeight: screenHeight)
        .edgesIgnoringSafeArea(.all)
    }
    
    @State var selectedProducts = [String: Int]()
    
    //https://dribbble.com/shots/18733610-TokoMegawa-E-Commerce
    var contentView2: some View {
        let columns = [
            GridItem(.adaptive(minimum: screenWidth / 3, maximum: screenWidth / 2), spacing: Sizing.small),
            GridItem(.adaptive(minimum: screenWidth / 3, maximum: screenWidth / 2), spacing: Sizing.small)
        ]
        
        //let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        
        return NavigationView(){
            ZStack(){
                
                Group(){
                    if self.selectedTab == .browse {
                        ScrollView(.vertical) {
                            
                            LazyVGrid(columns: columns) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        ProductView(product: item, selectedProducts: $selectedProducts)
                                    } label: {
                                        self.shopItemView(item)
                                            .id("button-\(item.id)")
                                    }
                                    .padding()
                                    .frame(maxHeight: screenWidth / 1.2)
                                    .frame(maxWidth: screenWidth / 2.2)
                                    .id(item.id)
                                }
                            }
                            .padding()
                            .padding(.bottom, max(16, safeAreaInsets.bottom))
                            .padding(.top, safeAreaInsets.top)
                        }
                    } else if self.selectedTab == .orders {
                        OrderStatusView()
                    } else if self.selectedTab == .support {
                        Text("Support")
                    }
                }
                .frame(maxWidth: screenWidth, maxHeight: screenHeight)
                
                VStack(){
                    Spacer()
                        .frame(minHeight: screenHeight * 0.6)
                    HStack(){
                        ForEach(Tab.allCases) { tab in
                            Button() {
                                self.selectedTab = tab
                            } label: {
                                HStack(){
                                    Image(systemName: selectedTab == tab ? tab.emoji.active : tab.emoji.default)
                                    Text(tab.label)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: true)
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
                    .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                    //.animation(.easeInOut)
                }
                //.padding(.bottom, max(16, safeAreaInsets.bottom))
                
            }
            
            .toolbar() {
                
                ToolbarItem(placement: .principal){
                    TextField("Search", text: $searchText)
                        .padding(Sizing.small / 2.5)
                            
#if os(macOS)
                        .background(Color(.systemGray))
#else
                        .background(Color(.systemGray6))
#endif
                            .cornerRadius(8)
                    .frame(maxWidth: screenWidth * 0.65)
                }
                
#if os(macOS)
                let toolbarPlacement: ToolbarItemPlacement = .automatic
#else
                let toolbarPlacement: ToolbarItemPlacement = .navigationBarTrailing
#endif
                
                ToolbarItem(placement: toolbarPlacement){
                    Button(){
                        print("Tapped cart!")
                    } label: {
                        Image(systemName: selectedProducts.isEmpty ? "cart" : "cart.fill")
                    }
                    .disabled(selectedProducts.isEmpty)
                    .overlay(
                        GeometryReader(){ proxy in
                            ZStack(alignment: .topTrailing){
                                if !selectedProducts.isEmpty {
                                    Text(selectedProducts.values.reduce(0, +).description)
                                        .foregroundColor(.fixedWhite)
                                        .padding(2)
                                        .fixedSize()
                                        .font(.caption2.weight(.light))
                                        .frame(width: Sizing.small, height: Sizing.small)
                                        .backgroundColor(.red)
                                        .cornerRadius(Sizing.small / 2)
                                        .offset(x: Sizing.small / 3, y: -1 * (Sizing.small / 3))
                                        .onAppear(){
                                            print("values: \(selectedProducts)\nsum: \(selectedProducts.values)")
                                        }
                                }
                            }
                            .animation(.easeInOut)
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topTrailing)
                            //.backgroundColor(.green)
                        }
                    )
                }
         
            }
            .navigationTitle("Katty Food & Drinks")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            
        }
        .ignoresSafeArea(edges: .bottom)
        //.searchable(text: $queryString)
        //.task(){
            //let req = URLRequest(url: URL(staticString: "https://fakestoreapi.com/products"))
            //let (data, _) = try! await api.urlSession.data(for: req)
//            let data: Data = SAMPLE_DATA.data(using: .utf8)!
//            let products: [DummyProduct] = try! Musicroom.jsonDecoder().decode([DummyProduct].self, from: data)
//
//            let itemss = products.map() { p in
//                ExperienceData.Item(experienceItemType: .product, defaultPrice: Int(p.price * 100),
//                                    imageName: p.image, itemGrouping: p.category,
//                                    subtitle: p.dummyProductDescription, title: p.title, uuid: p.image)
//            }
//
//            for item in itemss {
//                let properties: StikrExperienceDataItemRecord.PersistedType.PropertiesDict = [.experienceId: (self.dataModel?.stored?.id ?? 2) as AnyObject,
//                                                                                              .experienceItemType: item.experienceItemType.rawValue as AnyObject,
//                                                                                              .imageName: item.imageName as AnyObject,
//                                                                                              .defaultPrice: item.defaultPrice as AnyObject,
//                                                                                              .itemGrouping: item.itemGrouping as AnyObject,
//                                                                                              .subtitle: item.subtitle as AnyObject,
//                                                                                              .title: item.title as AnyObject,
//                                                                                              .uuid: UUID().uuidString as AnyObject]
//                let expData = StikrExperienceDataItemRecord(properties: properties)
//                let result = try? await expData.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
//
//                print("saved \(result?.title): \(result)")
//            }
            
//            ExperienceData.Item(experienceItemType: .product, ,
//                                imageName: p.image, itemGrouping: p.category,
//                                subtitle: p.dummyProductDescription, title: p.title, uuid: p.image)
 //       }
    }
    
}

import UserNotifications

struct OrderStatusView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var notificationSettings: UNNotificationSettings? = nil
    
    let apnTokenPublisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
    
    @Namespace var namespace
    
    var contentView: some View {
        VStack(){
            Spacer()
            Text("Track Orders")
                .font(.title2)
                .padding()
            
            Group(){
                if let settings = notificationSettings, ![.denied, .notDetermined].contains(settings.authorizationStatus) {
                    Text("We've notify you as your order status changes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .matchedGeometryEffect(id: "notif-button", in: namespace)
                } else {
                    Button(){
                        print("subscribe for notifciation!")
                        appCoordinator.requestedNotificationPermission.send(Date())
                    } label: {
                        HStack(){
                            Spacer()
                            HStack(){
                                Text("Notify Me!")
                                Image(systemName: "bell.fill")
                            }
                            .font(.title3)
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                    .accentColor(.purple)
                    .background(Color.purple)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .frame(width: screenWidth - 100, height: 60)
                    .buttonStyle(OutlineButton())
                    .matchedGeometryEffect(id: "notif-button", in: namespace)
                }
            }
            
            Spacer()
            Spacer()
        }
        .onAppear(perform: refreshNotificationStatus)
        .onReceive(apnTokenPublisher) { _ in
            refreshNotificationStatus()
        }
    }
    
    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.notificationSettings = settings
        }
    }
    
}

struct ProductView: View {
    
    @State var product: ExperienceData.Item
    @Binding var selectedProducts: [String: Int]
    
    var body: some View {
        VStack() {
            NetworkImage(string: product.imageName) {
                ProgressView()
            }
            .aspectRatio(contentMode: .fit)
            .padding()
            .frame(maxHeight: screenHeight / 3)
            .layoutPriority(9)
            .id(product.imageName)
            
            if selectedProducts[product.id] != nil {
                Label(){
                    Text("Added")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }.foregroundColor(.green)
            }
            
            HStack(alignment: .top){
                
                VStack(alignment: .leading){
                    Text(product.title ?? "Product")
                        .multilineTextAlignment(.leading)
                        .padding(.top)
                    Text(product.itemGrouping ?? "Category")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundColor(.white)
                        .background(Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.leading)
                
                
                Spacer()
                
                VStack(alignment: .center){
                    Button(){
                        let newCount = (selectedProducts[product.id] ?? 0) + 1
                        selectedProducts[product.id] = newCount
                        print("values: \(selectedProducts)\nsum: \(selectedProducts.values)")
                        
                            //self.selectedProducts = Dictionary(uniqueKeysWithValues: selectedProducts.map() { ($0.key, $0.value) })
                    } label: {
                        Image(systemName: "cart.badge.plus")
                    }
                    .padding(.horizontal)
                    
                    Text("£\((product.defaultPrice ?? 0) / 100)")
                        .font(.headline.weight(.thin))
                        .foregroundColor(.primary)
                        //.fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .font(.title2)
                        .padding()
                }
                .font(.title3)
                .padding()
                .layoutPriority(10)
                
                
            }
            
            Text(product.subtitle ?? "Product description")
                .font(.subheadline)
                .padding(.horizontal)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .toolbar() {
            
            #if os(macOS)
            let toolbarPlacement: ToolbarItemPlacement = .automatic
            #else
            let toolbarPlacement: ToolbarItemPlacement = .navigationBarTrailing
            #endif
            
            ToolbarItem(placement: toolbarPlacement){
                Button(){
                    print("Tapped cart!")
                } label: {
                    Image(systemName: selectedProducts.isEmpty ? "cart" : "cart.fill")
                }
                .disabled(selectedProducts.isEmpty)
                .overlay(
                    GeometryReader(){ proxy in
                        ZStack(alignment: .topTrailing){
                            if !selectedProducts.isEmpty {
                                Text(selectedProducts.values.reduce(0, +).description)
                                    .foregroundColor(.fixedWhite)
                                    .padding(2)
                                    .fixedSize()
                                    .font(.caption2.weight(.light))
                                    .frame(width: Sizing.small, height: Sizing.small)
                                    .backgroundColor(.red)
                                    .cornerRadius(Sizing.small / 2)
                                    .offset(x: Sizing.small / 3, y: -1 * (Sizing.small / 3))
                            }
                        }
                        .animation(.easeInOut)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topTrailing)
                            //.backgroundColor(.green)
                    }
                )
            }
            
        }
    }
    
}
