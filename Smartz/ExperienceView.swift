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



class ExperienceData: ObservableObject {
    
    @Published var editStartedAt: Date? = nil
    
    @Published var logoImageUrl: URL?
    @Published var bannerImageUrl: URL?
    @Published var backgroundImageUrl: URL?
    
    @Published var companyName: String?
    @Published var landingPageText: String?
    
    init() {
        
    }
}

protocol ExperienceView: JoliView {
    associatedtype Model: ExperienceData
    var dataModel: Model { get }
    var editMode: EditMode { get nonmutating set }
}

extension ExperienceView {
    
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

struct RestaurantView: ExperienceView {
    
    @Binding var editMode: EditMode
    
    class Model: ExperienceData {
        
        
    }
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let dataModel: Model
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    public init(data: Model? = nil, editMode: Binding<EditMode> = .constant(.inactive)){
        self.dataModel = data ?? Model()
        self._editMode = editMode
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
                        
                        
                        NavigationLink(destination: Text("I have a reservation").navigationTitle(Text("Reservation"))) {
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
                        
                        Button(){
                            let preview: AppPreview = .view(){
                                    RestaurantMenuView()
                                        .frame(width: screenWidth)
                                        .frame(minHeight: screenHeight - (safeAreaInsets.bottom + safeAreaInsets.top))
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
        .showEditPencil(.constant(.preview))
    }
    
}

struct RestaurantMenuView: View {
    
    @State private var selectedTab: Int = 1
    
    var tabNames = ["FOOD", "DRINKS", "HAPPY HOUR", "NUTRITION"]
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    var body: some View {
        NavigationView(){
            TabView(selection: $selectedTab) {
                VStack(alignment: .leading){
                    
                
                    Text("Food").font(.largeTitle)
                    Text("Some food")
                }
                .tag(1)
                
                VStack(alignment: .leading){
                    Text("Drink").font(.largeTitle)
                    Text("Some drink")
                }
                .tag(2)
                
                VStack(alignment: .leading){
                    Text("Happy Hour").font(.largeTitle)
                    Text("Some happy")
                }
                .tag(3)
                
                VStack(alignment: .leading){
                    Text("Nutrition").font(.largeTitle)
                    Text("Some nut")
                }
                .tag(4)
            }
            .navigationTitle(Text(tabNames[selectedTab - 1]))
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}


struct RestaurantProxyView: View {
    public var body: some View {
        return RestaurantView()
    }
}
