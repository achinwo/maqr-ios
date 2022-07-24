//
//  SmartzApp.swift
//  Smartz
//
//  Created by Anthony Chinwo on 22/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import KeychainAccess
import Version
import JoliApi
import JoliCore
import os
import MessageUI
import AuthenticationServices

@main
struct SmartzApp: AppClip, AppAuthentication {
    
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var coordinator: AppCoordinator
    
    @Namespace var namespace
    
    @AppStorage(key: AppStorageKey.authToken, store: UserDefaults.groupContainer)
    var activeSessionIdFromAppclip: String = .empty
    
    @AppStorage(key: AppStorageKey.location, store: UserDefaults.groupContainer)
    var activeLocationFromAppclip: AppLocation = .unset
    
    @AppStorage(key: AppStorageKey.location, store: .standard)
    var currentLocation: AppLocation = .unset {
        willSet {
            print("[\(Self.self)] Setting current location: \(currentLocation) -> \(newValue)")
            guard newValue != currentLocation else { return }
            
            coordinator.modal.close()
        }
    }
    
    @AppStorage("active-session-id") var activeSessionId: String = .empty
    
    @State var appleSignInDelegates: SignInWithAppleDelegates? = nil
    
    @State var serverInfo: ServerInfo? = nil
    
    var apnTokenPublisher: NotificationCenter.Publisher
    
    var websocket: Socket
    
    @State var window: UIWindow?
    
    @State var safeAreaInsets: EdgeInsets
    
    let keychain: Keychain
    
    @State var auths: [Auth] = []
    
    @State var activeSessionToken: String? = nil
    var api: JoliApi
    @State var alertInfo: Alert? = nil
    @State var isActionSheetPresented: Bool = false
    
    @State var currentUser: User? = nil
    let videoController: VideoPlaybackController
    
    init() {
        JoliApi.BaseUrl.defaultDevUrl = URL(staticString: "https://maqr.co")
        JoliApi.BaseUrl.defaultProdUrl = URL(staticString: "https://maqr.co")
        
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        apnTokenPublisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
        keychain = Keychain(service: "com.smartstickr.session-token")
        videoController = VideoPlaybackController()
        
        _safeAreaInsets = State(initialValue: EdgeInsets())
        
        // set app products as default
        Product.Identifier.productIds = Product.Identifier.stikrProductIds
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        
        let baseUrls = JoliApi.Environment.current.baseUrl
        
        self.api = JoliApi(baseUrl: baseUrls, headers: request.allHTTPHeaderFields ?? [:])
        
        let appclipsSessionId = self.activeSessionIdFromAppclip.isEmpty ? nil : self.activeSessionIdFromAppclip
        let location = self.activeLocationFromAppclip
        let currentLocation = self.currentLocation
        
        print("[\(Self.self)] initializing: appclipsSessionId=\(String(describing: appclipsSessionId)), appclipsLocation=\(location), currentLocation=\(currentLocation)")
        
        if self.currentLocation == .unset, location != .unset {
            self._currentLocation = AppStorage(wrappedValue: location, key: AppStorageKey.location, store: .standard)
        }
        
        self._auths = State(initialValue: Self.resolveAuths(keychain))
        
        let sessionId = self.activeSessionId.isEmpty ? nil : self.activeSessionId
        
        self._activeSessionToken = State(initialValue: sessionId ?? appclipsSessionId)
        
        api.urlSessionConfiguration = api.urlSessionConfiguration.withAuthHeader(self.activeSessionToken)
        
        coordinator.api = self.api
        
//        if let token = self.activeSessionToken {
//            request.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
//        }
    }
    
    @State var mailComposeResult: Result<MFMailComposeResult, Error>? = nil
    
    @State var modalItem: ModalCoordinator.Modal? = nil
    @State var modalItemOnClose: ModalCoordinator.CloseCallback? = nil
    
    var modalItemBinding: Binding<ModalCoordinator.Modal?> { $modalItem }
    
    @State var trialData: TrialInfo? = nil
    
    public var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    public var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    func modalView(_ item: ModalCoordinator.Item) -> some View {
        Group(){
            //Text("Hello world")
            if case let .mailOptions(opts) = item {
                MailView(result: self.$mailComposeResult, subject: opts.subject, recipients: opts.recipients, body: opts.body)
            } else if case let .view(view) = item {
                
                let preview = Binding<AppPreview?>() {
                    return view
                } set: { dismiss in
                    guard dismiss == nil else { return }
                    
                    self.modalItem = nil
                }
                
                AppPreviewView(preview: preview,
                               currentUser: self.$currentUser,
                               animation: namespace)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
        
    var contentView: some View {
        
        let exitButton = GeometryReader() { proxy in
            VStack(){
                HStack(){
                    Button(){
                        currentLocation = .home
                        trialData = nil
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left.circle.fill")
                            .font(.largeTitle)
                            //.resizable()
                            //.aspectRatio(contentMode: .fit)
                            //.frame(width: 48, height: 48)
                            .opacity(0.4)
                            //.grayscale(0.8)
                            .shadow(color: Color.secondaryLabel, radius: 1, x: 0.2, y: 0.2)
                    }
                    .padding(.horizontal)
                    .clipShape(Circle())
                    Spacer()
                }
                Spacer()
            }
        }
        
        return ContentView(currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController, trialInfo: $trialData)
            .overlay(
                GeometryReader(){ proxy in
                    //let isVisible = trialData != nil || ![AppLocation.home, AppLocation.unset].contains(currentLocation)
                    Group(){
                        if let trial = trialData {
                            trial.experienceTypeInfo.toView(trial).overlay(exitButton)
                        } else if ![AppLocation.home, AppLocation.unset].contains(currentLocation) {
                            Group(){
                                if case let AppLocation.product(storeId, _) = currentLocation,
                                   storeId.lowercased() == "joey" {
                                    JoeyRestuarantView<VideoPlaybackController>(currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
                                } else if case let AppLocation.product(storeId, _) = currentLocation,
                                          storeId.lowercased() == "shows" {
                                    BrandPromoView(crazyworldDemo)
                                } else if case let AppLocation.product(_, productId) = currentLocation, productId.lowercased() == "inventory" {
                                    InventoryView(hospitalPharmacy)
                                } else if currentLocation.isExperience {
                                    DynamicExperienceView<VideoPlaybackController>(currentLocation, currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
                                } else {
                                    SiseMealboxView<VideoPlaybackController>(siseMealboxDemo, currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
                                }
                            }
                            .overlay(exitButton)
                        }
                    }
                }
                .ifLet(self.alertInfo) { view, alert in
                    view.alert(isPresented: self.$isActionSheetPresented) { return alert }
                }
            )
            .onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onReceive(coordinator.signoutSubject, perform: self.signOut)
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
            .onAppear() {
                
                guard let currentAuth = self.auths.first else {
                    return
                }
                
                let token = activeSessionToken ?? currentAuth.session.token
                
                let authenticate: () -> () = {
                    Task() { await self.authenticate(.sessionToken(token), alertOnFail: false) }
                }
                
                guard let appleIdentifier = currentAuth.user.appleIdentifier else {
                    authenticate()
                    return
                }
                
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                
                appleIDProvider.getCredentialState(forUserID: appleIdentifier) { (credentialState, error) in
                    switch credentialState {
                        case .authorized:
                            print("[SIGN IN WITH APPLE] auth is valid")
                            authenticate()
                        case .revoked, .notFound:
                            print("[SIGN IN WITH APPLE] auth has been revoked")
                            DispatchQueue.main.async() {
                                self.coordinator.signoutSubject.send(currentAuth)
                            }
                        default:
                            break
                    }
                }
                
            }
    }
    
    func signOut(_ auth: Auth) -> Void {
        let newAuths = self.auths.filter() { $0.session.token != auth.session.token}
        self.auths = newAuths
        
        self.activeSessionToken = nil
        try? keychain.remove(auth.user.email)
        
        storeToKeychain(newAuths)
        
        self.coordinator.activeSessionToken = nil
        self.coordinator.authsSubject.send(newAuths)
        
        self.coordinator.api.urlSessionConfiguration = self.coordinator.api.urlSessionConfiguration.withAuthHeader(nil)
        
        self.coordinator.serverLogDestination.send(.info, msg: "signedout: \(auth)", thread: Thread.current.description, file: #file, function: #function, line: #line)
        
        if auth.session.token == activeSessionIdFromAppclip {
            self.activeSessionIdFromAppclip = .empty
        }
        
        print("signedout: \(auth.user.name)")
    }
    
}

public typealias TrialInfo = ExperienceData


extension Strings {
    
    internal static var appSupportEmail: String {
        return "info@maqr.co"
    }
    
}
