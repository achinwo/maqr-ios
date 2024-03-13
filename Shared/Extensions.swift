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

#if os(macOS)
import AppKit
public typealias UIApplication = NSApplication

#else
import UIKit
import PartialSheet

#endif

import Combine
import UIImageColors


//public typealias Color = SwiftUI.Color
//public typealias View = SwiftUI.View

fileprivate var emptyData = Data()

public extension Data {
    
    static var empty: Data {
        return emptyData
    }
    
}

#if !os(macOS)
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
#endif

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
public typealias UIView = NSView
public typealias UIColor = NSColor
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


public extension Collection where Element: Hashable {
    
    var uniq: Set<Element> {
        return Set(self)
    }
    
}

public extension View {
    
    @ViewBuilder
    func backgroundColor(_ color: Color?) -> some View {
        if let color {
            self.background(color)
        } else {
            self
        }
    }
    
}

extension Collection where Element: RawRepresentable {
    
    public var rawValues: [Element.RawValue] {
        return self.map() { $0.rawValue }
    }
    
}

extension Collection where Element: Identifiable {
    
    public var ids: [Element.ID] {
        return self.map() { $0.id }
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
    func playMusicroom(_ room: Musicroom, device: Spotify.Device, on: DispatchQueue? = nil) async throws -> Musicroom {
        return try await HttpMethod.Fetch.post(url: "/api/musicrooms/\(room.id)/play?deviceId=\(device.id)", dataType: Musicroom.self, baseUrl: self.baseUrl.http, urlSession: self.urlSession)
    }
    
    //fetch<T: Codable>(urlString: String, dataType: T.Type, baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil)
    
    public func save<T>(_ model: T, on: DispatchQueue? = nil) async throws -> T.PersistedType where T: Persistable {
        return try await model.save(baseUrl: self.baseUrl.rawValue.http, urlSession: urlSession)
    }
    
    func fetchQueuedTracks(room: Musicroom, on: DispatchQueue? = nil) async throws -> [QueuedTrack] {
        return try await HttpMethod.Fetch.get(url: "/api/musicrooms/\(room.id)/queued", dataType: [QueuedTrack].self, baseUrl: self.baseUrl.http, urlSession: self.urlSession)
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
    
        /// cross-Swift compatible characters count
    var length: Int {
        return self.count
    }
    
        /// cross-Swift-compatible first character
    var firstChar: Character? {
        return self.first
    }
    
        /// cross-Swift-compatible last character
    var lastChar: Character? {
        return self.last
    }
    
        /// cross-Swift-compatible index
    func find(_ char: Character) -> Index? {
#if swift(>=5)
        return self.firstIndex(of: char)
#else
        return self.index(of: char)
#endif
    }
}

extension URL: Identifiable {
    
    public var id: String {
        self.absoluteString
    }
    
}


public extension UUID {
    
    var isBlank: Bool {
        uuidString.allSatisfy() { char in
            return char == "0" || char == "-"
        }
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


public extension URL {
    
    var cached: URL {
        
        guard let cachesDirUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first, self.isFileURL else {
            return self
        }
        
        return cachesDirUrl.appendingPathComponent(self.lastPathComponent)
    }
    
}

public struct ImageCompressor {
    
    public static func compress(image: UIImage, maxByte: Int) async -> UIImage? {
        
        return await withCheckedContinuation() { continuation in
            #if os(macOS)
            guard let data = image.jpegData(compressionQuality: 0.2) else {
                continuation.resume(returning: nil)
                return
            }
            
            continuation.resume(returning: NSImage(data: data))
            #else
            
            DispatchQueue.global(qos: .userInitiated).async {
                guard let currentImageSize = image.jpegData(compressionQuality: 1.0)?.count else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var iterationImage: UIImage? = image
                var iterationImageSize = currentImageSize
                var iterationCompression: CGFloat = 1.0
                
                while iterationImageSize > maxByte && iterationCompression > 0.01 {
                    let percantageDecrease = getPercantageToDecreaseTo(forDataCount: iterationImageSize)
                    
                    let canvasSize = CGSize(width: image.size.width * iterationCompression, height: image.size.height * iterationCompression)
                    
                    UIGraphicsBeginImageContextWithOptions(canvasSize, false, image.scale)
                    
                    defer { UIGraphicsEndImageContext() }
                    
                    image.draw(in: CGRect(origin: .zero, size: canvasSize))
                    iterationImage = UIGraphicsGetImageFromCurrentImageContext()
                    
                    guard let newImageSize = iterationImage?.jpegData(compressionQuality: 1.0)?.count else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    iterationImageSize = newImageSize
                    iterationCompression -= percantageDecrease
                }
                
                continuation.resume(returning: iterationImage)
            }
            #endif
        }
    }
    
    private static func getPercantageToDecreaseTo(forDataCount dataCount: Int) -> CGFloat {
        switch dataCount {
            case 0 ..< 3000000: return 0.05
            case 3000000 ..< 10000000: return 0.1
            default: return 0.2
        }
    }
}
