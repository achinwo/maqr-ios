//
//  SmartzApp.swift
//  Smartz
//
//  Created by Anthony Chinwo on 22/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import KeychainAccess
import Version
import JoliApi
import JoliCore
import os
import MessageUI

let crazyworldDemo = ExperienceData.fromDefaults(.init(logoImageUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/logo_crazyworld.png"),
                                                       bannerImageUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/poster_crazy_world_lowres.jpg"),
                                                       bannerVideoUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/crazyworld_netflix_trailer.mp4"),
                                                       brandName: "It's a Crazy World",
                                                       landingPageText: "“It’s a crazy world” is a modern-day 30-minute sitcom created by Amanda Ebeye and majorly directed by KC Muel and Amanda Ebeye. It tells the story of a very wealthy man with three women and three kids. It’s a hilarious sitcom that addresses the competition women go through in general trying to outdo themselves and constantly vying for the man’s attention. In this case, these women would use any means available to them, with social media being their number one go-to tool. \n\nThe other two women are constantly trying to win the favorite spot which the first wife already occupies as he constantly reminds them that besides pregnancy and the kids from the other women; he’s a man with a one-man-one-woman personality. So they try every way they can to win that spot, employing social media tools, the last wife and the kids’ area always on Instagram, Snapchat, Facebook, living a lie, making their worlds look perfect when it is not.",
                                                       socialInstagramUsername: "itsacrazyworld_tvseries",
                                                       releaseDate: Date(timeIntervalSince1970: 1627171200),
                                                       releasePlatformName: "Netflix",
                                                       releasePlatformLogoUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/logo_netflix.png"),
                                                       releasePlatformInstaUsername: "naijaonnetflix"
                                                       ))

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
        
        return ContentView($trialData)
            .overlay(
                GeometryReader(){ proxy in
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
            )
            .onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
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
                            .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom)
                            .animation(.spring())
                            .edgesIgnoringSafeArea([.bottom])
                        //.background(Color.yellow)
                    }
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
