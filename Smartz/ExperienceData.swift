//
//  ExperienceData.swift
//  Joli
//
//  Created by Anthony Chinwo on 08/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import Promises
import SwiftUI
import JoliPlayground
import JoliApi

public typealias MultilineString = String

public enum SocialLink {
    
    case instagramUser(String)
    case instagramHashtag(String)
    case youtubeChannel(String)
    case youtubeUser(String)
    
    var url: URL {
        switch self {
        case .instagramUser(let username):
            return baseUrl.appendingPathComponent(username, isDirectory: true)
        case .instagramHashtag(let hashtag):
            return baseUrl.appendingPathComponent("/explore/tags/\(hashtag)", isDirectory: true)
        case .youtubeChannel(let channel):
            return baseUrl.appendingPathComponent("/channel/\(channel)")
        case .youtubeUser(let username):
            return baseUrl.appendingPathComponent("/user/\(username)")
        }
    }
    
    public static var urls: (instagram: URL, youtube: URL) {
        return (instagram: URL(staticString: "https://www.instagram.com"),
                youtube: URL(staticString: "https://www.youtube.com"))
    }
    
    var baseUrl: URL {
        switch self {
        case .instagramUser(_), .instagramHashtag(_):
            return Self.urls.instagram
        case .youtubeChannel(_), .youtubeUser(_):
            return Self.urls.youtube
        }
    }
}

public extension View {
    
    func backgroundColor(_ color: Color) -> some View {
        return self.background(color)
    }
    
}

public extension URL {
    
    init(staticString: StaticString){
        self.init(string: "\(staticString)")!
    }
    
    init(social: SocialLink){
        self = social.url
    }
    
}

extension Color: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.hexString)
    }
    
}

extension Color: Decodable {
    
    public init(from decoder: Decoder) throws {
        let hex = try decoder.singleValueContainer().decode(String.self)
        self.init(hex: hex)
    }
    
}

public protocol ExperienceDataItem: Codable {
    var aliasTitle: String? { get set }
    var caution: String? { get set }
    var defaultPrice: Int? { get set }
    var duration: Int? { get set }
    var imageName: String? { get set }
    var isOptional: Bool? { get set }
    var itemGrouping: String? { get set }
    var itemSubgrouping: String? { get set }
    var experienceItemType: ExperienceItemType { get set }
    var spicy: Spicy? { get set }
    var subtitle: String? { get set }
    var title: String? { get set }
    var identifier: Int? { get }
}

extension StikrExperienceDataItem: ExperienceDataItem {
    
    public var identifier: Int? {
        return id
    }
    
}

public class ExperienceData: ObservableObject, Persistable, Decodable, Equatable {
    
    lazy var jsonEncoder: JSONEncoder = {
        var encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    public static func == (lhs: ExperienceData, rhs: ExperienceData) -> Bool {
        let encoder = lhs.jsonEncoder
        
        guard let lhsData = try? encoder.encode(lhs),
              let rhsData = try? encoder.encode(rhs),
              let lhsString = String(data: lhsData, encoding: .utf8),
              let rhsString = String(data: rhsData, encoding: .utf8)
              else {
            return false
        }
        
        return lhsString == rhsString
    }
    
    public typealias PersistedType = StikrExperienceData
    
    public struct Item: ExperienceDataItem {
        public var experienceItemType: ExperienceItemType
        public var aliasTitle: String?
        public var caution: String?
        public var defaultPrice: Int?
        public var duration: Int?
        public var imageName: String?
        public var isOptional: Bool?
        public var itemGrouping: String?
        public var itemSubgrouping: String?
        public var spicy: Spicy?
        public var subtitle: String?
        public var title: String?
        public var identifier: Int?
    }
    
//    public var json: Json {
//        let items: [(String, AnyObject)] = []
//        return Dictionary<String, AnyObject>(uniqueKeysWithValues: items)
//    }
    
    static func imageAttributes() -> [ReferenceWritableKeyPath<ExperienceData, URL?>] {
        return [
            \.logoImageUrl,
            \.bannerImageUrl,
            \.backgroundImageUrl,
        ]
    }
    
    public func save(baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil) -> Promise<PersistedType> {
        
        return self.uploadImages(baseUrl: baseUrl, urlSession: urlSession, on: on)
            .then(on: .main) { urls -> Promise<PersistedType> in
                
                print("[uploadImages] URLs: \(urls)")
                
                for keyPath in Self.imageAttributes() {
                    guard let currentValue = self[keyPath: keyPath],
                          let newUrl = urls.first(where: { $0.original == currentValue })?.saved else { continue }
                    
                    self[keyPath: keyPath] = baseUrl?.appendingPathComponent("images").appendingPathComponent(newUrl.lastPathComponent)
                    //print("[uploadImages] updated url: \(currentValue) -> \(self[keyPath: keyPath])")
                }
                
                guard let data = try? self.jsonEncoder.encode(self) else {
                    return Promise.init(NetworkError.badRequest("Unable to serialize \(Self.self) instance"))
                }
                
                let urlComp = "/api/db/experiences"
                let promise = HttpMethod.Fetch.post(url: urlComp,
                                                    dataType: PersistedType.self,
                                                    payload: .data(data),
                                                    baseUrl: baseUrl,
                                                    urlSession: urlSession,
                                                    on: on)
                
                return promise.then(on: on ?? .main){ object -> PersistedType in
                    DispatchQueue.main.async() {
                        self.stored = object
                        self.uuid = object.uuid
                    }
                    return object
                }
            }
    }
    
    func uploadImages(baseUrl: URL? = nil, urlSession: URLSession? = nil, on: DispatchQueue? = nil) -> Promise<[(original: URL, saved: URL)]> {
        var promises: [Promise<(original: URL, saved: URL)>] = []
        
        let imageUrls: [URL] = Self.imageAttributes().compactMap() { self[keyPath: $0] }
        
        for imgUrl in Set(imageUrls) {
            
            guard imgUrl.isFileURL else {
                print("[uploadImages] skipping \(imgUrl)")
                continue
            }
            
            do {
                let data = try Data(contentsOf: imgUrl)
                guard let image = UIImage(data: data) else {
                    print("[uploadImages] unable to convert to UIImage: \(imgUrl)")
                    continue
                }
                
                let ext: ImageExtension = imgUrl.pathExtension.lowercased() == "png" ? .png : .jpeg
                let uploadPromise = JoliApi.upload(image, fileName: imgUrl.lastPathComponent, ext: ext, baseUrl: baseUrl, urlSession: urlSession, on: on)
                    .then(on: on ?? .promises) { (original: imgUrl, saved: $0) }
                
                promises.append(uploadPromise)
                
            } catch {
                print("[uploadImages] error uploading \(imgUrl): \(error)")
            }
            
            
        }
        
        return Promises.all(promises)
    }
    
    static let DEFAULT_BRAND_NAME = "SmartStikr"
    
    @Published var editStartedAt: Date? = nil
    
    @Published var stored: PersistedType? = nil
    
    // sourcery: title = "Logo Image", description = "Your brand logo image", default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/smartz_logo.png")"
    @Published var logoImageUrl: URL?
    
    // sourcery: title = "Banner Image", description = "Banner image of landing page"
    // sourcery: default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/austin-chan-ukzHlkoz1IE-unsplash.jpg")"
    @Published var bannerImageUrl: URL?
    
    // sourcery: title = "Banner Video", description = "Banner video of landing page", default = "URL(staticString: "https://www.youtu.be/ofFyRI6ROTI")"
    @Published var bannerVideoUrl: URL?
    
    // sourcery: title = "Background Image", description = "Default background image for your brand", default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/bg_light.jpg")"
    @Published var backgroundImageUrl: URL?
    
    // sourcery: title = "Brand Name", description = "Name of your company or brand", default = ""Your Brand""
    @Published var brandName: String
    
    // sourcery: title = "Welcome Message", description = "Invite customers to your brand experience", default = ""Describe \nyour brand \nexperience""
    @Published var landingPageText: MultilineString
    
    // sourcery: title = "Instagram", description = "Instagram account username", default = ""smartstikr""
    @Published var socialInstagramUsername: String?
    
    // sourcery: title = "Release Date", description = "Product release date", default = "Date().advanced(by: 604800)"
    @Published var releaseDate: Date?
    
    // sourcery: title = "Release Platform Name", description = "Platform where this product will be made available", default = ""App Store""
    @Published var releasePlatformName: String?
    
    // sourcery: title = "Release Platform Logo", description = "Platform logo image", default = "URL(staticString: "https://www.freepnglogos.com/uploads/app-store-logo-png/file-app-store-ios-custom-size-18.png")"
    @Published var releasePlatformLogoUrl: URL?
    
    // sourcery: title = "Release Platform Instagram", description = "Platform instagram name", default = ""smartstikr""
    @Published var releasePlatformInstaUsername: String?
    
    // sourcery: title = "Primary", description = "Primary brand color", default = ".blue"
    @Published var brandColorPrimary: Color = .blue
    
    // sourcery: title = "Secondary", description = "Secondary brand color", default = ".orange"
    @Published var brandColorSecondary: Color = .orange
    
    // sourcery: title = "Accent", description = "Accent brand color", default = ".primary"
    @Published var brandColorAccent: Color = .primary
    
    @Published var uuid: String? = nil
    
    // sourcery: title = "Items", description = "List brand experience items", default = "[]"
    @Published var items: [ExperienceData.Item] = []
    
    required init(brandName: String? = nil, landingPageText: MultilineString? = nil) {
        self.brandName = brandName ?? Self.DEFAULT_BRAND_NAME
        self.landingPageText = landingPageText ?? "Welcome to YOUR brand"
    }
    
    static func fromExperienceData(_ experienceData: PersistedType, baseUrl: URL) -> Self {
        let res = Self.init(brandName: experienceData.brandName, landingPageText: experienceData.landingPageText)
        return res
    }

// sourcery:inline:auto:ExperienceData.Experiences
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String?.self, forKey: .uuid)
        logoImageUrl = try container.decode(URL?.self, forKey: .logoImageUrl)
        bannerImageUrl = try container.decode(URL?.self, forKey: .bannerImageUrl)
        bannerVideoUrl = try container.decode(URL?.self, forKey: .bannerVideoUrl)
        backgroundImageUrl = try container.decode(URL?.self, forKey: .backgroundImageUrl)
        brandName = try container.decode(String.self, forKey: .brandName)
        landingPageText = try container.decode(MultilineString.self, forKey: .landingPageText)
        socialInstagramUsername = try container.decode(String?.self, forKey: .socialInstagramUsername)
        releaseDate = try container.decode(Date?.self, forKey: .releaseDate)
        releasePlatformName = try container.decode(String?.self, forKey: .releasePlatformName)
        releasePlatformLogoUrl = try container.decode(URL?.self, forKey: .releasePlatformLogoUrl)
        releasePlatformInstaUsername = try container.decode(String?.self, forKey: .releasePlatformInstaUsername)
        brandColorPrimary = try container.decode(Color.self, forKey: .brandColorPrimary)
        brandColorSecondary = try container.decode(Color.self, forKey: .brandColorSecondary)
        brandColorAccent = try container.decode(Color.self, forKey: .brandColorAccent)
        items = try container.decode([ExperienceData.Item].self, forKey: .items)
    }
// sourcery:end
}

extension ExperienceData {
    
    static func unwrap(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        
        if mirror.displayStyle != .optional {
            return value
        }
        
        if let child = mirror.children.first {
            return child.value
        } else {
            return nil
        }
    }
    
    public func isValid(for dataKeys: [ExperienceDataKeyPath]) -> Bool {
        var missingValues: [ExperienceDataKeyPath.Metadata] = []
        
        for dataKey in Set(dataKeys) {
            guard let meta = dataKey.meta else {
                continue
            }
            
            let value = Self.unwrap(self[keyPath: meta.keypath])
            
            
            guard value == nil else { continue }
            
            missingValues.append(meta)
        }
        
        //print("missingValues: \(missingValues.map(\.name))")
        
        return missingValues.isEmpty
    }
    
}
