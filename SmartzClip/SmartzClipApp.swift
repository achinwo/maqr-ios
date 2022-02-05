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
    
    @State var isSheetPresented: Bool = false
    @State var result: Result<MFMailComposeResult, Error>? = nil
    
    init() {
        //let a = AttributedString()
        JoliApi.BaseUrl.defaultDevUrl = URL(staticString: "https://smartstikr.com")
        JoliApi.BaseUrl.defaultProdUrl = URL(staticString: "https://smartstikr.com")
        
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
    
    @State var modalItem: ModalCoordinator.Modal? = nil
    
    var contentView: some View {
        Group(){
                if case let AppLocation.product(storeId, _) = currentLocation,
                   storeId.lowercased() == "joey" {
                    JoeyRestuarantView<VideoPlaybackController>(currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
                } else if case let AppLocation.product(storeId, _) = currentLocation,
                          storeId.lowercased() == "shows" {
                    TvShowPromoView(crazyworldDemo)
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
            .sheet(item: self.$modalItem){
                defer { self.modalItem = nil }
                
                self.modalItem?.onClose()
            } content: { modalItem in
                
                if case let .mailOptions(opts) = modalItem.item {
                    MailView(result: $result, subject: opts.subject, recipients: opts.recipients, body: opts.body)
                } else if case let .view(view) = modalItem.item {
                    GeometryReader() { proxy in
                        AppPreviewView(preview: .constant(view), currentUser: self.$currentUser, animation: namespace)
                            .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom)
                            .animation(.spring())
                            .edgesIgnoringSafeArea([.bottom])
                    }
                    .environmentObject(coordinator)
                }
            }
            .onReceive(coordinator.modal.publisher) { modalItem in
                
                guard let modalItem = modalItem else {
                    self.modalItem = nil
                    return
                }
                
                if case let .mailOptions(opts) = modalItem.item, !MFMailComposeViewController.canSendMail() {
                    
                    guard let encoded = opts.subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                          let validUrl = URL(string: "mailto:\(Strings.appSupportEmail)?subject=\(encoded)") else {
                              coordinator.serverLogDestination.send(.error, msg: "[\(Self.self)] unable to send mail: subject=\(opts.subject)",
                                                                    thread: Thread.current.debugDescription, file: #file, function: #function, line: #line)
                              return
                          }
                    
                    UIApplication.shared.open(validUrl)
                } else {
                    self.modalItem = modalItem
                }
            }
    }
}

extension Strings {
    
    internal static var appSupportEmail: String {
        return "smartstikr@gmail.com"
    }
    
}
