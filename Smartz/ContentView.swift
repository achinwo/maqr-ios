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
import KeychainAccess

enum AssetInfo {
    case video(AVPlayer)
    case youtube(YouTubeVideoIdentifier)
    case image(String)
    case symbol(String)
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

public struct ProductOffering: Identifiable {
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

public let products: [ProductOffering] = [
    ProductOffering(name: "Meal Preparations", description: MealboxView.subtitle, location: .product("sise", "ofada"), companyLogoName: nil, companyDescription: "Meal box delivery", isComingSoon: false, experienceCls: MealboxView.self, iconName: MealboxView.iconName),
    ProductOffering(name: "Reservation Check-in", description: RestaurantView.subtitle, location: .product("joey", "sherman"), companyLogoName: nil, companyDescription: "Restaurant", isComingSoon: false, experienceCls: RestaurantView.self, iconName: RestaurantView.iconName),
    ProductOffering(name: "Brand Promotion", description: BrandPromoView.subtitle, location: .product("shows", "iacw"), companyLogoName: nil, companyDescription: "Brand", isComingSoon: false,
            experienceCls: BrandPromoView.self, iconName: "film.fill"),
    ProductOffering(name: "Wedding Event", description: WeddingEventView.subtitle, location: .experienceWeddingEvent("lizmanfred", URL(staticString: "https://maqr.co/ewed/lizmanfred")), companyLogoName: nil, companyDescription: "Event", isComingSoon: false,
            experienceCls: WeddingEventView.self, iconName: "person.2.circle"),
    ProductOffering(name: InventoryView.title, description: InventoryView.subtitle, location: .product("stikr", "inventory"),
                    companyLogoName: nil, companyDescription: "Ecommerce", isComingSoon: false,
                    experienceCls: InventoryView.self, iconName: InventoryView.iconName),
    ProductOffering(name: "Restock Essentials Instantly", description: ReorderNowView.subtitle, location: .product("stikr", "sherman"), companyLogoName: nil, companyDescription: "Ecommerce", isComingSoon: true,
            experienceCls: ReorderNowView.self, iconName: "creditcard.fill"),
    ProductOffering(name: "ꚠoli - Listen Together", description: "Enꚠoy music in groups with real-time voting", location: .product("joli", "joli"), companyLogoName: "logo_joli", companyDescription: "Entertainment", isComingSoon: true,
            experienceCls: ReorderNowView.self)
]

struct ContentView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    enum Tab: Int, Identifiable, CaseIterable {
        case home
        case appClipCreator
        //        case gallery
        case about
        
        var id: Int {
            rawValue
        }
        
        var label: String {
            switch self {
            case .about:
                return "About"
            case .appClipCreator:
                return "Design"
            case .home:
                return "Home"
            }
        }
        
        var color: Color {
            switch self {
            case .about:
                return Color.systemIndigo
            case .appClipCreator:
                return .pink
            case .home:
                return .green
            }
        }
        
        var emoji: (default: String, active: String) {
            switch self {
            case .about:
                return (default: "info.circle", active: "info.circle.fill")
            case .appClipCreator:
                return (default: "qrcode", active: "qrcode.viewfinder")
            case .home:
                return (default: "house", active: "house.fill")
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
    
    @State var activeSectionIdx: Int? = nil
    
    @Namespace var namespace
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @AppStorage(key: .activeTab) var selectedTab: Tab = .home
    
    @State var experienceData: ExperienceData?
    
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
                .animation(.none)
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
    
    var codeDesignerButton: some View {
        Button(){
            self.selectedTab = .appClipCreator
            
            Task() {
                guard let receiptData = appCoordinator.storeKitHelper.retreiveReceipt() else {
                    appCoordinator.serverLogDestination.send(.info, msg: "No receipt found!", thread: Thread.current.description,
                                                             file: #file, function: #function, line: #line)
                    return
                }
                
                let json: Json = [
                    "receiptData": receiptData as AnyObject,
                ]
                
                do {
                    let res = try await HttpMethod.post.fetchJson(urlPath: URLComponents(string: "/api/process-transaction")!, payload: json, baseUrl: api.baseUrl.http, urlSession: api.urlSession)
                    print("[RECEIPT] \(res)")
                } catch {
                    print("[RECEIPT] error: \(error)")
                }
                
            }
            
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
        .frame(width: screenWidth - 100, height: 60)
        .accentColor(.orange)
        .buttonStyle(OutlineButton())
        .padding(.top, safeAreaInsets.top)
    }
    
    @State public var visualCode = VisualCodeRecord()
    @State public var isEditingExperience = false
    @State public var submitting = false
    @State var currentAuth: Auth? = nil
    
    @AppStorage(key: .activeAccessLevel) private var selectedAccessLevel = ExperienceDataAccess.experienceDataAccessPrivate
    
    @discardableResult
    @MainActor
    func submitExperience(_ expData: ExperienceData) async throws -> StikrExperienceData {
        self.submitting = true
        
        defer {
            self.submitting = false
        }
        
        do {
            let saved = try await expData.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            print("[HomeView] SAVE experience: \(saved)")
            return saved
        } catch {
            self.appCoordinator.globalErrorHandler()(error)
            throw error
        }
    }
    
    var contentView: some View {
        NavigationView(){
            VStack(){
                if self.selectedTab == .home {
                    
                    let binding = Binding<String?>() {
                        return self.experienceData?.uuid
                    } set: { newValue in
                        print("[historyView] ignoring set: \(String(describing: newValue))")
                    }
                    
                    if let stikrExp = self.experienceData?.stored, let expCopy = ExperienceData.fromExperienceData(stikrExp, baseUrl: api.baseUrlHttp) {
                        
                        let experienceDataView = ExperienceDataView(expCopy){ data in
                            self.isEditingExperience = false
                            
                            guard !data.isDeleted else {
                                self.experienceData = nil
                                return
                            }
                            
                            Task() {
                                do {
                                    let saved = try await self.submitExperience(data)
                                    print("[ExperienceDataView] edited data - \(saved)")
                                    self.experienceData = ExperienceData.fromExperienceData(saved, baseUrl: api.baseUrlHttp)
                                    
                                } catch {
                                    print("[ExperienceDataView] error saving experience - \(error)")
                                    for symbol: String in Thread.callStackSymbols {
                                        print(symbol)
                                    }
                                }
                                
                            }
                            
                        }
                        .navigationBarTitle(expCopy.brandName)
                        .navigationBarItems(trailing: Button(){
                            appCoordinator.dismissKeyboard()
                            self.trialInfo = expCopy
                        } label: {
                            Text("Try It!")
                        })
                        
                        NavigationLink(destination: experienceDataView, isActive: self.$isEditingExperience) {
                            EmptyView()
                        }
                        .hidden()
                    }
                    
                    HomeView(selectedExperienceUuid: binding, accessLevel: $selectedAccessLevel) { (action, stikrExp) in
                        
                        switch action {
                            case .selected:
                                self.experienceData = ExperienceData.fromExperienceData(stikrExp, baseUrl: api.baseUrlHttp)
                                
                                    //            DispatchQueue.main.async(){
                                    //                onExperinceDataChanged(self.experienceData)
                                    //            }
                                
                                guard let visualCode = stikrExp.visualcodes?.last else { return }
                                
                                self.visualCode = visualCode.builder()
                                
                            case .launch:
                                self.trialInfo = ExperienceData.fromExperienceData(stikrExp, baseUrl: api.baseUrlHttp)
                                
                            case .edit:
                                print("[Home] editing experience")
                                isEditingExperience = true
                        }
                        
                        
                    } footer: {
                        codeDesignerButton
                            .padding()
                            .padding(.bottom, safeAreaInsets.bottom * 2)
                            .disabled(selectedAccessLevel != .experienceDataAccessPrivate)
                            .opacity(selectedAccessLevel == .experienceDataAccessPrivate ? 1 : 0)
                            .animation(.easeInOut)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                        //.navigationBarTitle()
                    .toolbar() {
                        ToolbarItem(placement: .principal) {
//                            VStack(alignment: .center) {
//                                Text("Live Experiences").font(.headline)
//                                Text("Your active brand experiences").font(.subheadline).foregroundColor(.secondaryLabel)
//                            }
                            let accessLevels = [ExperienceDataAccess.experienceDataAccessPrivate, ExperienceDataAccess.experienceDataAccessPublic]
                            
                            Picker("Choose experiences", selection: $selectedAccessLevel) {
                                ForEach(accessLevels) { item in
                                    Text(item.rawValue.capitalized)
                                        .accentColor(item == .experienceDataAccessPrivate ? .purple : .orange)
                                        .tag(item)
                                }
                            }
                            .id("man-screen-title")
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(minWidth: screenWidth / 2)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            let isLoggedIn = currentAuth != nil
                            
                            Button() {
                                self.selectedTab = .appClipCreator
                            } label: {
                                Image(systemName: "plus")
                            }
                            .padding(.leading)
                            .opacity(isLoggedIn && selectedAccessLevel == .experienceDataAccessPrivate ? 1 : 0)
                            .disabled(!isLoggedIn || selectedAccessLevel != .experienceDataAccessPrivate)
                            .animation(.easeInOut)
                        }
                        
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: self.onProfileActionClicked){
                                
                                if let auth = appCoordinator.activeAuth {
                                    NetworkImage(url: auth.user.gravatarUrl){
                                        Image(systemName: "person")
                                    }
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle")
                                }
                                
                            }
                            .frame(maxWidth: 32)
                            .animation(.easeInOut)
                            .padding(.trailing)
                            .id("man-screen-signin")
                        }
                    }
                    
                } else if self.selectedTab == .about {
                    ScrollView(.vertical){
                        AboutView()
                    }
                    .navigationBarHidden(true)
                    .toolbar() {
                        EmptyView()
                    }
                } else if self.selectedTab == .appClipCreator {
                    ScrollView(.vertical){
                        CodeDesignerView() { experienceData in
                            self.trialInfo = experienceData
                        }
                        .frame(minHeight: screenHeight * 1.5)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .edgesIgnoringSafeArea(.bottom)
        .onReceive(appCoordinator.$keyboardHeight, assign: \.keyboardHeight, target: self)
        .onReceive(appCoordinator.authSubject, assign: \.currentAuth, target: self)
        .frame(minWidth: screenWidth, idealHeight: screenHeight - safeAreaInsets.top)
        .overlay(
        
            VStack(){
                Spacer()
                    //                Picker(selection: self.$selectedTab, label: Text("Users")) {
                self.tabView
            }
            .frame(maxHeight: screenHeight - safeAreaInsets.top)
        )
        .background(
            Group(){
                if self.selectedTab == .about {
                    Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    EmptyView()
                }
            }
        )
    }
    
    @State var keyboardHeight: CGFloat = 0
    
    func onProfileActionClicked() -> Void {
        guard let currentAuth = appCoordinator.activeAuth, self.appCoordinator.activeSessionToken != nil else {
            self.appCoordinator.requestedSignIn.send(.apple(){ value in
                print("sign-in! \(value)")
            })
            return
        }
        
        let signOut = {
            print("Requested sign out")
            self.appCoordinator.signoutSubject.send(currentAuth)
        }
        
        let accountDelete = {
            print("Requested account deletion")
            
            Task(){
                print("[accountDelete] posting...")
                guard let success = try? await api.accountDelete(), success else { return }
                
                signOut()
                
                try? Keychain(service: "com.smartstickr.session-token").remove(currentAuth.user.appleIdentifier!)
            }
        }
        
        appCoordinator.modal.present() {
            .view2() {
                NavigationView(){
                    VStack(){
                        
                        NetworkImage(url: currentAuth.user.gravatarUrl){
                            Image(systemName: "person")
                        }
                        .clipShape(Circle())
                        .frame(maxWidth: screenWidth / 2, maxHeight: screenWidth / 2)
                        .padding()
                        
                        Text(currentAuth.user.displayName.name ?? "Anonymous")
                            .font(.title.weight(.thin))
                        Text(currentAuth.user.email)
                            .font(.caption)
                            .foregroundColor(.secondaryLabel)
                        
                        Button(){
                            
                            appCoordinator.modal.close() {
                                appCoordinator.withAlert(Strings.reallyLogoutTitle,
                                                         message: Strings.reallyLogoutMessage,
                                                         destructive: true, label: "Sign Out",
                                                         action: signOut)
                            }
                            
                        } label: {
                            Text("Sign Out")
                        }
                        .padding()
                        
                        Spacer()
                        Spacer()
                        
                        Divider()
                        
                        Button() {
                            appCoordinator.modal.close() {
                                appCoordinator.withAlert("Account Deletion",
                                                         message: "Are you sure you want to delete your account?\n\nWarning: This action is irreversible!",
                                                         destructive: true, label: "Delete",
                                                         action: accountDelete)
                            }
                            
                        } label: {
                            Text("Delete Account")
                        }
                        .foregroundColor(.red.opacity(0.7))
                        .padding()
                        .padding(.vertical)
                    }
                    .padding()
                    .navigationTitle("Account")
                }
                .eraseToAnyView()
            }
        }
    }
    
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
