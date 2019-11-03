//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 30/10/2019.
//

import Foundation
import Promises

public typealias Json = [String: Codable]

//

public protocol DataConvertible {
    func toData() throws -> Data?
    static func fromData(_ data: Data) throws -> Self?
}

extension DataConvertible {
    
    static var jsonEncoder: JSONEncoder {
        return Musicroom.jsonEncoder()
    }
    
    static var jsonDecoder: JSONDecoder {
        return Musicroom.jsonDecoder()
    }
}

extension DataConvertible where Self: Decodable {
    
    public static func fromData(_ data: Data) throws -> Self? {
        return try Self.jsonDecoder.decode(Self.self, from: data)
    }
    
}

extension DataConvertible where Self: Encodable {
    
    public func toData() throws -> Data? {
        return try Self.jsonEncoder.encode(self)
    }
    
}

extension DataConvertible where Self == Json {
    
    public func toData() throws -> Data? {
        return try JSONSerialization.data(withJSONObject: self, options: [])
    }
    
    public static func fromData(_ data: Data) throws -> Self? {
        return try JSONSerialization.jsonObject(with: data, options: []) as? Self
    }
    
}

extension Decodable where Self == Json {
    
}

extension Dictionary: DataConvertible where Key == String, Value: Codable {
    
}


extension Array: DataConvertible where Element: Codable {
    
}

extension Optional: DataConvertible where Wrapped: Codable {
    
}

//Optional<Json>

//extension DataConvertible where Self == Json {
//
//    public func toData() throws -> Data? {
//        return try JSONSerialization.data(withJSONObject: self, options: [])
//    }
//
//    public func fromData(_ data: Data) throws -> Self? {
//        return try JSONSerialization.jsonObject(with: data, options: []) as? Self
//    }
//
//}

public struct Response<T: Codable>: Codable {
    
//
//
//    public static func fromData(_ data: Data) throws -> Response<T>? {
//        return try JSONSerialization.jsonObject(with: data, options: []) as? Self
//    }
//
//    public func toData() throws -> Data? {
//        return try JSONSerialization.data(withJSONObject: self, options: [])
////      return try Musicroom.jsonEncoder().encode(self)
//    }
//
//    public static func fromData(_ data: Data) throws -> Response<T>? where T == DbModel {
//        return try Musicroom.jsonDecoder().decode(Self.self, from: data)
//    }
//
//    public func toData() throws -> Data? where T == DbModel {
//        return try Musicroom.jsonEncoder().encode(self)
//    }
    
    public let data: T
    
}

extension Response: DataConvertible {
    
}

//
//extension Response: DataConvertible {
//
//    public func toData() throws -> Data? {
//        let encoder = Musicroom.jsonEncoder()
//        return try encoder.encode(self)
//    }
//
//    public func fromData(_ data: Data) throws -> Self? {
//        let decoder = Musicroom.jsonDecoder()
//        return try decoder.decode(Self.self, from: data)
//    }
//
//}

public enum NetworkError: Error {
    case invalidUrl(URLComponents, URL)
    case invalidUrlPath(String)
    case badRequest(String)
    case badResponse(String)
    case deserialization(String)
}

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    
    func fetch<T: DataConvertible & Codable>(urlString: String, dataType: T.Type, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let baseUrl = baseUrl ?? Track.baseUrl.http
        return self.fetch(urlString: urlString, dataType: dataType, payload: nil, baseUrl: baseUrl, on: on)
    }
    
    func fetch<T: DataConvertible & Codable>(urlString: String, dataType: T.Type, payload: DataConvertible?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        guard let url = URLComponents(string: urlString) else {
            return Promise(NetworkError.invalidUrlPath(urlString))
        }
        
        let baseUrl = baseUrl ?? Track.baseUrl.http
        return self.fetch(urlPath: url, dataType: dataType, payload: payload, baseUrl: baseUrl, on: on)
    }
    
    func fetch<T: DataConvertible & Codable>(urlPath: URLComponents, dataType: T.Type, payload: DataConvertible?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let baseUrl = baseUrl ?? Track.baseUrl.http
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        return self.fetch(url: url, dataType: dataType, payload: payload, on: on)
    }
    
    func fetch<T: DataConvertible & Codable>(url: URL, dataType: T.Type, payload: DataConvertible?, on: DispatchQueue? = nil) -> Promise<T> {
        
        let queue = on ?? DispatchQueue.global(qos: .default)
        
        return Promise<T>(on: queue) { (resolve, reject) in
            
            let callback = { (data: Data?, resp: URLResponse?, error: Error?) -> Void in
                
                guard let data = data else {
                    return reject(error!)
                }
                
                do {
                    //let resp = try Musicroom.jsonDecoder().decode(Response<T>.self, from: data)
                    //let resp = try Response<T>.fromData(data) //.fromData(data)

                    guard let respObj = try Response<T>.fromData(data) else {
                        return reject(NetworkError.deserialization("Failed to deserialize data: \(data)"))
                    }
                    
                    resolve(respObj.data)
                } catch {
                    reject(error)
                }
            }
            
            let task: URLSessionTask
            switch self {
                case .post:
                    
                    guard let payloadData = try? payload?.toData() else {
                        return reject(NetworkError.badRequest("bad paylod for post request: \(String(describing: payload))"))
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = self.rawValue
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
                    
                    task = URLSession.shared.uploadTask(with: request, from: payloadData, completionHandler: callback)
                case .get:
                    task = URLSession.shared.dataTask(with: url, completionHandler: callback)
            }
            task.resume()
        }
    }
}
