//
//  Extensions.swift
//  Joli
//
//  Created by Anthony Chinwo on 31/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliApi
import SwiftUI
import JoliCore
import Promises
import UIKit
import PartialSheet
import Combine

public extension Builder where T == User {
    
    var ranking: DiscjockeyPosition {
        guard let djPosition = self[.djRanking, Int?.self] as? Int else {
            return DiscjockeyPosition.personal
        }
        
        return DiscjockeyPosition(rawValue: djPosition) ?? DiscjockeyPosition.personal
    }
}

extension View {
    
    var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    var screenWidth: CGFloat {
        return screenSize.width
    }
    
    var screenHeight: CGFloat {
        return screenSize.height
    }
    
}


extension View {

    
    func onFrameChange(enabled isEnabled: Bool = true, _ frameHandler: @escaping (CGRect)->()) -> some View {

        guard isEnabled else { return AnyView(self) }

        return AnyView(self.background(GeometryReader() { (geometry: GeometryProxy) in

            Color.clear.beforeReturn {

                frameHandler(geometry.frame(in: .global))
            }
        }))
    }

    private func beforeReturn(_ onBeforeReturn: ()->()) -> Self {
        onBeforeReturn()
        return self
    }
}

extension Spotify.Device {
    
    var imageName: String {
        switch type {
            case .smartphone:
                return "iphone"
            case .computer:
                return "laptopcomputer"
            case .automobile:
                return "car"
            case .tablet:
                return "ipad"
            case .tv:
                return "tv"
            default:
                return "hifispeaker"
        }
    }
}


extension JoliApi {
    
    @discardableResult
    func playMusicroom(_ room: Musicroom, device: Spotify.Device, on: DispatchQueue? = nil) -> Promise<Musicroom> {
        return HttpMethod.Fetch.post(url: "/api/musicrooms/\(room.id)/play?deviceId=\(device.id)", dataType: Musicroom.self, baseUrl: self.baseUrl.http, urlSession: self.urlSession, on: on)
    }
    
    //fetch<T: Codable>(urlString: String, dataType: T.Type, baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil)
    
    public func save<T>(_ model: T, on: DispatchQueue? = nil) -> Promise<T.PersistedType> where T: Persistable {
        return model.save(baseUrl: self.baseUrl.rawValue.http, urlSession: urlSession, on: on)
    }
    
    func fetchQueuedTracks(room: Musicroom, on: DispatchQueue? = nil) -> Promise<[QueuedTrack]> {
        return HttpMethod.Fetch.get(url: "/api/musicrooms/\(room.id)/queued", dataType: [QueuedTrack].self, baseUrl: self.baseUrl.http, urlSession: self.urlSession, on: on)
    }
    
}

extension UIImage {
    
    var noir: UIImage? {
        let context = CIContext(options: nil)
        
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else {
            return nil
        }
        
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        
        guard let output = currentFilter.outputImage, let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    func squared() -> UIImage? {
        guard size.width != size.height else {
            return self
        }

        let cropWidth = min(size.width, size.height)

        let cropRect = CGRect(
            x: (size.width - cropWidth) * scale / 2.0,
            y: (size.height - cropWidth) * scale / 2.0,
            width: cropWidth * scale,
            height: cropWidth * scale
        )

        guard let imageRef = cgImage?.cropping(to: cropRect) else {
            return nil
        }
        //print("[UIImage] new size: \(cropRect)")
        return UIImage(cgImage: imageRef, scale: scale, orientation: imageOrientation)
    }
    
}


public extension String {
    static var empty: String {
        return ""
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

//@available(iOS 7.0, *)
//open class var activityCategory: UIActivity.Category { get } // default is UIActivityCategoryAction.
//
//
//open var activityType: UIActivity.ActivityType? { get } // default returns nil. subclass may override to return custom activity type that is reported to completion handler
//
//open var activityTitle: String? { get } // default returns nil. subclass must override and must return non-nil value
//
//open var activityImage: UIImage? { get } // default returns nil. subclass must override and must return non-nil value
//
//
//open func canPerform(withActivityItems activityItems: [Any]) -> Bool // override this to return availability of activity based on items. default returns NO
//
//open func prepare(withActivityItems activityItems: [Any]) // override to extract items and set up your HI. default does nothing
//
//
//open var activityViewController: UIViewController? { get } // return non-nil to have view controller presented modally. call activityDidFinish at end. default returns nil
//
//open func perform() // if no view controller, this method is called. call activityDidFinish when done. default calls [self activityDidFinish:NO]
//
//
//// state method
//
//open func activityDidFinish(_ completed: Bool) // activity must call this when activity is finished

class ShareActivity: UIActivity {
    
    override var activityType: UIActivity.ActivityType {
        return .copyToPasteboard
    }
    
    override var activityTitle: String? {
        return "Joli"
    } // default returns nil. subclass must override and must return non-nil value
    
    override var activityImage: UIImage? {
        return UIImage(named: "joli_icon.png")!
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
    
    @Published var isSearching = true
    @Published var isSharePresented = false
    public var namespace: Namespace.ID? = nil
    
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


public final class ImageStore {
    typealias _ImageDictionary = [String: CGImage]
    fileprivate var images: _ImageDictionary = [:]

    fileprivate static var scale = 2
    
    public static var shared = ImageStore()
    
    public func image(name: String) -> SwiftUI.Image {
        let index = _guaranteeImage(name: name)
        
        return Image(images.values[index], scale: CGFloat(ImageStore.scale), label: Text(verbatim: name))
    }

    public static func loadImage(name: String) -> CGImage {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "jpg") ?? Bundle.main.url(forResource: name, withExtension: "png"),
            let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            fatalError("Couldn't load image \(name).jpg from main bundle.")
        }
        return image
    }
    
    fileprivate func _guaranteeImage(name: String) -> _ImageDictionary.Index {
        if let index = images.index(forKey: name) { return index }
        
        images[name] = ImageStore.loadImage(name: name)
        return images.index(forKey: name)!
    }
}
