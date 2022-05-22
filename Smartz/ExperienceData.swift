//
//  ExperienceData.swift
//  Joli
//
//  Created by Anthony Chinwo on 08/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import SwiftUI
import JoliApi
import MultipartFormData

#if !os(macOS)
import SharedUI
#endif

public protocol ExperienceDataItem: Codable {
    var aliasTitle: String? { get set }
    var caution: String? { get set }
    var defaultPrice: Int? { get set }
    var duration: Int? { get set }
    var imageName: String? { get set }
    var isOptional: Bool? { get set }
    var itemNo: Int? { get set }
    var itemGrouping: String? { get set }
    var itemSubgrouping: String? { get set }
    var experienceItemType: ExperienceItemType { get set }
    var spicy: Spicy? { get set }
    var subtitle: String? { get set }
    var title: String? { get set }
    var createdAt: Date { get }
    var uuid: String { get }
}

extension StikrExperienceDataItem: ExperienceDataItem {
    
}

extension ExperienceItemType {
    
    var label: String {
        switch self {
            case .mealPrepStep:
                return "Preparation Step"
            case .menuFoodNutrition:
                return "Nutritional Info"
            case .mealPrepIngredient:
                return "Ingredient"
            case .menuDrinkItem:
                return "Drink"
            case .person:
                return "Person"
            case .profileSkill:
                return "Skill"
            case .menuFoodItem:
                return "Food Item"
            case .product:
                return "Product"
        }
    }
    
    var isNumbered: Bool {
        switch self {
            case .mealPrepStep:
                return true
            default:
                return false
        }
    }
    
}

public class ExperienceData: ObservableObject, Persistable, Decodable, Equatable {
    
    lazy var jsonEncoder: JSONEncoder = {
        var encoder = Musicroom.jsonEncoder(outputFormatting: .prettyPrinted)
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
    
    public struct Item: ExperienceDataItem, Identifiable, Comparable, Equatable, Hashable {
        
        public static func < (lhs: ExperienceData.Item, rhs: ExperienceData.Item) -> Bool {
            lhs.createdAt < rhs.createdAt
        }
        
        public var experienceItemType: ExperienceItemType
        public var aliasTitle: String?
        public var caution: String?
        public var defaultPrice: Int?
        public var duration: Int?
        public var imageName: String?
        public var isOptional: Bool?
        public var itemGrouping: String?
        public var itemSubgrouping: String?
        public var itemNo: Int?
        public var spicy: Spicy?
        public var subtitle: String?
        public var title: String?
        public var identifier: Int?
        public var createdAt: Date = Date()
        public var uuid: String = UUID().uuidString
        
        public var id: String {
            return uuid
        }
        
    }
    
//    public var json: Json {
//        let items: [(String, AnyObject)] = []
//        return Dictionary<String, AnyObject>(uniqueKeysWithValues: items)
//    }
    
    static func imageAttributes() -> [ReferenceWritableKeyPath<ExperienceData, URL?>] {
        return keyPaths.compactMap() { kp in
            guard let meta = kp.meta, let keypath = kp as? ReferenceWritableKeyPath<ExperienceData, URL?>, meta.mediaType.starts(with: "image") else { return nil }
            return keypath
        }
    }
    
    func toMultipartFormData() throws -> MultipartFormData {
        let encoder = self.jsonEncoder
        let multipartFormData = try MultipartFormData() {
            
            try Subpart {
                ContentDisposition(name: "body")
                ContentType(mediaType: .applicationJson)
            } body: {
                try encoder.encode(self)
            }
                
            for keyPath in Self.imageAttributes() where keyPath.meta != nil {
                if let meta = keyPath.meta, let url = self[keyPath: meta.keypath] as? URL, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
                    try Subpart {
                        try ContentDisposition(uncheckedName: meta.name, uncheckedFilename: url.absoluteString)
                        ContentType(mediaType: .applicationOctetStream)
                    } body: {
                        try Data(contentsOf: url)
                    }
                }
            }

        }

        //let url = URL(string: "https://example.com/example")!
        //let request = URLRequest(url: url, multipartFormData: multipartFormData)
        
        return multipartFormData
    }
    
    @MainActor
    public func save(baseUrl: URL? = nil, urlSession: URLSession? = nil) async throws -> PersistedType {
        let appUrl = baseUrl ?? LocalhostApi.default.baseUrlHttp

        let urlComp = "/api/db/experiences"
        let multipart = try self.toMultipartFormData()
        let request = URLRequest(url: appUrl.appendingPathComponent(urlComp), multipartFormData: multipart)
        let session = urlSession ?? URLSession.shared
        
        let (data, _) = try await session.data(from: request)
        
        let decoder = Musicroom.jsonDecoder()
        
        let object = try decoder.decode(Response<PersistedType>.self, from: data)
        
        guard let saved = object.data, object.error == nil else {
            throw NetworkError.errorMessage(object.error)
        }
        
//        let object = try await HttpMethod.Fetch.post(url: urlComp, dataType: PersistedType.self, payload: .data(data), baseUrl: baseUrl, urlSession: urlSession)

        self.stored = saved
        self.uuid = saved.uuid
        return saved
    }
    
    func fromHeicToJpg(heicPath: String, jpgPath: String) async -> UIImage? {
        guard let heicImage = UIImage(named: heicPath), let jpgImageCompresed = await ImageCompressor.compress(image: heicImage, maxByte: 1_000_000) else { return nil }
        
        let jpgImageData = jpgImageCompresed.jpegData(compressionQuality: 1.0)
        FileManager.default.createFile(atPath: jpgPath, contents: jpgImageData, attributes: nil)
        
        return UIImage(named: jpgPath)
    }
    
    public var isNew: Bool {
        return uuid == nil
    }
    
    static let DEFAULT_BRAND_NAME = "Maqr"
    
    @Published var editStartedAt: Date? = nil
    
    @Published var stored: PersistedType? = nil
    
    // sourcery: title = "Logo Image", description = "Your brand logo image", mediaType = "image"
    // sourcery: default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/smartz_logo.png")"
    @Published var logoImageUrl: URL?
    
    // sourcery: title = "Banner Image", description = "Banner image of landing page", mediaType = "image"
    // sourcery: default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/austin-chan-ukzHlkoz1IE-unsplash.jpg")"
    @Published var bannerImageUrl: URL?
    
    // sourcery: title = "Banner Video", description = "Banner video of landing page", default = "URL(staticString: "https://www.youtu.be/ofFyRI6ROTI")"
    @Published var bannerVideoUrl: URL?
    
    // sourcery: title = "Background Image", description = "Default background image for your brand", mediaType = "image"
    // sourcery: default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/bg_light.jpg")"
    @Published var backgroundImageUrl: URL?
    
    // sourcery: title = "Product Image", description = "Your product image", mediaType = "image"
    // sourcery: default = "URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/devialet_phantom.png")"
    @Published var productImageUrl: URL?
    
    // sourcery: title = "Brand Name", description = "Name of your company or brand", default = ""Your Brand""
    @Published var brandName: String
    
    // sourcery: title = "Brand Email", description = "Contact email for enquiries and support", default = ""Your Brand""
    @Published var brandContactEmail: String?
    
    // sourcery: title = "Welcome Message", description = "Invite customers to your brand experience", default = ""Describe \nyour brand \nexperience""
    @Published var landingPageText: MultilineString
    
    // sourcery: title = "Product Name", description = "Brand product name", default = ""Your Product""
    @Published var productName: String?
    
    // sourcery: title = "Product Description", description = "Brand product description", default = ""Describe \nthis product""
    @Published var productDescription: MultilineString?
    
    // sourcery: title = "Instagram", description = "Instagram account username", default = ""smartstikr""
    @Published var socialInstagramUsername: String?
    
    // sourcery: title = "Instagram Tag", description = "Instagram tag", default = ""smartstikr""
    @Published var socialInstagramTag: String?
    
    // sourcery: title = "Facebook", description = "Facebook Page", default = ""smartstikr""
    @Published var socialFacebookPage: String?
    
    // sourcery: title = "TikTok", description = "TikTok username", default = ""smartstikr""
    @Published var socialTiktokUsername: String?
    
    // sourcery: title = "Release Date", description = "Product release date", default = "Date().advanced(by: 604800)"
    @Published var releaseDate: Date?
    
    // sourcery: title = "Release Platform Name", description = "Platform where this product will be made available", default = ""App Store""
    @Published var releasePlatformName: String?
    
    // sourcery: title = "Release Platform Logo", description = "Platform logo image", mediaType = "image"
    // sourcery: default = "URL(staticString: "https://www.freepnglogos.com/uploads/app-store-logo-png/file-app-store-ios-custom-size-18.png")"
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
    
    var experienceTypeInfo: Experiences
    
    var experienceTypeName: String { experienceTypeInfo.rawValue.className }
    
    // sourcery: title = "Items", description = "List brand experience items", default = "[]"
    @Published var items: [ExperienceData.Item] = []
    
    required init(_ typeInfo: Experiences, brandName: String? = nil, landingPageText: MultilineString? = nil) {
        self.experienceTypeInfo = typeInfo
        self.brandName = brandName ?? Self.DEFAULT_BRAND_NAME
        self.landingPageText = landingPageText ?? "Welcome to YOUR brand"
    }
    
    static func fromExperienceData(_ experienceData: PersistedType, baseUrl: URL) -> ExperienceData? {
        
        guard let typeInfo = Experiences(typeName: experienceData.experienceTypeName) else { return nil }
        
        let res = ExperienceData.init(typeInfo, brandName: experienceData.brandName, landingPageText: experienceData.landingPageText)
        res.uuid = experienceData.uuid
        
        res.logoImageUrl = URL.fromString(experienceData.logoImageUrl)
        res.bannerImageUrl = URL.fromString(experienceData.bannerImageUrl)
        res.bannerVideoUrl = URL.fromString(experienceData.bannerVideoUrl)
        res.backgroundImageUrl = URL.fromString(experienceData.backgroundImageUrl)
        
        res.productName = experienceData.productName
        res.productImageUrl = URL.fromString(experienceData.productImageUrl)
        res.productDescription = experienceData.productDescription
        
        res.brandContactEmail = experienceData.brandContactEmail
        
        res.brandName = experienceData.brandName
        res.landingPageText = experienceData.landingPageText ?? res.landingPageText
        res.socialInstagramUsername = experienceData.socialInstagramUsername
        
        res.socialInstagramTag = experienceData.socialInstagramTag
        res.socialFacebookPage = experienceData.socialFacebookPage
        res.socialTiktokUsername = experienceData.socialTiktokUsername
        
        res.releaseDate = experienceData.releaseDate
        res.releasePlatformName = experienceData.releasePlatformName
        res.releasePlatformLogoUrl = URL.fromString(experienceData.releasePlatformLogoUrl)
        res.releasePlatformInstaUsername = experienceData.releasePlatformInstaUsername
        
        res.brandColorPrimary = Color.init(hex: experienceData.brandColorPrimary ?? res.brandColorPrimary.hexString)
        res.brandColorSecondary = Color.init(hex: experienceData.brandColorSecondary ?? res.brandColorSecondary.hexString)
        res.brandColorAccent = Color.init(hex: experienceData.brandColorAccent ?? res.brandColorAccent.hexString)
        
        res.stored = experienceData
        
        guard let items = experienceData.items else {
            return res
        }
        
        res.items = items.map(){ stkItem -> Item in
            return ExperienceData.Item(experienceItemType: stkItem.experienceItemType,
                                       aliasTitle: stkItem.aliasTitle, caution: stkItem.caution,
                                       defaultPrice: stkItem.defaultPrice, duration: stkItem.duration,
                                       imageName: stkItem.imageName, isOptional: stkItem.isOptional,
                                       itemGrouping: stkItem.itemGrouping, itemSubgrouping: stkItem.itemSubgrouping,
                                       spicy: stkItem.spicy, subtitle: stkItem.subtitle,
                                       title: stkItem.title, identifier: stkItem.id, uuid: stkItem.uuid)
        }
        
        return res
    }

// sourcery:inline:auto:ExperienceData.Experiences
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(String?.self, forKey: .uuid)
        let experienceTypeName = try container.decode(String.self, forKey: .experienceTypeName)

        guard let experienceTypeInfo = Experiences(typeName: experienceTypeName) else {
            throw SerializationError.invalidData("Unable resolve type for '\(experienceTypeName)'")
        }

        self.experienceTypeInfo = experienceTypeInfo
        stored = try container.decode(PersistedType?.self, forKey: .stored)

        logoImageUrl = try container.decode(URL?.self, forKey: .logoImageUrl)
        bannerImageUrl = try container.decode(URL?.self, forKey: .bannerImageUrl)
        bannerVideoUrl = try container.decode(URL?.self, forKey: .bannerVideoUrl)
        backgroundImageUrl = try container.decode(URL?.self, forKey: .backgroundImageUrl)
        productImageUrl = try container.decode(URL?.self, forKey: .productImageUrl)
        brandName = try container.decode(String.self, forKey: .brandName)
        brandContactEmail = try container.decode(String?.self, forKey: .brandContactEmail)
        landingPageText = try container.decode(MultilineString.self, forKey: .landingPageText)
        productName = try container.decode(String?.self, forKey: .productName)
        productDescription = try container.decode(MultilineString?.self, forKey: .productDescription)
        socialInstagramUsername = try container.decode(String?.self, forKey: .socialInstagramUsername)
        socialInstagramTag = try container.decode(String?.self, forKey: .socialInstagramTag)
        socialFacebookPage = try container.decode(String?.self, forKey: .socialFacebookPage)
        socialTiktokUsername = try container.decode(String?.self, forKey: .socialTiktokUsername)
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

public enum SerializationError: Error {
    case invalidData(String)
}
