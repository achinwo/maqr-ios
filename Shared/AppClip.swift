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
            print("Failed to parse (stringLiteral) as a regular expression")
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
        return dict.count > 0 ? dict : nil
    }
    
    public static let phone: Regex = "^(\\+\\d{1,2}\\s)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}$"
}

public extension Regex {
    static func ~=(pattern: Regex, value: String) -> Bool {
        return pattern.match(value)
    }
}

public enum AppLocation: RawRepresentable {
    
    case invited(String) // joli.live/r/abc
    case playroom(String)
    
    case home
    
    static var `default` = "/"
    
    public init?(rawValue: String) {
        let patterns = AppLocation.patterns
        
        if let matches = patterns.invited.matchGroups(rawValue), let inviteId = matches["inviteId"] {
            self = .invited(inviteId)
        } else if let matches = patterns.playroom.matchGroups(rawValue), let roomId = matches["roomId"] {
            self = .playroom(roomId)
        } else if rawValue.isEmpty || rawValue == AppLocation.default {
            self = .home
        } else {
            return nil
        }
    }
    
    public var rawValue: String {
        switch self {
            case .invited(let inviteId):
                return "/join/\(inviteId)"
            case .playroom(let roomId):
                return "/r/\(roomId)"
            default:
                return AppLocation.default
        }
    }
    
    static var patterns = (
        home: Regex("^/$"),
        invited: Regex("^/join/(?<inviteId>.+)$"),
        playroom: Regex("^/r/(?<roomId>.+)$")
    )
    
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
}

extension JoliView {
    
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

public final class AppCoordinator: ObservableObject {
    
    public var currentLocation: AppLocation = .home
    public var sheet: PartialSheetManager = PartialSheetManager()
    
    @Published public var isSearching = true
    @Published public var isSharePresented = false
    @Published public var namespace: Namespace.ID? = nil
    
    public init(namespace: Namespace.ID? = nil){
        self.namespace = namespace
    }
    
    public func share(text: String){
        isSharePresented.toggle()
        //
        let text = "You have been invited to join the room. Go to https://api.jolimc.com/join/abcd to join the room."
        let av = UIActivityViewController(activityItems: [text], applicationActivities: [ShareActivity()])
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true) {
            print("[AppCoordinator#share] share view presented")
        }
    }
    
    public func withImpact(_ impact: UIImpactFeedbackGenerator.FeedbackStyle = .soft, _ action: () -> Void){
        let impactHeavy = UIImpactFeedbackGenerator(style: impact)
        action()
        impactHeavy.impactOccurred()
    }
    
    public struct Modifier: ViewModifier {
        
        let coordinator: AppCoordinator
        
        public init(_ coordinator: AppCoordinator){
            self.coordinator = coordinator
        }
        
        public func body(content: Content) -> some View {
            return content
                .environmentObject(self.coordinator)
                .environmentObject(self.coordinator.sheet)
        }
        
    }
    
}

public protocol AppClip: App {
    associatedtype Content: View
    
    var contentView: Content { get }
    var scenePhase: ScenePhase { get }
    var coordinator: AppCoordinator { get }
    var namespace: Namespace.ID { get }
    
    func onUserActivity(_ activity: NSUserActivity) -> Void
    
}

public extension AppClip {
    
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
