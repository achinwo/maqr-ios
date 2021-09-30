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

@main
struct SmartzApp: AppClip {
    
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
    
    @State var serverVersion: Version? = nil
    
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
        JoliApi.BaseUrl.defaultDevUrl = URL(staticString: "https://smartstikr.com")
        JoliApi.BaseUrl.defaultProdUrl = URL(staticString: "https://smartstikr.com")
        
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
        apnTokenPublisher = NotificationCenter.default.publisher(for: Notifications.apnToken)
        keychain = Keychain(service: "com.smartstickr.session-token")
        videoController = VideoPlaybackController()
        
        _safeAreaInsets = State(initialValue: EdgeInsets())
        
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        
        let request = Self.wssUrlRequest
        self.websocket = Socket(request: request)
        
        let baseUrls = JoliApi.Environment.current.baseUrl
        
        self.api = JoliApi(baseUrl: baseUrls, headers: request.allHTTPHeaderFields ?? [:])
        self.coordinator.api = api
    }
    
    @State var mailOptions: MailView.Options? = nil
    @State var isSheetPresented: Bool = false
    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State var modalView: AppPreview? = nil
    
    @State var trialData: TrialInfo? = nil
    
    public var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    public var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
        
    var contentView: some View {
        
        let exitButton = GeometryReader() { proxy in
            VStack(){
                HStack(){
                    Button(){
                        currentLocation = .home
                        trialData = nil
                    } label: {
                        Image("smartz_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .padding(4)
                            .opacity(0.4)
                            .grayscale(0.8)
                            .shadow(color: Color.secondaryLabel, radius: 1, x: 0.2, y: 0.2)
                    }
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
                            trial.trialType.toView(trial.data).overlay(exitButton)
                        } else if ![AppLocation.home, AppLocation.unset].contains(currentLocation) {
                            Group(){
                                if case let AppLocation.product(storeId, _) = currentLocation,
                                   storeId.lowercased() == "joey" {
                                    JoeyRestuarantView<VideoPlaybackController>(currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
                                } else if case let AppLocation.product(storeId, _) = currentLocation,
                                          storeId.lowercased() == "shows" {
                                    TvShowPromoView(crazyworldDemo)
                                } else {
                                    SiseMealboxView<VideoPlaybackController>(currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
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
//            .overlay(
//                GeometryReader(){ proxy in
//                    YouTubeView(playerState: youtube)
//                        .frame(width: proxy.size.width, height: proxy.size.height)
//                }
//                .background(Color.blue.opacity(0.6))
//                .onAppear(){
//                    youtube.playVideo()
//                }
//            )
            .onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
            .onChange(of: self.mailOptions) { opts in
                isSheetPresented = self.mailOptions != nil
            }
            .onChange(of: self.modalView) { modal in
                isSheetPresented = self.modalView != nil
            }
            .sheet(isPresented: $isSheetPresented){
                self.modalView = nil
                self.mailOptions = nil
            } content: {
                
                if let opts = self.mailOptions {
                    MailView(result: $result, subject: opts.subject, recipients: opts.recipients, body: opts.body)
                } else {
                    GeometryReader() { proxy in
                        AppPreviewView(preview: self.$modalView, currentUser: self.$currentUser, animation: namespace)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .animation(.spring())
                        //.background(Color.yellow)
                    }
                    .edgesIgnoringSafeArea(.all)
                    .environmentObject(coordinator)
                }
            }
            .onReceive(coordinator.globalModalSubject) { view in
                self.modalView = view
            }
            .onReceive(coordinator.$mailOptions) { opts in
                
                guard let opts = opts else {
                    self.mailOptions = nil
                    return
                }
                
                guard MFMailComposeViewController.canSendMail() else {
                    
                    if let encoded = opts.subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                       let validUrl = URL(string: "mailto:\(Strings.appSupportEmail)?subject=\(encoded)") {
                        UIApplication.shared.open(validUrl)
                    } else {
                        coordinator.serverLogDestination?.send(.error, msg: "[\(Self.self)] unable to send mail: subject=\(opts.subject)",
                                                               thread: Thread.current.debugDescription, file: #file, function: #function, line: #line)
                    }
                    
                    return
                }
                
                self.mailOptions = opts
            }
    }
}

public enum ExperienceTrialType {
    case mealboxPrep
    case restaurantCheckin
    case brandPromotion
    
    func toView(_ data: ExperienceData) -> some View {
        switch self {
            case .mealboxPrep:
                return MealboxView(data).eraseToAnyView()
            case .restaurantCheckin:
                return RestaurantView(data).eraseToAnyView()
            case .brandPromotion:
                return TvShowPromoView(data).eraseToAnyView()
        }
    }
}

public typealias TrialInfo = (trialType: ExperienceTrialType, data: ExperienceData)
