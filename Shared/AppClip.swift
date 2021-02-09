//
//  AppClip.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import PartialSheet
import JoliApi
import JoliCore
import Promises
import Combine

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

public enum ImageExtension: String, CaseIterable {
    case jpeg = "jpg"
    case png = "png"
}

public extension JoliApi {
    
    func createMultipartBody(data: Data, boundary: String, file: String) -> Data {
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
    
    func upload(_ image: UIImage, fileName: String? = nil, ext: ImageExtension = .jpeg, timeout: TimeInterval = 60.0) -> Promise<URL> {
        
        let fileName = fileName ?? "\(ShortCodeGenerator.getCode().lowercased()).\(ext.rawValue)"
        
        let fileExt = URL(fileURLWithPath: fileName).pathExtension
        guard let extResolved = ImageExtension(rawValue: fileExt), extResolved == ext else {
            return Promise(NetworkError.badRequest("Invalid file extension \"\(fileExt)\""))
        }
        
        guard let imageData = (ext == .jpeg ? image.pngData() : image.jpegData(compressionQuality: 0.5)) else {
            return Promise(NetworkError.badRequest("Unable to convert image to data"))
        }
        
        let boundary = "Boundary-562F49C8-26CD-4D87-9C8F-DEA380DE4BF007"
        let url = URL(string: "/images", relativeTo: baseUrl.http)!
        
        var urlRequest: URLRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post.rawValue
        
        let data = createMultipartBody(data: imageData, boundary: boundary, file: fileName)
        urlRequest.httpBody = data
        urlRequest.timeoutInterval = timeout
        
        urlRequest.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(data.count.description, forHTTPHeaderField: "Content-Length")
        
        return Promise() { (resolve, reject) in
            let task = self.urlSession.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
                
                guard error == nil else {
                    reject(NetworkError.badResponse(error!.localizedDescription))
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? Json,
                      let fileName = json["fileName"] as? String,
                      let url = URL(string: fileName, relativeTo: self.baseUrl.http) else {
                    reject(NetworkError.badResponse("Deserialization error"))
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

public enum AppLocation: RawRepresentable, CustomStringConvertible {
    
    case invited(String) // joli.live/r/abc
    case playroom(String)
    
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
        } else if rawValue == AppLocation.upgrade.rawValue {
            self = .upgrade
        } else if rawValue.isEmpty || rawValue == AppLocation.default {
            self = .home
        } else {
            return nil
        }
        
    }
    
    public var rawValue: String {
        switch self {
        case .upgrade:
            return "/upgrade"
            case .invited(let inviteId):
                return "/playroom/invite/\(inviteId)"
            case .playroom(let roomId):
                return "/r/\(roomId)"
            default:
                return AppLocation.default
        }
    }
    
    static var patterns = (
        home: Regex("^/$"),
        invited: Regex("^/playroom/invite/(?<inviteId>.+)$"),
        playroom: Regex("^/r/(?<roomId>.+)$")
    )
    
    public var description: String {
        return "\(Self.self)(\(rawValue))"
    }
    
}

public extension AppLocation {
    
    init?(_ activity: NSUserActivity){
        guard let incomingUrl = activity.webpageURL,
              let components = URLComponents(url: incomingUrl, resolvingAgainstBaseURL: true) else {
            logger.info("[AppLocation] unable to resolve: \(activity)")
            return nil
        }
        
        self.init(rawValue: components.path)
    }
}

public extension PartialSheetManager {
    
    func show<T>(_ onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> T) where T: SwiftUI.View {
        self.showPartialSheet(onDismiss, content: content)
    }
}

public protocol JoliView: View {
    var appCoordinator: AppCoordinator { get }
    var api: JoliApi { get }
}

extension JoliView {
    
    public var api: JoliApi {
        return appCoordinator.api
    }
    
    public func withImpact(_ impact: UIImpactFeedbackGenerator.FeedbackStyle = .soft, animated: Animation? = nil, _ action: () -> Void){
        if let animation = animated {
            withAnimation(animation) {
                appCoordinator.withImpact(impact, action)
            }
        } else {
            appCoordinator.withImpact(impact, action)
        }
    }
}

class ShareActivity: UIActivity {
    
    override var activityType: UIActivity.ActivityType {
        return .copyToPasteboard
    }
    
    override var activityTitle: String? {
        return "Joli"
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



public protocol AppClip: App {
    associatedtype Content: View
    
    var env: JoliApi.Environment { get }
    var contentView: Content { get }
    var scenePhase: ScenePhase { get }
    var coordinator: AppCoordinator { nonmutating get }
    var namespace: Namespace.ID { get }
    
    func onUserActivity(_ activity: NSUserActivity) -> Void
    func onScenePhaseChange(_ phase: ScenePhase) -> Void
    func onOpenUrl(url: URL) -> Void
    func onConnectionStateChange(_ state: ConnectionState) -> Void
    
    func onInternalError(_ error: Error) -> Void
}

public extension AppClip {
    
    var debug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var env: JoliApi.Environment {
        guard self.debug else {
            return .production
        }
        
        let json = JoliApi.Environment.CACHED_ENV_CONFIG
        return JoliApi.Environment(rawValue: json["env"] as? String ?? JoliApi.Environment.local.rawValue) ?? .development
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack(){
                self.contentView
                    .addPartialSheet()
            }
            .onOpenURL(perform: self.onOpenUrl)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: self.onUserActivity)
            .onChange(of: scenePhase, perform: self.onScenePhaseChange)
            .modifier(AppCoordinator.Modifier(coordinator))
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
        logger.debug("[\(Self.self)] open URL: \(url)")
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
        self.coordinator.currentLocation = AppLocation(activity) ?? .home
    }
    
}

public extension UserDefaults {
    
    static var groupContainer: UserDefaults {
        return UserDefaults(suiteName: "group.app.jolimc.Joli") ?? .init()
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
