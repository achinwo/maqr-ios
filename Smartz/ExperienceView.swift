//
//  ExperienceView.swift
//  Joli
//
//  Created by Anthony Chinwo on 02/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import Combine



public class ExperienceData: ObservableObject {
    
    static let DEFAULT_BRAND_NAME = "SmartStikr"
    
    @Published var editStartedAt: Date? = nil
    
    // sourcery: title = "Logo Image", description = "Your brand logo image"
    @Published var logoImageUrl: URL?
    
    // sourcery: title = "Banner Image", description = "Banner image of landing page"
    @Published var bannerImageUrl: URL?
    
    // sourcery: title = "Banner Video", description = "Banner video of landing page"
    @Published var bannerVideoUrl: URL?
    
    // sourcery: title = "Background Image", description = "Default background image for your brand"
    @Published var backgroundImageUrl: URL?
    
    // sourcery: title = "Brand Name", description = "Name of your company or brand"
    @Published var brandName: String
    
    // sourcery: title = "Welcome Message", description = "Invite customers to your brand experience"
    @Published var landingPageText: String
    
    // sourcery: title = "Instagram", description = "Instagram account username"
    @Published var socialInstagramUsername: String?
    
    init(brandName: String? = nil, landingPageText: String? = nil) {
        self.brandName = brandName ?? Self.DEFAULT_BRAND_NAME
        self.landingPageText = landingPageText ?? "Welcome to YOUR brand"
    }
}

public protocol Experience {
    //associatedtype Model: ExperienceData
    var dataModel: ExperienceData { get }
    var editMode: EditMode { get nonmutating set }
    static var dataKeys: [PartialKeyPath<ExperienceData>] { get }
    static var allDataKeys: [PartialKeyPath<ExperienceData>] { get }
}

public extension JoliView where Self: Experience {
    
    static var allDataKeys: [PartialKeyPath<ExperienceData>] {
        return Self.primaryDataKeys + Self.dataKeys
    }
    
    static var primaryDataKeys: [PartialKeyPath<ExperienceData>] {
        let paths: [PartialKeyPath<ExperienceData>] = [
            \ExperienceData.brandName,
            \ExperienceData.logoImageUrl,
            \ExperienceData.landingPageText
        ]
        
        return paths
    }
    
    var body: some View {
        return self.contentView
            .onReceive(appCoordinator.connectionStateSubject) { state in
                self.onConnectionStateChange(state.state)
            }
            .onReceive(dataModel.$editStartedAt) { dt in
                self.editMode = dt != nil ? .active : .inactive
            }
    }
}

struct EditPencilViewModifier: ViewModifier {
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Binding var displayMode: ViewDisplayMode
    @State var editMode: EditMode = .inactive
    
    func body(content: Content) -> some View {
        
        let editOverlay = VStack(){
            HStack(){
                Spacer()
                Group(){
                    if editMode == EditMode.active {
                        Text("Save")
                            .fixedSize()
                            .frame(width: 32, height: 32)
                            .padding()
                    } else {
                        Image(systemName: "pencil")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .padding()
                    }
                }
                .onTapGesture {
                    self.editMode = editMode == EditMode.active ? EditMode.inactive : EditMode.active
                }
                .foregroundColor(.primary)
                .background(Circle().foregroundColor(.blue).opacity(0.6))
                .padding(.top, safeAreaInsets.top)
                .padding(.trailing)
            }
            Spacer()
        }
        
        return Group(){
            if displayMode != .readonly {
                content
                    .environment(\.editMode, $editMode)
                    .overlay(editOverlay)
            } else {
                content
            }
        }
    }
}

extension View {
    func showEditPencil(_ displayMode: Binding<ViewDisplayMode>) -> some View {
        self.modifier(EditPencilViewModifier(displayMode: displayMode))
    }
}

enum ViewDisplayMode {
    case preview
    case readonly
}

struct RestaurantView: Experience, JoliView {
    
    @Binding var editMode: EditMode
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let dataModel: ExperienceData
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    @State var arrivedAt: Date? = Date()
    
    @State var menu: RestaurantMenu?
    
    public init(data: ExperienceData? = nil, editMode: Binding<EditMode> = .constant(.inactive)){
        self.dataModel = data ?? ExperienceData()
        self._editMode = editMode
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
        NavigationView(){
            ZStack(){
                infoView
                    .frame(width: screenWidth, height: screenHeight)
                    .onAppear(){
                    }
            }
            .edgesIgnoringSafeArea(.vertical)
            .navigationBarHidden(true)
        }
        .edgesIgnoringSafeArea(.vertical)
        .showEditPencil(.constant(.readonly))
        .onAppear() {
            self.menu = RestaurantMenu.getDefaultMenu()
            
            print("MENU: \(self.menu)")
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
            
            let preview: AppPreview = .view2(){
                RestaurantMenuView(menu: menu)
                    .frame(width: screenWidth)
                    .frame(minHeight: screenHeight - safeAreaInsets.top)
                    .eraseToAnyView()
            }
            
            appCoordinator.globalModalSubject.send(preview)
        } label: {
            Label(){
                Text("View our menu")
                
            } icon: {
                Image("restaurant_menu")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)
                
            }
            .font(.title3)
        }
    }
    
}

extension Color {
    static func random()->Color {
        let r = Double.random(in: 0 ... 1)
        let g = Double.random(in: 0 ... 1)
        let b = Double.random(in: 0 ... 1)
        return Color(red: r, green: g, blue: b)
    }
}

struct AnimatableGradientView: View {
    @State private var gradientA: [Color] = [.white, .red]
    @State private var gradientB: [Color] = [.white, .blue]
    
    @State private var firstPlane: Bool = true
    
    func setGradient(gradient: [Color]) {
        if firstPlane {
            gradientB = gradient
        }
        else {
            gradientA = gradient
        }
        firstPlane = !firstPlane
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: self.gradientA), startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 1)))
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: self.gradientB), startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 1)))
                .opacity(self.firstPlane ? 0 : 1)
            ///this button just demonstrates the solution
            Button(action:{
                withAnimation(.spring()) {
                    self.setGradient(gradient: [Color.random(), Color.random()])
                }
            })
            {
                Text("Change gradient")
            }
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
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Image(colorScheme == .dark ? "logo_joey_full_white" : "logo_joey_full_black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: screenWidth / 2)
                                .onTapGesture {
                                    presentationMode.wrappedValue.dismiss()
                                }
        )
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
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Image(colorScheme == .dark ? "logo_joey_full_white" : "logo_joey_full_black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: screenWidth / 2)
                                .onTapGesture {
                                    presentationMode.wrappedValue.dismiss()
                                }
        )
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
        
        return ScrollView(.vertical){
            VStack(alignment: .leading){
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
        ScrollView(.vertical){
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
    }
    
    var body: some View {
        //NavigationView(){
        ZStack(){
            
            TabView(selection: $selectedTab) {
                
                foodView
                    .frame(maxWidth: screenWidth)
                    .tag(0)
                
                ForEach(Array(RestaurantDrink.Category.allCases.enumerated()), id: \.offset) { item in
                    self.drinkView(item.element)
                        .frame(maxWidth: screenWidth)
                        .tag(item.offset + 1)
                }
            }
            .navigationTitle(Text(tabNames.count > selectedTab ? tabNames[selectedTab] : ""))
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
            
        //}
    }
}


struct RestaurantProxyView: View {
    public var body: some View {
        return RestaurantView()
    }
}
