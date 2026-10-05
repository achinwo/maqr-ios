//
//  RestaurantView+Legacy.swift
//  Joli
//
//  Created by Anthony Chinwo on 28/05/2023.
//  Copyright © 2023 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI

struct RestaurantMenuButtonView: JoliView {
    
    @Binding var menu: RestaurantMenu?
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @State var isPresented = false
    
    var contentView: some View {
        Button(){
            
            
            guard let menu = self.menu else {
                
                print("Unable to load menu")
                return
            }
            
            self.isPresented = true
            
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
        .sheet(isPresented: self.$isPresented) {
            RestaurantMenuView(menu: menu!)
                .frame(width: screenWidth)
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
                
                if let drinks = drinkGroup.items.filter({ $0.category == category }) as? [RestaurantDrink], !drinks.isEmpty {
                    
                    if let url = drinkGroup.imageUrl {
                        NetworkImage(url: url){
                            VStack(){
                                ProgressView()
                            }
                        }
                        .id(url)
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
            //        ZStack(){
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
        
            //            VStack(){
            //                Color.white.opacity(0.2).frame(width: screenWidth, height: 50)
            //                Spacer()
            //            }
            //        }
            //        .frame(width: screenWidth)
    }
}
