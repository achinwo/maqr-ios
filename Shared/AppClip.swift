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
import Promises
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
}

public typealias UIWindow = NSWindow
public typealias UIEdgeInsets = NSEdgeInsets

public extension UIWindow {
    
    var safeAreaInsets: NSEdgeInsets {
        return .init()
    }
}

#else
import UIKit
import PartialSheet

public typealias FeedbackStyle = UIImpactFeedbackGenerator.FeedbackStyle
#endif

public struct ShortCodeGenerator {

    private static let base62chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".unicodeScalars.map() {
        Character($0)
    }
    
    private static let maxBase: UInt32 = 62

    static func getCode(withBase base: UInt32 = maxBase, length: Int = 16) -> String {
        var code = ""
        for _ in 0..<length {
            let random = Int(arc4random_uniform(min(base, maxBase)))
            code.append(base62chars[random])
        }
        return code
    }
}


public enum SpotifyError: Error {
    case unathorized
}


public enum ImageExtension: String, CaseIterable {
    
    case jpeg = "jpg"
    case png = "png"
    
    public init?(rawValue: String) {
        switch rawValue.lowercased() {
            case Self.png.rawValue:
                self = .png
            case Self.jpeg.rawValue, "jpeg":
                self = .jpeg
            default:
                return nil
        }
    }
    
}

public extension Data {
    
    var countMb: Double {
        return Double(count) / (1024 * 1024)
    }
    
    var sizeFormatted: String {
        return self.sizeFormatted([.useMB])
    }
    
    func sizeFormatted(_ allowedUnits: ByteCountFormatter.Units = [.useMB], countStyle: ByteCountFormatter.CountStyle = .file) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = allowedUnits // optional: restricts the units to MB only
        bcf.countStyle = countStyle
        return bcf.string(fromByteCount: Int64(count))
    }
    
}

public extension JoliApi {
    
    static func createMultipartBody(data: Data, boundary: String, file: String) -> Data {
        var body = Data()
        let ln = "\r\n"
        let boundaryPrefix = "--\(boundary)\(ln)"
        body.append(boundaryPrefix)
        body.append("Content-Disposition: form-data; name=\"\(file)\"; filename=\"\(file)\"\(ln)")
        body.append("Content-Type: application/octet-stream;charset=utf-8\(ln + ln)")
        body.append(data)
        body.append(ln)
        body.append("--\(boundary)--\(ln)")
        return body
    }
    
    @available(iOS 14.0, *)
    static func upload(_ image: UIImage, fileName: String? = nil, ext: ImageExtension = .jpeg, timeout: TimeInterval = 60.0, baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil) -> Promise<URL> {
        
        let fileName = fileName ?? "\(ShortCodeGenerator.getCode().lowercased()).\(ext.rawValue)"
        
        let fileExt = URL(fileURLWithPath: fileName).pathExtension
        guard let extResolved = ImageExtension(rawValue: fileExt), extResolved == ext else {
            print("[upload] Unable to resolve extension: \(fileExt)")
            return Promise(NetworkError.badRequest("Invalid file extension \"\(fileExt)\""))
        }
        
        
        guard let imageData = (ext == .jpeg ? image.jpegData(compressionQuality: 0.2) : image.pngData()) else {
            return Promise(NetworkError.badRequest("Unable to convert image to data"))
        }
        
        let boundary = "Boundary-562F49C8-26CD-4D87-9C8F-DEA380DE4BF007"
        let url = URL(string: "/images", relativeTo: baseUrl)!
        
        var urlRequest: URLRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post.rawValue
        
        let data = Self.createMultipartBody(data: imageData, boundary: boundary, file: fileName)
        urlRequest.httpBody = data
        urlRequest.timeoutInterval = timeout
        
        urlRequest.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(data.count.description, forHTTPHeaderField: "Content-Length")
        
        let session = urlSession ?? URLSession.shared
        
        print("actual size of image in Mb: \(imageData.sizeFormatted)")
        
        return Promise() { (resolve, reject) in
            let task = session.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
                
                guard error == nil else {
                    reject(NetworkError.badResponse(error!.localizedDescription))
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? Json,
                      let fileName = json["fileName"] as? String,
                      let url = URL(string: fileName, relativeTo: baseUrl) else {
                    reject(NetworkError.badResponse("Deserialization error - image upload \(ext) \(String(data: data ?? Data(), encoding: .utf8))"))
                    return
                }
                
                resolve(url)
            }
            
            task.resume()
        }
    }
}


public enum AppStorageKey: String {
    case authToken = "auth_token"
    case location = "location"
}

public struct Regex: ExpressibleByStringLiteral, Equatable {
    
    fileprivate let expression: NSRegularExpression
    private let regexString: String
    
    public init(stringLiteral: String) {
        self.regexString = stringLiteral
        do {
            self.expression = try NSRegularExpression(pattern: stringLiteral, options: [])
        } catch {
            print("Failed to parse \"\(stringLiteral)\" as a regular expression")
            self.expression = try! NSRegularExpression(pattern: ".*", options: [])
        }
    }
    
    public func match(_ input: String) -> Bool {
        let result = expression.rangeOfFirstMatch(in: input, options: [],
                                                  range: NSRange(input.startIndex..., in: input))
        return NSEqualRanges(result, NSMakeRange(NSNotFound, 0))
    }
    
    public func matchGroups(_ string: String) -> [String: String]? {
        guard let nameRegex = try? NSRegularExpression(pattern: "\\(\\?\\<(\\w+)\\>", options: []) else {
            return nil
        }
        
        let nameMatches = nameRegex.matches(in: regexString, options: [], range: NSMakeRange(0, regexString.count))
        let names = nameMatches.map { (textCheckingResult) -> String in
            return (regexString as NSString).substring(with: textCheckingResult.range(at: 1))
        }
        
        guard let regex = try? NSRegularExpression(pattern: regexString, options: []) else {
            return nil
        }
        
        let result = regex.firstMatch(in: string, options: [], range: NSMakeRange(0, string.count))
        var dict = [String: String]()
        
        for name in names {
            guard let nsRange = result?.range(withName: name), let range = Range(nsRange, in: string) else {
                continue
            }
            
            dict[name] = String(string[range])
        }
        return dict.isEmpty ? nil : dict
    }
    
    public static let phone: Regex = "^(\\+\\d{1,2}\\s)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}$"
}

public extension Regex {
    static func ~=(pattern: Regex, value: String) -> Bool {
        return pattern.match(value)
    }
}

public enum AppLocation: RawRepresentable, CustomStringConvertible, Equatable {
    
    case invited(String) // joli.live/r/abc
    case playroom(String)
    case rsvp(String)
    case reward(String)
    case product(String, String)
    
    case unset
    case home
    case upgrade
    case error
    
    static var `default` = "/"
    
    public init?(rawValue: String) {
        let patterns = AppLocation.patterns
        
        if let matches = patterns.invited.matchGroups(rawValue), let inviteId = matches["inviteId"] {
            self = .invited(inviteId)
        } else if let matches = patterns.playroom.matchGroups(rawValue), let roomId = matches["roomId"] {
            self = .playroom(roomId)
        } else if let matches = patterns.rsvp.matchGroups(rawValue), let eventId = matches["eventId"] {
            self = .rsvp(eventId)
        } else if let matches = patterns.reward.matchGroups(rawValue), let rewardUid = matches["rewardId"] {
            self = .reward(rewardUid)
        } else if let matches = patterns.product.matchGroups(rawValue),
                  let storeId = matches["storeId"],
                  let productId = matches["productId"] {
            self = .product(storeId, productId)
        } else if rawValue == AppLocation.upgrade.rawValue {
            self = .upgrade
        } else if rawValue == AppLocation.default {
            self = .home
        } else if rawValue.isEmpty {
            self = .unset
        } else {
            return nil
        }
        
    }
    
    public var rawValue: String {
        switch self {
            case .upgrade:
                return "/upgrade"
            case .invited(let inviteId):
                return "/i/\(inviteId)"
            case .playroom(let roomId):
                return "/r/\(roomId)"
            case .unset:
                return .empty
            case .rsvp(let eventId):
                return "/rsvp/b/\(eventId)"
            case .reward(let uid):
                return "/ir/\(uid)"
            case .product(let storeId, let pId):
                return "/s/\(storeId)/\(pId)"
            default:
                return AppLocation.default
        }
    }
    
    static var patterns = (
        home: Regex("^/$"),
        invited: Regex("^/(playroom/invite|i)/(?<inviteId>.+)$"),
        playroom: Regex("^/r/(?<roomId>.+)$"),
        rsvp: Regex("^/rsvp/b/(?<eventId>.+)$"),
        reward: Regex("^/ir/(?<rewardId>.+)$"),
        product: Regex("^/s/(?<storeId>.+)/(?<productId>.+)$")
    )
    
    public var description: String {
        guard self != .unset else {
            return "\(Self.self)(<unset>)"
        }
        
        return "\(Self.self)(\(rawValue))"
    }
    
}

public extension AppLocation {
    
    init?(_ activity: NSUserActivity){
        guard let incomingUrl = activity.webpageURL else {
            logger.error("[AppLocation] unable to resolve activity: \(activity)")
            return nil
        }
        
        self.init(incomingUrl)
    }
    
    init?(_ url: URL){
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            logger.error("[AppLocation] unable to resolve: \(url)")
            return nil
        }
        
        self.init(rawValue: components.path)
    }
    
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
            }//.toast(isPresenting: <#T##Binding<Bool>#>, alert: <#T##() -> AlertToast#>)
        
            //.toast(isPresenting: isPresentingToast, alert: <#T##() -> AlertToast#>)
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
    
    var env: JoliApi.Environment { get }
    var contentView: Content { get }
    var scenePhase: ScenePhase { get }
    var coordinator: AppCoordinator { nonmutating get }
    var namespace: Namespace.ID { get }
    var appleSignInDelegates: SignInWithAppleDelegates? { get nonmutating set }
    var serverVersion: Version? { get nonmutating set }
    var apnTokenPublisher: NotificationCenter.Publisher { get }
    
    var websocket: Socket { get }
    var window: UIWindow? { get nonmutating set }
    var safeAreaInsets: EdgeInsets { get nonmutating set }
    
    var keychain: Keychain { get }
    var auths: [Auth] { get nonmutating set }
    var activeSessionToken: String? { get nonmutating set }
    
    static var version: Version { get }
    static var isAppclip: Bool { get }
    static var debug: Bool { get }
    static var defaultHeaders: [String: String] { get }
    
    func onUserActivity(_ activity: NSUserActivity) -> Void
    func onScenePhaseChange(_ phase: ScenePhase) -> Void
    func onOpenUrl(url: URL) -> Void
    func onConnectionStateChange(_ state: ConnectionState) -> Void
    
    func onInternalError(_ error: Error) -> Void
    func onNotificationRecieved(_ message: Data) -> Void
    
    func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool) -> Promise<Auth?>
}

extension Bundle {
    // Name of the app - title under the icon.
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? object(forInfoDictionaryKey: "CFBundleName") as? String
    }
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
    // MARK: - authenticate
    @discardableResult
    func authenticate(_ credentials: JoliApi.AuthCredentials, alertOnFail: Bool = true) -> Promise<Auth?> {
        
        if case let .sessionToken(token) = credentials, token.isEmpty {
            logger.error("[\(Self.self)#authentication] call aborted, empty token")
            return Promise<Auth?>(nil)
        }
        
        return coordinator.api.authenticate(credentials)
            .then() { auth -> Auth? in
                
                guard let auth = auth else {
                    return nil
                }
                
                var newAuths = self.auths.filter() { $0.session.userId != auth.session.userId}
                newAuths.append(auth)
                
                self.auths = newAuths
                
                self.activeSessionToken = auth.session.token
                
                storeToKeychain(newAuths)
                self.coordinator.api.auth = auth
                
                self.coordinator.authsSubject.send(newAuths)
                self.coordinator.activeSessionToken = self.activeSessionToken
                
                let points = CGFloat(auth.user.heartPoints ?? 375)
                self.coordinator.userHeartsSubject.send(Hearts(score: points <= HeartLevel.empty.rawValue ? HeartLevel.quarter.rawValue : points))
                
                //logger.debug("[App#authentication] activeSessionToken: \(String(describing: self.activeSessionToken))")
                
                DispatchQueue.main.async { // Hack - authentication sideeffect needs refactoring
                    if case .spotifyRefreshToken(_) = credentials, let pendingCallback = self.coordinator.pendingSpotifyAuthCallback.value {
                        pendingCallback(true)
                    }
                }
                
                return auth
            }
            .catch() { error in
                logger.error("[App#authentication] creds: \(String(describing: credentials)), error: \(String(describing: error))")
                
                DispatchQueue.main.async { // Hack - authentication sideeffect needs refactoring
                    if case .spotifyRefreshToken(_) = credentials, let pendingCallback = self.coordinator.pendingSpotifyAuthCallback.value {
                        pendingCallback(false)
                    }
                }
                
                guard case let .sessionToken(token) = credentials, let error = error as? SpotifyError, error != SpotifyError.unathorized else {
                    
                    
                    if alertOnFail {
                        let message = "If the issue persists, try closing and re-launching the app"
                        coordinator.withAlert("Unable to complete Sign In", message: message)
                    }
                    
                    return
                }
                
                let auths = self.auths.filter() { $0.session.token != token}.sorted(by: { $0.user.name < $1.user.name })
                storeToKeychain(auths)
            }
            .always {
                
                defer {
                    websocket.connect()
                }
                
                guard let token = activeSessionToken, !self.websocket.isConnected else { return }
                
                var req = Self.wssUrlRequest
                req.addValue(token, forHTTPHeaderField: "X-SESSION-ID")
                websocket.request = req
            }
    }
    
    static var wssUrlRequest: URLRequest {
        let url = JoliApi.Environment.current.baseUrl.ws
        var request = URLRequest(url: url.appendingPathComponent("/ws"), cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5)
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
        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let version = Version("\(appVersion).\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")") else {
            return Version.init(1, 0, 0)
        }
        
        return version
    }
    
    static var defaultHeaders: [String: String] {
        
        #if os(macOS)
        let uuid: String? = nil
        let model: String = "Mac"
        let name: String = Host.current().localizedName ?? model
        #else
        let uuid: String? = UIDevice.current.identifierForVendor?.uuidString
        let model: String = UIDevice.current.model
        let name: String = UIDevice.current.name
        #endif
        
        var headers = [
            "X-PLATFORM": "ios",
            "X-PLATFORM-VERSION": UIDevice.current.systemVersion,
            "X-DEVICE-UUID": uuid ?? "",
            "X-DEVICE-MODEL": model,
            "X-DEVICE-NAME": name,
            "X-APP-VERSION": Self.version.description,
            "X-APP-SKU": Self.isAppclip ? "APPCLIP" : "FULL",
            //"X-SESSION-ID": activeSessionId,
        ]
        
        if let displayName = Bundle.main.displayName {
            headers["X-APP-NAME"] = displayName
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
            
            self.authenticate(.apple(data.user.displayName(), data.user.email, data.user.identifier, identityToken, authorizationCode), alertOnFail: false)
                .then() { auth in
                    callback(auth != nil)
                }
                .catch() { _ in
                    callback(false)
                }
            
//            if success {
//                // update UI
//            } else {
//                // show the user an error
//            }
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
            .onOpenURL(perform: self.onOpenUrl)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: self.onUserActivity)
            .onChange(of: scenePhase, perform: self.onScenePhaseChange)
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
            .onReceive(apnTokenPublisher) { (notification: Notification) in
                guard let notif = notification.object as? [Notification.Name: Data],
                      let data = notif[Notifications.apnToken] else {
                    return
                }
                
                self.onNotificationRecieved(data)
            }
            .modifier(AppCoordinator.Modifier(coordinator))
            .environment(\.safeAreaInsets, safeAreaInsets)
            .onReceive(coordinator.$keyboardHeight) { _ in
                self.updateEdgeInsets()
            }
            .onAppear() {
                
                self.window = SafeAreaInsetsKey.defaultWindow
                self.updateEdgeInsets()
                
                JoliApi.resolveServer(self.coordinator.api.baseUrl.http)
                    .timeout(3.0)
                    .then(on: .main) { version in
                        logger.info("[\(Self.self)] server info: host=\(self.coordinator.api.baseUrl.http), version=\(version)")
                        self.serverVersion = version
                    }
                    .catch(self.coordinator.globalErrorHandler())
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
        coordinator.serverLogDestination?.send(.info, msg: msg, thread: Thread.current.description,
                                               file: #file, function: #function, line: #line)
    }
    
    func onNotificationRecieved(_ deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        self.coordinator.api.setNotificationToken(token)
            .then() { device in
                logger.info("Token Saved: \(device)")
            }
            .catch(self.coordinator.globalErrorHandler())
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

public extension AppStorage {
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value == String {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
    init(wrappedValue: Value, key: AppStorageKey, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {
        self.init(wrappedValue: wrappedValue, key.rawValue, store: store)
    }
    
}
