//
//  SmartzClipApp.swift
//  SmartzClip
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
import MessageUI

@main
struct SmartzClipApp: AppClip {
    
    @Environment(\.scenePhase) var scenePhase
    
    var coordinator: AppCoordinator
    
    @Namespace var namespace
    
    @AppStorage(key: AppStorageKey.location, store: UserDefaults.groupContainer)
    var activeLocationFromAppclip: AppLocation = .unset
    
    @AppStorage(key: AppStorageKey.location, store: .standard)
    var currentLocation: AppLocation = .unset {
        didSet {
            print("[\(Self.self)] Setting current location: \(currentLocation)")
        }
    }
    
    @AppStorage("active-session-id") var activeSessionId: String = .empty
    
    @State var appleSignInDelegates: SignInWithAppleDelegates? = nil
    
    @State var serverInfo: ServerInfo? = nil
    
    var apnTokenPublisher: NotificationCenter.Publisher =  NotificationCenter.default.publisher(for: Notifications.apnToken)
    
    var websocket: Socket
    
    @State var window: UIWindow?
    
    @State var safeAreaInsets: EdgeInsets = EdgeInsets()
    
    var keychain: Keychain = Keychain(service: "com.smartstickr.session-token")
    
    @State var auths: [Auth] = []
    
    @State var activeSessionToken: String? = nil
    var api: JoliApi
    @State var alertInfo: Alert? = nil
    @State var isActionSheetPresented: Bool = false
    
    @State var currentUser: User? = nil
    let videoController = VideoPlaybackController()
    
    @State var mailComposeResult: Result<MFMailComposeResult, Error>? = nil
    
    @State var modalItem: ModalCoordinator.Modal? = nil
    @State var modalItemOnClose: ModalCoordinator.CloseCallback? = nil
    
    var modalItemBinding: Binding<ModalCoordinator.Modal?> { $modalItem }
    
    init() {
        //let a = AttributedString()
        JoliApi.BaseUrl.defaultDevUrl = URL(staticString: "https://maqr.co")
        JoliApi.BaseUrl.defaultProdUrl = URL(staticString: "https://maqr.co")
        
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        
        let baseUrls = JoliApi.Environment.current.baseUrl
        
        self.api = JoliApi(baseUrl: baseUrls, headers: request.allHTTPHeaderFields ?? [:])
        print("[\(Self.self)] isAppClip: \(Self.isAppclip)")
        
        self.coordinator.api = api
    }
    
    var contentView: some View {
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
            .onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
    }
    
    func modalView(_ item: ModalCoordinator.Item) -> some View {
        Group(){
            if case let .mailOptions(opts) = item {
                MailView(result: self.$mailComposeResult, subject: opts.subject, recipients: opts.recipients, body: opts.body)
            } else if case let .view(view) = item {
                
                let preview = Binding<AppPreview?>() {
                    return view
                } set: { dismiss in
                    guard dismiss == nil else { return }
                    
                    self.modalItem = nil
                }
                
                GeometryReader() { proxy in
                    AppPreviewView(preview: preview, currentUser: self.$currentUser, animation: namespace)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .animation(.spring())
                        .edgesIgnoringSafeArea([.bottom])
                        //.background(Color.yellow)
                }
                .environmentObject(coordinator)
            }
        }
    }
    
}

extension Strings {
    
    internal static var appSupportEmail: String {
        return "smartstikr@gmail.com"
    }
    
}
