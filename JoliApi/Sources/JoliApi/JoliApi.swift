import Foundation
import SwiftUI
import CoreLocation
import Promises

@available(OSX 10.12, *)
func doTest(completionHandler: (() -> Void)?) -> Void {
    //let urlSession = URLSession(configuration: .default)
    //let url = URL(string: "http://localhost:8080/api/db/musicrooms")!
    
    Musicroom.findById(id: 1, on: .global(qos: .background))
        .then() { (res) -> Promise<User?> in
            debugPrint("response: \(String(describing: res))")
            return res!.fetchUpdatedBy()
                
    }.then(){ user in
        debugPrint("User: \(String(describing: user))")
    }
    .always() {
            completionHandler?()
        }.catch() { error in
            debugPrint("error: \(error.localizedDescription)")
        }
    
//    let task  = urlSession.dataTask(with: url) { (data, resp, error) in
//
//        guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
//            print("error fetching data: \(error?.localizedDescription)")
//            return
//        }
//        let decoder = JSONDecoder()
//
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        formatter.calendar = Calendar(identifier: .iso8601)
//        formatter.timeZone = TimeZone(secondsFromGMT: 0)
//        formatter.locale = Locale(identifier: "en_UK_POSIX")
//
//        decoder.dateDecodingStrategy = .formatted(formatter)
//        do {
//            let rooms = try decoder.decode(Response<[Musicroom]>.self, from: data)
//            print("response: \(rooms.data[0].createdAt!.description)")
//
//            print("json: \(jsonString)")
//        } catch {
//            print("Couldn't parse \(jsonString) as \([Musicroom].self):\n\(error)")
//        }
//
//    }
//    task.resume()
//    let message = URLSessionWebSocketTask.Message.string("Hello Socket")
//    webSocketTask.send(message) { error in
//        if let error = error {
//            print("WebSocket sending error: \(error)")
//        }
//    }
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
}

public indirect enum UserOrId: Equatable, Codable, Hashable {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .user(let user):
            try container.encode(user)
        case .id(let id):
            try container.encode(id)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let id = try? container.decode(Int.self) {
            self = .id(id)
        } else if let user = try? container.decode(User.self){
            self = .user(user)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data must be int or User")
        }
    }
    
    var id: Int? {
        switch self {
        case .user(let user):
            return user.id
        case .id(let id):
            return id
        }
    }
    
    var user: User? {
        switch self {
        case .user(let user):
            return user
        default:
            return nil
        }
    }
    
    case user(User)
    case id(Int)
}

public protocol DbModel: Hashable, Codable, Identifiable {
    var id: Int? { get set }
    
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    var deletedAt: Date? { get }
    
    var createdBy: UserOrId? { get }
    var updatedBy: UserOrId? { get }
    var deletedBy: UserOrId? { get }
    
    static func all(on: DispatchQueue?) -> Promise<[Self]>
}

extension DbModel {
    
    static func baseUrl() -> URL {
        return URL(string: "http://192.168.1.213:8080")!//"http://localhost:8080/")!
    }
    
    static func fetch<T: Codable>(urlPath: String, dataType: T.Type, on: DispatchQueue? = nil) -> Promise<T> {
        guard let url = URLComponents(string: urlPath) else {
            return Promise(NetworkError.invalidUrlPath(urlPath))
        }
        return Self.fetch(urlPath: url, dataType: dataType, on: on)
    }
    
    static func fetch<T: Codable>(urlPath: URLComponents, dataType: T.Type, on: DispatchQueue? = nil) -> Promise<T> {
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
    
    public var id: Int?
    
    public var createdAt: Date?
    public var updatedAt: Date?
    public var deletedAt: Date?
    
    public var createdBy: UserOrId?
    public var updatedBy: UserOrId?
    public var deletedBy: UserOrId?
    
    public var name: String
    public var email: String
}

public struct Musicroom: DbModel {
    public var id: Int?
    
    public var createdAt: Date?
    public var updatedAt: Date?
    public var deletedAt: Date?
    
    public var createdBy: UserOrId?
    public var updatedBy: UserOrId?
    public var deletedBy: UserOrId?
    
    public var name: String
}

