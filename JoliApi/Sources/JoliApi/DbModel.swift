//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 29/10/2019.
//

import Foundation
import Promises

extension Promise {
    
}
//
//extension String: Identifiable {
//    var id: ObjectOrId<String> { .obj(self) }
//}
//
//typealias StringOrInt = ObjectOrId<String>

public enum StringOrInt: Codable, Hashable {
    case string(String)
    case int(Int)
    
    public var  int: Int? {
        guard case let .int(int) = self else { return nil }
        return int
    }
    
    public var  string: String? {
        guard case let .string(val) = self else { return nil }
        return val
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let obj):
            try container.encode(obj)
        case .int(let id):
            try container.encode(id)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let id = try? container.decode(Int.self) {
            self = .int(id)
        } else if let obj = try? container.decode(String.self){
            self = .string(obj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data must be int or string")
        }
    }
}


public protocol IdIdentifiable: Codable, Hashable, Identifiable {
    var id: StringOrInt? { get set }
}



//protocol Trackable: Codable, Hashable {
//    associatedtype Value: Codable, Hashable
//}
//
//@propertyWrapper
//public struct TrackedValue: Trackable {
//    typealias Value =
//
//
//
//    private var currentValue: Value
//
//    public var wrappedValue: Value {
//        get { return currentValue }
//        set {
//            currentValue = newValue
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(currentValue)
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        //debugPrint("field: \(String(describing: T.self)), isOptional: \(Tracked.isOptional(T.self))")
//
//        self.init(wrappedValue: try? container.decode(T.self))
//    }
//}

@propertyWrapper
public struct Tracked<T: Codable & Hashable>: Codable, Hashable {
    
    public var projectedValue: T?
    private var currentValue: T?
    
    public var wrappedValue: T? {
        get { return currentValue }
        set {
            currentValue = newValue
        }
    }
    
    public init(wrappedValue: T?){
        currentValue = wrappedValue
        projectedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(currentValue)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        //debugPrint("field: \(String(describing: T.self)), isOptional: \(Tracked.isOptional(T.self))")
        
        self.init(wrappedValue: try? container.decode(T.self))
    }
}

public indirect enum ObjectOrId<T: IdIdentifiable>: Equatable, Codable, Hashable {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .obj(let obj):
            try container.encode(obj)
        case .id(let id):
            try container.encode(id)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let id = try? container.decode(Int.self) {
            self = .id(id)
        } else if let obj = try? container.decode(T.self){
            self = .obj(obj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data must be int or Object")
        }
    }
    
    var id: StringOrInt? {
        switch self {
        case .obj(let obj):
            return obj.id
        case .id(let id):
            return .int(id)
        }
    }
    
    var obj: T? {
        switch self {
        case .obj(let obj):
            return obj
        default:
            return nil
        }
    }
    
    case obj(T)
    case id(Int)
}

public protocol DbModel: IdIdentifiable, CustomStringConvertible, DataConvertible {
    
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    var deletedAt: Date? { get }
    
    var createdBy: ObjectOrId<User>? { get }
    var updatedBy: ObjectOrId<User>? { get }
    var deletedBy: ObjectOrId<User>? { get }
    
    static func all(baseUrl: URL?, on: DispatchQueue?) -> Promise<[Self]>
}

private var BASE_URL: URL?

extension DbModel {
    
    func propertyNames() -> [String] {
        return Mirror(reflecting: self).children.compactMap { $0.label }
    }
    
    public var description: String {
        let desc = String(data: try! Self.jsonEncoder(outputFormatting: .prettyPrinted).encode(self), encoding: .utf8)!
        return "\(Self.className())(\(desc))"
    }
    
    //    func propertyValues() {
    //        let mirror = Mirror(reflecting: self)
    //        for (propName, prop) in mirror.children {
    //
    //            debugPrint("name: \(propName), value: \(String(describing: type(of: prop)).starts(with: ""))")
    //        }
    //    }
    
    func save(baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<Self?> {
        let suffix = self.id == nil ? "" : "/\(self.id!)"
        let urlComp = "/api/db/\(Self.className())\(suffix)"
        //return Self.post(urlPath: urlComp, dataType: Self?.self, payload: self, on: on)
        return HttpMethod.post.fetch(urlString: urlComp,
                                     dataType: Self?.self,
                                     payload: self,
                                     baseUrl: baseUrl,
                                     on: on)
    }
    
    //192.168.1.132
    static var baseUrl: (ws: URL, http: URL) {
//        get { (http:BASE_URL ?? URL(string: "http://172.20.10.2:8080")!,
//        ws:URL(string: "ws://172.20.10.2:8080")!)}
        get { (http:BASE_URL ?? URL(string: "http://192.168.1.173:8080")!,
               ws:URL(string: "ws://192.168.1.173:8080")!)}
        set {
            BASE_URL = newValue.http
        }
    }
    
    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_UK_POSIX")
        
        decoder.dateDecodingStrategy = .formatted(formatter)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return decoder
    }
    
    static func jsonEncoder(outputFormatting: JSONEncoder.OutputFormatting = []) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = outputFormatting
        return encoder
    }
    
    public func fetchUpdatedBy() -> Promise<User?> {
        guard let updatedBy = self.updatedBy, let id = updatedBy.id?.int else {
            return Promise<User?>(nil)
        }
        
        return User.findById(id: id)
    }
    
    public static func className() -> String {
        return String(describing: Self.self)
    }
    
    public static func all(baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<[Self]> {
        return HttpMethod.get.fetch(urlString: "/api/db/\(Self.className())", dataType: [Self].self, baseUrl: baseUrl, on: on)
    }
    
    public static func findById(id: Int, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<Self?> {
        return HttpMethod.get.fetch(urlString: "/api/db/\(Self.className())/\(id)",
            dataType: Self?.self, baseUrl: baseUrl, on: on)
    }
    
}

public struct User: DbModel {
    
    @Tracked<StringOrInt> public var id: StringOrInt?
    
    @Tracked<Date> public var createdAt: Date?
    @Tracked<Date> public var updatedAt: Date?
    @Tracked<Date> public var deletedAt: Date?
    
    @Tracked<ObjectOrId<User>> public var createdBy: ObjectOrId<User>?
    @Tracked<ObjectOrId<User>> public var updatedBy: ObjectOrId<User>?
    @Tracked<ObjectOrId<User>> public var deletedBy: ObjectOrId<User>?
    
    public var name: String
    public var email: String
    
    // get musicrooms
}

public struct Musicroom: DbModel {
    @Tracked<StringOrInt> public var id: StringOrInt?
    
    @Tracked<Date> public var createdAt: Date? = nil
    @Tracked<Date> public var updatedAt: Date? = nil
    @Tracked<Date> public var deletedAt: Date? = nil
    
    @Tracked<ObjectOrId<User>> public var createdBy: ObjectOrId<User>? = nil
    @Tracked<ObjectOrId<User>> public var updatedBy: ObjectOrId<User>? = nil
    @Tracked<ObjectOrId<User>> public var deletedBy: ObjectOrId<User>? = nil
    
    public var name: String
    
    // get users
    // get tracks
    
    public func fetchTracks(baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<[Track]> {
        guard let id = self.id else {
            return Promise([])
        }
        let urlPath = "/get_room_tracks"
        return HttpMethod.post.fetch(urlString: urlPath,
                                     dataType: [Track].self,
                                     payload: ["roomId": id],
                                     baseUrl: baseUrl, on: on)
    }
    
}

public struct Track: DbModel {
    
    @Tracked<StringOrInt> public var id: StringOrInt?
    
    @Tracked<Date> public var createdAt: Date? = nil
    @Tracked<Date> public var updatedAt: Date? = nil
    @Tracked<Date> public var deletedAt: Date? = nil
    
    @Tracked<ObjectOrId<User>> public var createdBy: ObjectOrId<User>? = nil
    @Tracked<ObjectOrId<User>> public var updatedBy: ObjectOrId<User>? = nil
    @Tracked<ObjectOrId<User>> public var deletedBy: ObjectOrId<User>? = nil
    
    public var title: String? = nil
    public var trackId: String? = nil
    public var thumbnailUrl: String? = nil
    public var artistName: String? = nil
    
    public var durationMs: Int?
    public var explicit: Bool?
    public var href: String?
    
    public var isLocal: Bool?
    public var name: String?
    public var popularity: Int?
    public var previewUrl: String?
    public var trackNumber: Int?
    public var type: String?
    public var uri: String?
    
    @discardableResult
    public func play(deviceId: String?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<Track> {
        
        var urlPath = URLComponents(string: "/api/spotify/play")!
        urlPath.queryItems = [
            URLQueryItem(name: "trackId", value: self.uri ?? "spotify:track:\(self.trackId!)"),
        ]
        
        if let deviceId = deviceId {
            urlPath.queryItems!.append(URLQueryItem(name: "deviceId", value: deviceId))
        }
        
        return HttpMethod.post.fetch(urlPath: urlPath, dataType: Self.self, payload: self, baseUrl: baseUrl, on: on)
    }
}
