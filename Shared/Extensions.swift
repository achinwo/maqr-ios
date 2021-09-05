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

#if os(macOS)
import AppKit
public typealias UIApplication = NSApplication

#else
import UIKit
import PartialSheet

#endif

import Combine
import UIImageColors


public typealias Color = SwiftUI.Color
public typealias View = SwiftUI.View

public typealias MultilineString = String


public extension String {
    func count(of needle: Character) -> Int {
        return reduce(0) {
            $1 == needle ? $0 + 1 : $0
        }
    }
}

public extension URL {
    
    init(staticString: StaticString){
        self.init(string: "\(staticString)")!
    }
}

public extension View {
    
    func snapshot(_ backgroundColor: Color = .clear) -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = UIColor(backgroundColor)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
}

public extension UIImageColors {
    
    var primaryColor: Color {
        return Color(primary)
    }
    
    var backgroundColor: Color {
        return Color(background)
    }
    
    var secondaryColor: Color {
        return Color(secondary)
    }
    
    var detailColor: Color {
        return Color(detail)
    }
    
}

extension QueuedTrack {
    
    public var colors: UIImageColors? {
        guard let bg = track?.colorBackground, let primary = track?.colorPrimary, let sec = track?.colorSecondary, let detail = track?.colorDetail else {
            return nil
        }
        return .init(background: UIColor(hex: bg),
                     primary: UIColor(hex: primary),
                     secondary: UIColor(hex: sec),
                     detail: UIColor(hex: detail))
    }
    
}

extension UIColor {
    
    public convenience init(hex: String) {
        let rgba = Color.rgbaFrom(hex: hex)
        self.init(red: CGFloat(rgba.red), green: CGFloat(rgba.green), blue: CGFloat(rgba.blue), alpha: CGFloat(rgba.alpha))
    }
    
}

public extension Color {
    
    var hexString: String {
        return UIColor(self).hexString
    }
    
    static func rgbaFrom(hex: String) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = .zero
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
            case 3: // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (1, 1, 1, 0)
        }
        
        return (
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
    
    init(hex: String) {
        let rgba = Self.rgbaFrom(hex: hex)
        
        self.init(
            .sRGB,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }
}

public extension Builder where T == User {
    
    var ranking: DiscjockeyPosition {
        guard let djPosition = self[.djRanking, Int?.self] as? Int else {
            return DiscjockeyPosition.personal
        }
        
        return DiscjockeyPosition(rawValue: djPosition) ?? DiscjockeyPosition.personal
    }
}


public extension View {
    
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
        
    func gradientForeground(colors: [Color]) -> some View {
        self.overlay(AngularGradient(gradient: Gradient(colors: colors),
                                     center: UnitPoint(x: 0.5, y: 1),
                                     angle: Angle(degrees: 0.00)))
            .mask(self)
    }
    
}

extension Array where Element == DispatchWorkItem {
    
    func cancelAll(){
        print("[App#DispatchWorkItems] cancelling \(self.count) items...")
        
        for item in self {
            item.cancel()
        }
    }
    
}


public extension PlayState {
    
    static var allColors: [Color] {
        return [
            .systemRed,
            .systemYellow,
            .systemBlue,
            .systemPink,
            .systemGreen,
            .systemOrange,
            .systemPurple,
        ]
    }
    
    var color: Color {
        let colors = Self.allColors
        let color = colors[(userName.count + userName.lowercased().count(of: "g")) % colors.count ]
        return color
    }
}

#if os(macOS)
public typealias UIActivityIndicatorView = NSProgressIndicator
public typealias UIViewRepresentable = NSViewRepresentable
public typealias UIViewRepresentableContext = NSViewRepresentableContext
#endif

public extension Search.Category {
 
    mutating func empty() {
        for cat in Self.allCases {
            self.remove(cat)
        }
    }
    
}


public extension Search.Engine {
    
    typealias SearchMethod2 = (String, Set<Search.Category>, Int) -> AnyPublisher<Spotify.SearchResult?, Never>
    
    func search(_ q: String, _ categories: Set<Search.Category>, limit: Int = 6, search searchFn: SearchMethod2) -> AnyPublisher<Spotify.SearchResult?, Never> {
        let supported = categories.filter(){ supportedCategories.contains($0) }
        
        guard !supported.isEmpty else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        return searchFn(q, supported, limit)
    }
    
}


public extension Character {
    var stringValue: String {
        return String(self)
    }
}

public extension Image {
    
    init(platformImage: UIImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
    
}




public extension Array where Element == Spotify.Image {
    
    var smallestImage: Spotify.Image? {
        return self.last
    }
    
    var largestImage: Spotify.Image? {
        return self.first
    }
    
    var mediumImage: Spotify.Image? {
        guard count >= 2 else {
            return self.largestImage
        }
        return self[1]
    }
    
}

public extension Search {
    
    struct ResultView: JoliView, Identifiable {
        
        @EnvironmentObject public var appCoordinator: AppCoordinator
        
        @GestureState var isTapping = false
        
        public var result: Result
        
        public var id: String {
            return result.id
        }
        
        private let content: () -> GeometryReader<AnyView>
        
        public init(result: Result, @ViewBuilder content: @escaping () -> GeometryReader<AnyView>){
            self.result = result
            self.content = content
        }
        
        public var contentView: some View {
//            let tap = TapGesture()
//                .updating($isTapping) { currentState, state, transaction in
//                    state = true
//                }
            content()
                .id(self.id)
//                .scaleEffect(x: isTapping ? 0.8 : 1, y: isTapping ? 0.8 : 1)
//                .simultaneousGesture(tap)
        }
    }
}

public extension View {
    
    var screenSize: CGSize {
        #if os(macOS)
        return CGSize(width: 400, height: 600)//NSScreen.main?.frame.size ?? .zero
        #else
        return UIScreen.main.bounds.size
        #endif
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
    
    #if os(macOS)
    var scale: CGFloat {
        1.0
    }
    #endif
    
    var noir: UIImage? {
        let context = CIContext(options: nil)
        
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else {
            return nil
        }
        
        #if !os(macOS)
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        
        guard let output = currentFilter.outputImage, let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        #else
        return nil
        #endif
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
        
        #if os(macOS)
        return nil
        #else
        guard let imageRef = cgImage?.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: imageRef, scale: scale, orientation: imageOrientation)
        #endif
    }
    
}


public extension String {
    static var empty: String {
        return ""
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

extension Data {
    
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else {
          return
        }
        
        self.append(data)
    }
}

extension UIApplication {
    func endEditing(_ force: Bool) {
        #if os(macOS)
        
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(for: force)
        #else
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(force)
        #endif
    }
}

struct ResignKeyboardOnDragGesture: ViewModifier {
    
    var gesture = DragGesture().onChanged{_ in
        UIApplication.shared.endEditing(true)
    }
    
    func body(content: Content) -> some View {
        content.simultaneousGesture(gesture)
    }
    
}

public extension View {
    
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
    
    func onReceive<P, Root>(_ publisher: P, assign: WritableKeyPath<Root, P.Output>, target: Root) -> some View where P : Publisher, P.Failure == Never {
        return self.onReceive(publisher) { value in
            var target = target
            target[keyPath: assign] = value
        }
    }
    
    @ViewBuilder
    func ifLet<V, Transform: View>(_ value: V?, transform: (Self, V) -> Transform) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(_ condition: Bool,if ifTransform: (Self) -> TrueContent, else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
    
}

#if os(macOS)
extension UIColor {
    public static let label = UIColor.controlColor
    public static let secondaryLabel = UIColor.controlBackgroundColor
    public static let tertiaryLabel = UIColor.controlBackgroundColor
    public static let quaternaryLabel = UIColor.controlBackgroundColor
    public static let link = UIColor.controlBackgroundColor
    public static let placeholderText = UIColor.controlBackgroundColor
    
    // Adaptable separators
    public static let separator = UIColor.controlBackgroundColor
    public static let opaqueSeparator = UIColor.controlBackgroundColor
    
    public static let systemBackground = UIColor.controlBackgroundColor
    public static let secondarySystemBackground = UIColor.controlBackgroundColor
    public static let tertiarySystemBackground = UIColor.controlBackgroundColor
    
    
    // Adaptable grouped backgrounds
    public static let systemGroupedBackground = UIColor.controlBackgroundColor
    public static let secondarySystemGroupedBackground = UIColor.controlBackgroundColor
    public static let tertiarySystemGroupedBackground = UIColor.controlBackgroundColor
    
    // Adaptable system fills
    public static let systemFill = UIColor.controlBackgroundColor
    public static let secondarySystemFill = UIColor.controlBackgroundColor
    public static let tertiarySystemFill = UIColor.controlBackgroundColor
    public static let quaternarySystemFill = UIColor.controlBackgroundColor
}
#endif

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension Color {
    
    #if !os(watchOS) // watchOS doesn't support adaptable colors.
    // Adaptable colors
    public static let systemRed = Color(UIColor.systemRed)
    public static let systemGreen = Color(UIColor.systemGreen)
    public static let systemBlue = Color(UIColor.systemBlue)
    public static let systemOrange = Color(UIColor.systemOrange)
    public static let systemYellow = Color(UIColor.systemYellow)
    public static let systemPink = Color(UIColor.systemPink)
    public static let systemPurple = Color(UIColor.systemPurple)
    public static let systemTeal = Color(UIColor.systemTeal)
    public static let systemIndigo = Color(UIColor.systemIndigo)
    
    // Adaptable grayscales
    public static let systemGray = Color(UIColor.systemGray)
    #if os(iOS) // tvOS doesn't have the adaptable gray shades, just the primary color.
    public static let systemGray2 = Color(UIColor.systemGray2)
    public static let systemGray3 = Color(UIColor.systemGray3)
    public static let systemGray4 = Color(UIColor.systemGray4)
    public static let systemGray5 = Color(UIColor.systemGray5)
    public static let systemGray6 = Color(UIColor.systemGray6)
    #endif //!tvOS
    
    // Adaptable text colors
    public static let label = Color(UIColor.label)
    public static let secondaryLabel = Color(UIColor.secondaryLabel)
    public static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    public static let quaternaryLabel = Color(UIColor.quaternaryLabel)
    public static let link = Color(UIColor.link)
    public static let placeholderText = Color(UIColor.placeholderText)
    
    // Adaptable separators
    public static let separator = Color(UIColor.separator)
    public static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    
    #if !os(tvOS) // tvOS supports the above adaptable colors, but not these. 🤷‍♂️
    // Adaptable backgrounds
    public static let systemBackground = Color(UIColor.systemBackground)
    public static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    public static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)
    
    
    // Adaptable grouped backgrounds
    public static let systemGroupedBackground = Color(UIColor.systemGroupedBackground)
    public static let secondarySystemGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    public static let tertiarySystemGroupedBackground = Color(UIColor.tertiarySystemGroupedBackground)
    
    // Adaptable system fills
    public static let systemFill = Color(UIColor.systemFill)
    public static let secondarySystemFill = Color(UIColor.secondarySystemFill)
    public static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
    public static let quaternarySystemFill = Color(UIColor.quaternarySystemFill)
    #endif // !tvOS
    #endif // !watchOS
    
    // "Fixed" colors
    // Some of these clash with existing Color names: compare Color.blue (0.22, 0.57, 0.97) in the light theme to
    // UIColor.blue (0.01, 0.19, 0.97) to see two very different shades of blue. For that matter the adaptable
    // UIColor.systemBlue in the light theme (0.25, 0.56, 0.97) isn't *quite* the same blue as Color.blue either.
    
    //So all of the UIColor "fixed" colors are here with "fixed" prepended to the color name.
    public static let fixedBlack = Color(UIColor.black)
    public static let fixedDarkGray = Color(UIColor.darkGray)
    public static let fixedLightGray = Color(UIColor.lightGray)
    public static let fixedWhite = Color(UIColor.white)
    public static let fixedGray = Color(UIColor.gray)
    public static let fixedRed = Color(UIColor.red)
    public static let fixedGreen = Color(UIColor.green)
    public static let fixedBlue = Color(UIColor.blue)
    public static let fixedCyan = Color(UIColor.cyan)
    public static let fixedYellow = Color(UIColor.yellow)
    public static let fixedMagenta = Color(UIColor.magenta)
    public static let fixedOrange = Color(UIColor.orange)
    public static let fixedPurple = Color(UIColor.purple)
    public static let fixedBrown = Color(UIColor.brown)
    public static let fixedClear = Color(UIColor.clear)
    
    // There are a few more predefined UIColors that could go here. groupTableViewBackground is formally deprecated
    // in favor of systemGroupedBackground so I didn't include it. lightText and darkText are not formally deprecated,
    // but there is a comment recommending replacing them with label and related colors so I didn't add them to this
    // list.
}
