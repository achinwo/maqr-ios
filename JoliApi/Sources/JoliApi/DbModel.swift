//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 29/10/2019.
//

import Foundation
import Promises

public protocol IdIdentifiable: Codable, Hashable, Identifiable {
    var id: Int? { get set }
}

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
    
    //    static func isOptional<T>(_ type: T.Type) -> Bool {
    //        let mirror = Mirror(reflecting: type)
    //        return mirror.displayStyle == .optional
    //        let typeName = String(describing: type)
    //        return typeName.hasPrefix("Optional<")
    //    }
    
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
    
    var id: Int? {
        switch self {
        case .obj(let obj):
            return obj.id
        case .id(let id):
            return id
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

public protocol DbModel: IdIdentifiable, CustomStringConvertible {
    
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    var deletedAt: Date? { get }
    
    var createdBy: ObjectOrId<User>? { get }
    var updatedBy: ObjectOrId<User>? { get }
    var deletedBy: ObjectOrId<User>? { get }
    
    static func all(on: DispatchQueue?) -> Promise<[Self]>
}

private var BASE_URL: URL?

extension DbModel {
    
    func propertyNames() -> [String] {
        return Mirror(reflecting: self).children.compactMap { $0.label }
    }
    
    public var description: String {
        return String(data: try! Self.jsonEncoder(outputFormatting: .prettyPrinted).encode(self), encoding: .utf8)!
    }
    
    //    func propertyValues() {
    //        let mirror = Mirror(reflecting: self)
    //        for (propName, prop) in mirror.children {
    //
    //            debugPrint("name: \(propName), value: \(String(describing: type(of: prop)).starts(with: ""))")
    //        }
    //    }
    
    func save(on: DispatchQueue? = nil) -> Promise<Self?> {
        let suffix = self.id == nil ? "" : "/\(self.id!)"
        let urlComp = URLComponents(string: "/api/db/\(Self.className())\(suffix)")!
        return Self.post(urlPath: urlComp, dataType: Self?.self, payload: self, on: on)
    }
    
    static var baseUrl: URL {
        get { BASE_URL ?? URL(string: "http://192.168.1.173:8080")! }
        set {
            BASE_URL = newValue
        }
    }
    
    static func fetch<T: Codable>(method: HttpMethod = .get, urlPath: String, dataType: T.Type, on: DispatchQueue? = nil) -> Promise<T> {
        guard let url = URLComponents(string: urlPath) else {
            return Promise(NetworkError.invalidUrlPath(urlPath))
        }
        return Self.fetch(urlPath: url, dataType: dataType, on: on)
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
    
    static func post<T: Codable, E: Encodable>(urlPath: URLComponents, dataType: T.Type, payload: E, on: DispatchQueue? = nil) -> Promise<T> {
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        let on = on ?? DispatchQueue.global(qos: .default)
        
        return Promise<T>(on: on) { (resolve, reject) in
            
            let encoder = Self.jsonEncoder()
            let jsonData = try encoder.encode(payload)
            
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            
            //let data = try JSONSerialization.jsonObject(with: jsonData, options: [])
            let task = URLSession.shared.uploadTask(with: request, from: jsonData) { (data, resp, error) in
                //Data?, URLResponse?, Error?
                guard let data = data else {
                    return reject(error!)
                }
                
                do {
                    let decoder = Self.jsonDecoder()
                    let resp = try decoder.decode(Response<T>.self, from: data)
                    resolve(resp.data)
                } catch {
                    reject(error)
                }
                
            }
            
            task.resume()
        }
    }
    
    static func fetch<T: Codable>(urlPath: URLComponents, dataType: T.Type, on: DispatchQueue? = nil) -> Promise<T> {
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        let on = on ?? DispatchQueue.global(qos: .default)
        let decoder = Self.jsonDecoder()
        
        return Promise<T>(on: on) { (resolve, reject) in
            
            let task = URLSession.shared.dataTask(with: url) { (data, resp, error) in
                
                guard let data = data else {
                    return reject(error!)
                }
                
                do {
                    let resp = try decoder.decode(Response<T>.self, from: data)
                    resolve(resp.data)
                } catch {
                    reject(error)
                }
                
            }
            
            task.resume()
        }
    }
    
    public func fetchUpdatedBy() -> Promise<User?> {
        guard let updatedBy = self.updatedBy, let id = updatedBy.id else {
            return Promise<User?>(nil)
        }
        
        return User.findById(id: id)
    }
    
    public static func className() -> String {
        return String(describing: Self.self)
    }
    
    public static func all(on: DispatchQueue? = nil) -> Promise<[Self]> {
        return Self.fetch(urlPath: "/api/db/\(Self.className())", dataType: [Self].self, on: on)
    }
    
    public static func findById(id: Int, on: DispatchQueue? = nil) -> Promise<Self?> {
        return Self.fetch(urlPath: "/api/db/\(Self.className())/\(id)", dataType: Self?.self, on: on)
    }
    
}

public struct User: DbModel {
    
    @Tracked<Int> public var id: Int?
    
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
    @Tracked<Int> public var id: Int?
    
    @Tracked<Date> public var createdAt: Date?
    @Tracked<Date> public var updatedAt: Date?
    @Tracked<Date> public var deletedAt: Date?
    
    @Tracked<ObjectOrId<User>> public var createdBy: ObjectOrId<User>?
    @Tracked<ObjectOrId<User>> public var updatedBy: ObjectOrId<User>?
    @Tracked<ObjectOrId<User>> public var deletedBy: ObjectOrId<User>?
    
    public var name: String
    
    // get users
    // get tracks
    
    public func fetchTracks(on: DispatchQueue? = nil) -> Promise<[Track]> {
        guard let id = self.id else {
            return Promise([])
        }
        
        let urlPath = URLComponents(string: "/get_room_tracks")!
        return Self.post(urlPath: urlPath, dataType: [Track].self, payload: ["roomId": id], on: on)
    }
}

public struct Track: DbModel {
    @Tracked<Int> public var id: Int?
    
    @Tracked<Date> public var createdAt: Date?
    @Tracked<Date> public var updatedAt: Date?
    @Tracked<Date> public var deletedAt: Date?
    
    @Tracked<ObjectOrId<User>> public var createdBy: ObjectOrId<User>?
    @Tracked<ObjectOrId<User>> public var updatedBy: ObjectOrId<User>?
    @Tracked<ObjectOrId<User>> public var deletedBy: ObjectOrId<User>?
    
    public var title: String
    public var trackId: String
    public var thumbnailUrl: String
    public var artistName: String
    
    public func play(deviceId: String?, on: DispatchQueue? = nil) -> Promise<Track> {
        let deviceId = deviceId ?? "764cec96ce3d400916aac96e10ece041079ab1f5"
        let urlPath = URLComponents(string: "/api/spotify/play?trackId=spotify:track:\(self.trackId)&deviceId=\(deviceId)")!
        return Self.post(urlPath: urlPath, dataType: Self.self, payload: self, on: on)
    }
}
