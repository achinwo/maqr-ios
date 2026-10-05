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
import MaqrApi
import os
import MessageUI
import AuthenticationServices
import UserNotifications


@main
struct SmartzApp: AppClip, AppAuthentication {
    
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    
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
    var api: MaqrApi
    @State var alertInfo: Alert? = nil
    @State var isActionSheetPresented: Bool = false
    
    @State var currentUser: User? = nil
    
    init() {
        
        MaqrApi.Environment.loadEnvConfig(from: Bundle.main)
        
        apnTokenPublisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
        keychain = Keychain(service: "com.smartstickr.session-token")
        
        _safeAreaInsets = State(initialValue: EdgeInsets())
        
        // set app products as default
        Product.Identifier.productIds = Product.Identifier.stikrProductIds
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        
        let baseUrls = MaqrApi.Environment.current.baseUrl
        
        self.api = MaqrApi(baseUrl: baseUrls, headers: request.allHTTPHeaderFields ?? [:])
        
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
        
        return ContentView(currentUser: $currentUser, websocket: websocket, trialInfo: $trialData)
            //.font(.custom("AvenirLTStd-Roman", size: 46))
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
                                    JoeyRestuarantView(currentUser: $currentUser, websocket: websocket)
                                } else if case let AppLocation.product(storeId, _) = currentLocation,
                                          storeId.lowercased() == "shows" {
                                    BrandPromoView(crazyworldDemo)
                                } else if case let AppLocation.product(_, productId) = currentLocation, productId.lowercased() == "inventory" {
                                    InventoryView(hospitalPharmacy)
                                } else if currentLocation.isExperience {
                                    DynamicExperienceView(currentLocation, currentUser: $currentUser, websocket: websocket)
                                } else {
                                    SiseMealboxView(siseMealboxDemo, currentUser: $currentUser, websocket: websocket)
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
                
//                let accept = UNNotificationAction(
//                    identifier: ActionIdentifier.accept.rawValue,
//                    title: "A. 33")
//
//                let reject = UNNotificationAction(
//                    identifier: ActionIdentifier.reject.rawValue,
//                    title: "B. 136")
//
//                let neutral = UNNotificationAction(
//                    identifier: ActionIdentifier.neutral.rawValue,
//                    title: "C. 9")
//
//                let plus = UNNotificationAction(
//                    identifier: ActionIdentifier.plus.rawValue,
//                    title: "D. 685")
//
//                let howManyGlassesInputAction =  UNTextInputNotificationAction(
//                    identifier: "drinkingReminder.howManyGlassesInputAction",
//                    //title: "How many glasses of water did you drink?",
//                    title: "How do you spell \"Squirrel\" in french?",
//                    options: [],
//                    textInputButtonTitle: "SUBMIT",
//                    textInputPlaceholder: "Enter french spelling")
//
//                let category = UNNotificationCategory(
//                    identifier: categoryIdentifier,
//                    actions: [
////                        accept,
////                        reject,
////                        neutral,
////                        plus,
//                        howManyGlassesInputAction
//                    ],
//                    intentIdentifiers: [])
//
//                UNUserNotificationCenter.current()
//                    .setNotificationCategories([category])
//
//                let content = UNMutableNotificationContent()
////                content.title = "French Lessons: Translate Below"
////                content.subtitle = "il est très heureux dans son travail"
//
////                content.title = "Maths Lessons: Challenge #16"
////                content.subtitle = "Take out the wrong number from the given series; 3, 4, 9, 33, 136, 685, 4116"
//
//                content.title = "French Lessons: Challenge #45"
//                content.subtitle = "How do you spell \"Squirrel\" in french?"
//
//                content.sound = UNNotificationSound.default
//                content.categoryIdentifier = self.categoryIdentifier
//
//                    // show this notification five seconds from now
//                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
//
//                    // choose a random identifier
//                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
//
//                    // add our notification request
//                UNUserNotificationCenter.current().add(request)
//
//                print("££££££££ Notification scheduled")
                
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
    
//    private let categoryIdentifier = "AcceptOrReject"
//
//    private enum ActionIdentifier: String {
//        case accept, reject, neutral, plus
//    }
    
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
