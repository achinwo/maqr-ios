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
    
    init() {
        JoliApi.Environment.loadEnvConfig(from: Bundle.main)
        
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
    
    var contentView: some View {
        Group(){
                if [AppLocation.home, AppLocation.unset].contains(currentLocation) {
                    ContentView()
                } else {
                    SiseMealboxView<VideoPlaybackController>(currentUser: $currentUser, websocket: websocket, localPlaybackController: videoController)
                        .overlay(
                            GeometryReader() { proxy in
                                VStack(){
                                    HStack(){
                                        Button(){
                                            currentLocation = .home
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
                        )
                }
            }
            .onReceive(coordinator.$currentLocation, assign: \.currentLocation, target: self)
            .onReceive(coordinator.globalAlertSubject) { alertInfo in
                self.alertInfo = alertInfo
                self.isActionSheetPresented = true
            }
            
            .onChange(of: self.mailOptions) { opts in
                isSheetPresented = self.mailOptions != nil
            }
            .sheet(isPresented: $isSheetPresented){
                self.mailOptions = nil
            } content: {
                Group(){
                    if let opts = self.mailOptions {
                        MailView(result: $result, subject: opts.subject, recipients: opts.recipients, body: opts.body)
                    }
                }
                .environmentObject(coordinator)
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

extension Strings {
    
    internal static var appSupportEmail: String {
        return "smartstikr@gmail.com"
    }
    
}
