//
//  AppClip.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import JoliApi
import JoliCore
import Combine
import AuthenticationServices
import Version
import KeychainAccess
import AlertToast

#if os(macOS)
import AppKit

public enum FeedbackStyle {
    case soft
    case rigid
    case medium
    case light
    case heavy
}

public typealias UIWindow = NSWindow
public typealias UIEdgeInsets = NSEdgeInsets

public extension UIWindow {
    
    var safeAreaInsets: NSEdgeInsets {
        return .init()
    }
}

public struct MFMailComposeViewController {
    
    static func canSendMail() -> Bool {
        return false
    }
    
}

public enum MFMailComposeResult {
    
}

#else
import UIKit
import PartialSheet
import MessageUI
//import SwiftyBeaver

public typealias FeedbackStyle = UIImpactFeedbackGenerator.FeedbackStyle
#endif


public enum SpotifyError: Error {
    case unathorized
}

#if !os(macOS)
public extension PartialSheetManager {
    
    func show<T>(_ onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> T) where T: SwiftUI.View {
        self.showPartialSheet(onDismiss, content: content)
    }
}
#endif

public protocol JoliView: View {
    associatedtype Content: View
    
    var appCoordinator: AppCoordinator { get }
    var api: JoliApi { get }
    
    var contentView: Content { get }
//    var visibility: (appearedAt: Date?, disappearedAt: Date?)  { nonmutating set get }
    
    func onConnectionStateChange(_ state: ConnectionState) -> Void
}

public extension JoliView {
    
    func presentToast(_ title: String, subTitle: String? = nil,
                      //custom: AlertCustom? = nil,
                      type: AlertToast.AlertType,
                      displayMode: AlertToast.DisplayMode = .alert,
                      duration: Double = 2,
                      tapToDismiss: Bool = true,
                      onDismiss: @escaping (Bool) -> Void) {
        
        let alertToast = AlertToast(displayMode: displayMode,
                                    type: type,
                                    title: title,
                                    subTitle: subTitle
        //                            custom: custom
        )
        appCoordinator.globalToastInfo.send((alertToast, onDismiss))
    }
    
    var tag: String {
        return "[\(Self.self)]"
    }
    
    var body: some View {
        return self.contentView
            .onReceive(appCoordinator.connectionStateSubject) { state in
                self.onConnectionStateChange(state.state)
            }
//            .onAppear() {
//                self.visibility = (appearedAt: Date(), disappearedAt: self.visibility.disappearedAt)
//            }
//            .onDisappear() {
//                self.visibility = (appearedAt: self.visibility.appearedAt, disappearedAt: Date())
//            }
    }
    
    var api: JoliApi {
        return appCoordinator.api
    }
    
    func onConnectionStateChange(_ state: ConnectionState) -> Void { }
    
    func withImpact(_ impact: FeedbackStyle = .soft, animated: Animation? = nil, _ action: () -> Void){
        if let animation = animated {
            withAnimation(animation) {
                appCoordinator.withImpact(impact, action)
            }
        } else {
            appCoordinator.withImpact(impact, action)
        }
    }
}

public protocol JoliContentView: JoliView {
    
    associatedtype PlaybackControllerType
    var localPlaybackController: PlaybackControllerType { get }
    var websocket: Socket { get }
    var websocketCancel: AnyCancellable? { get nonmutating set }
    
    var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? { get nonmutating set }
}

extension JoliContentView {
    
    public var body: some View {
        
        
        let isPresentingToast = Binding<Bool>(){
            return toastInfo != nil
        } set: { newValue in
            print("\(tag) setting presenting to: \(newValue)")
            guard toastInfo != nil, !newValue else {
                return
            }
            
            self.toastInfo = nil
        }
        return self.contentView
            .overlay(
                GeometryReader(){ proxy in
                    HStack(alignment: .top) {
                        Spacer()
                            .padding(.top, 200)
                            .ifLet(self.toastInfo) { view, alertToast in
                                view.toast(isPresenting: isPresentingToast) {
                                    alertToast.alert
                                } completion: {
                                    print("[\(Self.self)] toast completion")
                                    alertToast.onDismiss(true)
                                }
                            }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height / 2)
                    .padding(.top, proxy.safeAreaInsets.top)
                }
            )
            .onReceive(appCoordinator.connectionStateSubject) { state in
                self.onConnectionStateChange(state.state)
            }
            .onReceive(appCoordinator.globalToastInfo) { info in
                self.toastInfo = info
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0){
                    self.toastInfo = nil
                }
            }
    }
    
    static var defaultIdleTime: Double {
        return Strings.appName == "Joli" ? 4 : 6
    }
    
    private var playbackRefreshRate: TimeInterval {
        return 0.15
    }
    
    private var callback: Publishers.Smooth<PlayState.Publisher, String>.StateGetter {
        
        return { (state, now) in
            
            let uid = state.trackUri == nil ? nil : state.trackUri! + state.id.description
            
            guard let duration = state.durationMs, state.playingState == .playing else {
                return (id: uid, value: state.progressMs, duration: nil, idleTimeout: Self.defaultIdleTime)
            }
            
            return (id: uid, value: state.progressMs, duration: TimeInterval(duration), idleTimeout: Self.defaultIdleTime)
        }
        
    }
    
    private func updatePublishers() {
        print("[\(tag)] updating publishers")
        
        let publisher: PlayState.Publisher = self.websocket.publish(PlayState.self, interval: self.playbackRefreshRate, path: \.progressMs, resolver: callback)
        
        let votesPubs: QueuedTrackVote.Publisher = self.websocket
            .deserialize(QueuedTrackVote.self)
            .autoconnect()
            .multicast() {
                return PassthroughSubject<QueuedTrackVote, SocketError>()
            }
            .autoconnect()
            .eraseToAnyPublisher()
        
        self.appCoordinator.playStatePublisher = publisher
        self.appCoordinator.votesPublisher = votesPubs
    }
    
    public func assertWebsocketConnected() {
        //print("[AppView#assertWebsocketConnected] attempting...")
        
        guard self.websocket.isConnected else {
            self.websocket.connect()
            return
        }
        
        self.websocket.write(topic: "/status", body: [:]) { error in
            
            guard let error = error else {
                logger.info("[assertWebsocketConnected] asserting websocket connected successful")
                return
            }
            
            logger.error("[assertWebsocketConnected] asserting websocket connected: \(String(describing: error))")
            appCoordinator.globalErrorHandler()(error)
        }
    }
    
    public func onConnectionStateChanged(_ socket: Socket, _ connected: Bool){
        print("[\(tag)#onConnectionStateChanged] connected: \(connected)")
        
        guard connected else {
            let randomInt = Int.random(in: 2..<7)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(randomInt)) {
                
                guard !socket.isConnected else { return }
                
                socket.connect()
            }
            return
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_NOW_PLAYING"]) { error in
            print("[App] updated subscriptions: PLAYER_STATE_NOW_PLAYING - \(String(describing: error))")
            
            
            DispatchQueue.main.async {
//                self.reconnectingTasks.cancelAll()
//                self.reconnectingTasks.removeAll()
                self.updatePublishers()
            }
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_CHANGED"]) { error in
            
            guard error == nil else {
                print("[App] updated subscriptions (error): PLAYER_STATE_CHANGED - \(String(describing: error))")
                return
            }
            
            self.websocketCancel = self.websocket
                .sink() { completion in
                    websocketCancel?.cancel()
                    websocketCancel = nil
                } receiveValue: { message in
                    
                    guard case let .text(_, _, _, subjectValue) = message, let subject = subjectValue, subject == "PLAYER_STATE_CHANGED" else {
                        return
                    }
                    
                    self.appCoordinator.playStateChangeSubject.send(Date())
                }
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "database_updates"]) { error in
            print("[App] updated subscriptions: database_updates - \(String(describing: error))")
        }
    }
    
}

public enum ViewIdentifier: String, Identifiable {
    case explore = "views.explore"
    case listen = "views.listen"
    case notset = "views.none"
    
    public var id: String {
        return rawValue
    }
}

#if !os(macOS)
class ShareActivity: UIActivity {
    
    override var activityType: UIActivity.ActivityType {
        return .copyToPasteboard
    }
    
    override var activityTitle: String? {
        return Strings.appName
    } // default returns nil. subclass must override and must return non-nil value
    
    override var activityImage: UIImage? {
        return Images.joliIcon.uiImage
    } // default #imageLiteral(resourceName: "joil_icon_rounded.png")returns nil. subclass must override and must return non-nil value
    
    override func perform() {
        self.activityDidFinish(false)
    }
    
    override func activityDidFinish(_ completed: Bool) {
        logger.debug("[ShareActivity] finished: \(completed)")
    }
}
#endif

private struct SafeAreaInsetsKey: EnvironmentKey {

    static var defaultValue: EdgeInsets {
        guard let window = defaultWindow else {
            return EdgeInsets()
        }
        
        return window.safeAreaInsets.insets
    }
    
    static var defaultWindow: UIWindow? {
        #if os(macOS)
        return nil
        #else
        guard let scene = UIApplication.shared.connectedScenes.first,
              let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
              let window = windowSceneDelegate.window else {
            return nil
        }
        return window
        #endif
    }
}

public extension EnvironmentValues {
    
    var safeAreaInsets: EdgeInsets {
        get {
            self[SafeAreaInsetsKey.self]
        }
        set {
            self[SafeAreaInsetsKey.self] = newValue
        }
    }
}

private extension UIEdgeInsets {
    
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

public protocol AppClip: App {
    associatedtype Content: View
    associatedtype ModalView: View
    
    var env: JoliApi.Environment { get }
    var appDelegate: AppDelegate { get }
    var contentView: Content { get }
    var scenePhase: ScenePhase { get }
    var coordinator: AppCoordinator { nonmutating get }
    var namespace: Namespace.ID { get }
    var appleSignInDelegates: SignInWithAppleDelegates? { get nonmutating set }
    var serverInfo: ServerInfo? { get nonmutating set }
    var apnTokenPublisher: NotificationCenter.Publisher { get }
    
    var websocket: Socket { get }
    var window: UIWindow? { get nonmutating set }
    var safeAreaInsets: EdgeInsets { get nonmutating set }
    
    var mailComposeResult: Result<MFMailComposeResult, Error>? { get nonmutating set }
    
    var modalItem: ModalCoordinator.Modal? { get nonmutating set }
    var modalItemBinding: Binding<ModalCoordinator.Modal?> { get }
    var modalItemOnClose: ModalCoordinator.CloseCallback? { get nonmutating set }
    
    var keychain: Keychain { get }
    var auths: [Auth] { get nonmutating set }
    var activeSessionToken: String? { get nonmutating set }
    
    static var version: Version { get }
    static var isAppclip: Bool { get }
    static var debug: Bool { get }
    static var defaultHeaders: [String: String] { get }
    
    func modalView(_ item: ModalCoordinator.Item) -> ModalView
    
    func onUserActivity(_ activity: NSUserActivity) -> Void
    func onScenePhaseChange(_ phase: ScenePhase) -> Void
    func onOpenUrl(url: URL) -> Void
    func onConnectionStateChange(_ state: ConnectionState) -> Void
    
    func onInternalError(_ error: Error) -> Void
    func onNotificationRecieved(_ message: Data) async -> Void
    
    func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool) async throws -> Auth?
}

extension Bundle {
    // Name of the app - title under the icon.
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

public func resolveAppInfo() -> (uuid: String?, model: String, name: String, systemVersion: String, appName: String?, appId: String?) {
    var deviceUuid: UUID? = nil
    var deviceUuidString: String? = nil
    
#if os(macOS)
    let model: String = "Mac"
    let name: String = Host.current().localizedName ?? model
    let systemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
#else
    deviceUuid = UIDevice.current.identifierForVendor
    deviceUuidString = deviceUuid?.uuidString
    let model: String = UIDevice.current.model
    let name: String = UIDevice.current.name
    let systemVersion: String = UIDevice.current.systemVersion
#endif
    
    if let deviceUuid = deviceUuid, deviceUuid.isBlank {
        deviceUuidString = UserDefaults.standard.string(forKey: Strings.KEY_DEVICE_UUID) ?? "CLIP-\(UUID().uuidString)"
        UserDefaults.standard.set(deviceUuidString, forKey: Strings.KEY_DEVICE_UUID)
    }
    
    return (uuid: deviceUuidString, model: model, name: name, systemVersion: systemVersion, appName: Bundle.main.displayName, appId: Bundle.main.bundleIdentifier)
}

public func resolveAppVersion() -> Version {
    guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
          let version = Version("\(appVersion).\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")") else {
        return Version.init(1, 0, 0)
    }
    
    return version
}

public extension AppClip {
    
    static var debug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isAppclip: Bool {
        #if APPCLIP
        return true
        #else
        return false
        #endif
    }
    
    static var wssUrlRequest: URLRequest {
        let url = JoliApi.Environment.current.baseUrl.ws
        var request = URLRequest(url: url.appendingPathComponent(Self.debug ? "/api/ws" : "/ws"), cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5)
        request.allHTTPHeaderFields = Self.defaultHeaders
        return request
    }
    
    private func isSimulatorOrTestFlight() -> Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        
        return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
    }
    
    static var version: Version {
        return resolveAppVersion()
    }
    
    static var defaultHeaders: [String: String] {
        
        let appInfo = resolveAppInfo()
        
        var headers = [
            "X-PLATFORM": "ios",
            "X-PLATFORM-VERSION": appInfo.systemVersion,
            "X-DEVICE-UUID": appInfo.uuid ?? "",
            "X-DEVICE-MODEL": appInfo.model,
            "X-DEVICE-NAME": appInfo.name,
            "X-APP-VERSION": Self.version.description,
            "X-APP-SKU": Self.isAppclip ? "APPCLIP" : "FULL",
            //"X-SESSION-ID": activeSessionId,
        ]
        
        if let displayName = appInfo.appName {
            headers["X-APP-NAME"] = displayName
        }
        
        if let appId = appInfo.appId {
            headers["X-APP-ID"] = appId
        }
        
        return headers
    }
    
    var env: JoliApi.Environment {
        guard Self.debug else {
            return .production
        }
        
        let json = JoliApi.Environment.CACHED_ENV_CONFIG
        return JoliApi.Environment(rawValue: json["env"] as? String ?? JoliApi.Environment.local.rawValue) ?? .development
    }
    
    func presentSignInWithApple(callback: @escaping (Bool) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        performSignIn(using: [request], callback: callback)
    }
    
    func performSignIn(using requests: [ASAuthorizationRequest], callback: @escaping (Bool) -> Void) {
        appleSignInDelegates = SignInWithAppleDelegates(window: self.window, keychain: keychain) { data, error in
            print("[\(#file)#performSignIn] auth data: \(String(describing: data))")
            
            guard let data = data,
                  let idToken = data.identityToken,
                  let authCode = data.authorizationCode,
                  let identityToken = String(data: idToken, encoding: .utf8),
                  let authorizationCode = String(data: authCode, encoding: .utf8)
                  else {
                callback(false)
                return
            }
            
            Task() {
                
                do {
                    let auth = try await self.authenticate(.apple(data.user.displayName(), data.user.email, data.user.identifier, identityToken, authorizationCode), alertOnFail: false)
                    callback(auth != nil)
                } catch {
                    callback(false)
                }
            }
            
        }
        
        let controller = ASAuthorizationController(authorizationRequests: requests)
        controller.delegate = appleSignInDelegates
        controller.presentationContextProvider = appleSignInDelegates
        
        controller.performRequests()
    }
    
    func performExistingAccountSetupFlows() {
        #if !targetEnvironment(simulator)
        let requests = [
            ASAuthorizationAppleIDProvider().createRequest(),
            ASAuthorizationPasswordProvider().createRequest()
        ]
        
        // 2
        performSignIn(using: requests) { _ in }
        #endif
    }
    
    private func updateEdgeInsets() {
        guard let windowEdgeInsets = window?.safeAreaInsets else {
            print("[\(Self.self)] no window inserts: \(String(describing: window))")
            return
        }
        
        DispatchQueue.main.async {
            logger.debug("[\(Self.self)] updating edge insets: \(windowEdgeInsets.insets.bottom) - keyboard \(coordinator.keyboardHeight)")
            self.safeAreaInsets = windowEdgeInsets.insets
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack(){
                self.contentView
                    .if(!isMacOs){ view in
                        #if os(macOS)
                        view
                        #else
                        view.addPartialSheet()
                        #endif
                    }
            }
            .sheet(item: self.modalItemBinding){
                DispatchQueue.main.async {
                    defer { self.modalItemOnClose = nil }
                    self.modalItemOnClose?()
                }
            } content: { modalItem in
                GeometryReader() { proxy in
                    self.modalView(modalItem.item)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .edgesIgnoringSafeArea(.all)
            }
            .onOpenURL(perform: self.onOpenUrl)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: self.onUserActivity)
            .onChange(of: scenePhase, perform: self.onScenePhaseChange)
            .onReceive(coordinator.modal.publisher) { modalItem in
                
                guard let modalItem = modalItem else {
                    self.modalItem = nil
                    return
                }
                
                if case let .mailOptions(opts) = modalItem.item, !MFMailComposeViewController.canSendMail() {
                    
                    defer { self.modalItem = nil }
                    
                    guard let encoded = opts.subject.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                          let validUrl = URL(string: "mailto:\(Strings.appSupportEmail)?subject=\(encoded)") else {
                              coordinator.serverLogDestination.send(.error, msg: "[\(Self.self)] unable to send mail: subject=\(opts.subject)",
                                                                    thread: Thread.current.debugDescription, file: #file, function: #function, line: #line)
                              return
                          }
                    
                    #if os(macOS)
                    NSWorkspace.shared.open(validUrl)
                    #else
                    UIApplication.shared.open(validUrl)
                    #endif
                } else {
                    self.modalItem = modalItem
                    self.modalItemOnClose = modalItem.onClose
                }
            }
            .onReceive(coordinator.requestedSignIn) { authFlow in
                switch authFlow {
                    case .apple(let cb):
                        self.presentSignInWithApple(callback: cb)
                    case .spotify(let cb):
                        self.coordinator.pendingSpotifyAuthCallback.send() { success in
                            self.coordinator.pendingSpotifyAuthCallback.send(nil)
                            cb(success)
                        }
                        self.coordinator.spotifyAuthRequestedAt = Date()
                }
            }
            .onReceive(coordinator.requestedNotificationPermission) { ts in
                logger.info("[\(Self.self)] notifictaion requested at: \(ts)")
                appDelegate.registerForPushNotifications()
            }
            .onReceive(apnTokenPublisher) { (notification: Notification) in
                guard let notif = notification.object as? [Notification.Name: Data],
                      let data = notif[Notifications.apnToken] else {
                    return
                }
                
                Task() { await self.onNotificationRecieved(data) }
            }
            .modifier(AppCoordinator.Modifier(coordinator))
            .environment(\.safeAreaInsets, safeAreaInsets)
            .onReceive(coordinator.$keyboardHeight) { _ in
                self.updateEdgeInsets()
            }
            .onAppear() {
                
                self.window = SafeAreaInsetsKey.defaultWindow
                self.updateEdgeInsets()
                
                Task() {
                    do {
                        let info = try await JoliApi.resolveServer(self.coordinator.api.baseUrl.http)
                        await MainActor.run() {
                            logger.info("[\(Self.self)] server info: host=\(self.coordinator.api.baseUrl.http), version=\(info.version), features: \(info.feature), prefferedClientVersion: \(String(describing: info.preferredClientVersion))")
                            self.serverInfo = info
                            self.coordinator.serverInfo = info
                        }
                    } catch {
                        self.coordinator.globalErrorHandler()(error)
                    }
                }
            }
        }
    }
    
    func onInternalError(_ error: Error) {
        logger.debug("[\(Self.self)] error raised: \(String(describing: error))")
    }
    
    func onConnectionStateChange(_ state: ConnectionState) {
        logger.debug("[\(Self.self)] conection state changed: \(state)")
        self.coordinator.onConnectionStateChange(state)
    }
    
    func onOpenUrl(url: URL){
        let prevLoc = self.coordinator.currentLocation
        self.coordinator.currentLocation = AppLocation(url) ?? self.coordinator.currentLocation
        print("[\(Self.self)#onOpenUrl] url: \(url), previousLocation: \(prevLoc), currentLocation: \(self.coordinator.currentLocation)")
        logger.debug("[\(Self.self)#onOpenUrl] url: \(url), previousLocation: \(prevLoc), currentLocation: \(self.coordinator.currentLocation)")
    }
    
    func onScenePhaseChange(_ phase: ScenePhase){
        switch phase {
            case .active:
                print("App became active")
            case .inactive:
                print("App became inactive")
            case .background:
                print("App is running in the background")
            @unknown default:
                // Fallback for future cases
                print("Unknown scene phase: \(phase)")
        }
    }
    
    func onUserActivity(_ activity: NSUserActivity) -> Void {
        let lastLocation = self.coordinator.currentLocation
        self.coordinator.currentLocation = AppLocation(activity) ?? .home
        
        guard lastLocation != self.coordinator.currentLocation else {
            return
        }
        
        let msg = "[\(Self.self)] navigation: \(lastLocation) -> \(self.coordinator.currentLocation)"
        coordinator.serverLogDestination.send(.info, msg: msg, thread: Thread.current.description,
                                               file: #file, function: #function, line: #line)
    }
    
    @MainActor
    func onNotificationRecieved(_ deviceToken: Data) async {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        self.coordinator.apnToken = token
        
        do {
            let device = try await self.coordinator.api.setNotificationToken(token)
            logger.info("Token Saved: \(device)")
        } catch {
            logger.error("Unable to post apn: token=\(token), error=\(String(describing: error))")
            self.coordinator.globalErrorHandler()(error)
        }
    }
    
    func storeToKeychain(_ auths: [Auth]) {
        let jsonEncoder = Musicroom.jsonEncoder()
        
        for auth in auths {
            
            guard let authData = try? jsonEncoder.encode(auth) else {
                continue
            }
            
            try? keychain.remove(auth.user.email)
            
            do {
                try keychain.label("session-token").set(authData, key: auth.user.email)
            } catch {
                self.coordinator.globalErrorHandler()(error)
            }
        }
    }
    
    static func resolveAuths(_ keychain: Keychain) -> [Auth] {
        var auths: [Auth] = []
        let jsonDecoder = Musicroom.jsonDecoder()
        let items = keychain.allKeys()
        
        for item in items {
            
            guard let attributes = try? keychain.get(item, handler: { $0 }),
                  let label = attributes.label,
                  let data = attributes.data,
                  let auth = try? jsonDecoder.decode(Auth.self, from: data),
                  label == "session-token" else {
                continue
            }
            
            auths.append(auth)
        }
        
        return auths.sorted() { ($0.user.displayName.name ?? "") > ($1.user.displayName.name ?? "") }
    }
    
}

public extension UserDefaults {
    
    static var groupContainer: UserDefaults {
        return UserDefaults(suiteName: "group.app.jolimc.Joli") ?? .init()
    }
    
}


public struct ShakeEffect: GeometryEffect {
    
    public var position: CGFloat
    
    public var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
    
    public init(shakes: Int) {
        position = CGFloat(shakes)
    }
    
    public func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(translationX: -30 * sin(position * 2 * .pi), y: 0))
    }
    
}

public struct AppStorageKey: Hashable, Equatable, RawRepresentable, @unchecked Sendable {
    
    public var rawValue: String
    
    public init(_ rawValue: String){
        self.rawValue = rawValue
    }
    
    public init(rawValue: String){
        self.init(rawValue)
    }
    
    public static let authToken: AppStorageKey = .init("auth_token")
    public static let location: AppStorageKey = .init("location")
    public static let isTcAccepted: AppStorageKey = .init("terms_and_conditions_agreed")
    public static let purchasesIdsForTesting: AppStorageKey = .init("testing_purchases")
    
}

public extension AppStorage {
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value == String {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value == Data {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value == Bool {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
}
