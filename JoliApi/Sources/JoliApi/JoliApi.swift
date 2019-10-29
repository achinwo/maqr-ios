import Foundation
import SwiftUI
import CoreLocation
import Promises

func doTest(completionHandler: (() -> Void)?) -> Void {
    //let urlSession = URLSession(configuration: .default)
    //let url = URL(string: "http://localhost:8080/api/db/musicrooms")!
    //debugPrint("names: \(Musicroom(name: "test").propertyValues())")
    
    Musicroom.findById(id: 1, on: .global(qos: .background))
        .then() { (res) -> Void in
            var r = res!
            debugPrint("response1: \(String(describing: r))")
            r.createdAt = nil
            
            debugPrint("response: \(String(describing: r.$createdAt)) - \(String(describing: r.createdAt))")
            //return res!
                
    }
//    .then(){ user in
//        debugPrint("User: \(String(describing: user))")
//    }
    .always() {
            completionHandler?()
        }.catch() { error in
            print("error: \(error)")
        }
    
}

struct JoliApi {
    var text = "Hello, World!"
}

struct Response<T: Codable>: Codable {
    let data: T
}

enum NetworkError: Error {
    case invalidUrl(URLComponents, URL)
    case invalidUrlPath(String)
    case badRequest(String)
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

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
}

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
////        let mirror = Mirror(reflecting: type)
////        return mirror.displayStyle == .optional
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

public protocol DbModel: IdIdentifiable {
    
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    var deletedAt: Date? { get }
    
    var createdBy: ObjectOrId<User>? { get }
    var updatedBy: ObjectOrId<User>? { get }
    var deletedBy: ObjectOrId<User>? { get }
    
    
    
    static func all(on: DispatchQueue?) -> Promise<[Self]>
}

extension DbModel {
    
    func propertyNames() -> [String] {
        return Mirror(reflecting: self).children.compactMap { $0.label }
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
        return Self.post(urlPath: "/api/db/\(Self.className())\(suffix)", dataType: Self?.self, payload: self, on: on)
    }
    
    static func baseUrl() -> URL {
        //return URL(string: "http://192.168.1.213:8080")!
        return URL(string: "http://localhost:8080/")!
    }
    
    static func fetch<T: Codable>(method: HttpMethod = .get, urlPath: String, dataType: T.Type, payload: Any? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        guard let url = URLComponents(string: urlPath) else {
            return Promise(NetworkError.invalidUrlPath(urlPath))
        }
        return Self.fetch(method: method, urlPath: url, dataType: dataType, on: on)
    }
    
    static func post<T: Codable>(urlPath: String, dataType: T.Type, payload: Any, on: DispatchQueue? = nil) -> Promise<T> {
        Self.fetch(method: .post, urlPath: urlPath, dataType: dataType, payload: payload, on: on)
    }
    
    static func fetch<T: Codable>(method: HttpMethod = .get,urlPath: URLComponents, dataType: T.Type, payload: Any? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let baseUrl = Self.baseUrl()
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        let on = on ?? DispatchQueue.global(qos: .default)
        let decoder = JSONDecoder()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_UK_POSIX")
        
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        return Promise<T>(on: on) { (resolve, reject) in
            //URLSession.shared.
            var  task: URLSessionDataTask
            
            switch method {
            case .get:
                task = URLSession.shared.dataTask(with: url) { (data, resp, error) in
                    
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
            case .post:
                
                guard let payload = payload else {
                    let error = NetworkError.badRequest("Payload can not be empty for \(method.rawValue) request")
                    return reject(error)
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = method.rawValue
                
                let data = try JSONSerialization.data(withJSONObject: payload, options: [])
                task = URLSession.shared.uploadTask(with: request, from: data) { (data, resp, error) in
                    
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
    
    public var id: Int?
    
    public var createdAt: Date?
    public var updatedAt: Date?
    public var deletedAt: Date?
    
    public var createdBy: ObjectOrId<User>?
    public var updatedBy: ObjectOrId<User>?
    public var deletedBy: ObjectOrId<User>?
    
    public var name: String
    public var email: String
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
}


