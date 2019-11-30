//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 30/10/2019.
//

import Foundation
import Promises


public struct Response<T: Codable>: Codable {

    public let data: T
    
}

public enum NetworkError: Error {
    case invalidUrl(URLComponents, URL)
    case invalidUrlPath(String)
    case badRequest(String)
    case badResponse(String)
    case deserialization(String)
}

public typealias Json = [String: AnyObject]

extension Json {
    
    public func toData(writingOptions: JSONSerialization.WritingOptions = []) throws -> Data {
        return try JSONSerialization.data(withJSONObject: self, options: writingOptions)
    }
    
}

public enum HttpBody {
    case json(Json)
    case dbModel(DataConvertible)
    
    public func toData() throws -> Data {
        switch self {
        case .json(let json):
            return try json.toData()
        case .dbModel(let model):
            return try model.toData(outputFormatting: [])
        }
    }
}

enum HttpMethod: String {
    
    case get = "GET"
    case post = "POST"
    
    func fetch<T: Codable>(urlString: String, dataType: T.Type, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let baseUrl = baseUrl ?? Track.baseUrl.http
        return self.fetch(urlString: urlString, dataType: dataType, payload: nil, baseUrl: baseUrl, on: on)
    }
    
    func fetch<T: Codable>(urlString: String, dataType: T.Type, payload: HttpBody?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        guard let url = URLComponents(string: urlString) else {
            return Promise(NetworkError.invalidUrlPath(urlString))
        }
        
        let baseUrl = baseUrl ?? Track.baseUrl.http
        return self.fetch(urlPath: url, dataType: dataType, payload: payload, baseUrl: baseUrl, on: on)
    }
    
    func fetch<T: Codable>(urlPath: URLComponents, dataType: T.Type, payload: HttpBody?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let baseUrl = baseUrl ?? Track.baseUrl.http
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        return self.fetch(url: url, dataType: dataType, payload: payload, on: on)
    }
    
    func fetch<T: Codable>(url: URL, dataType: T.Type, payload: HttpBody?, on: DispatchQueue? = nil) -> Promise<T> {
        
        let queue = on ?? DispatchQueue.global(qos: .default)
        
        return Promise<T>(on: queue) { (resolve, reject) in
            
            let callback = { (data: Data?, resp: URLResponse?, error: Error?) -> Void in
                
                guard let data = data else {
                    return reject(error!)
                }
                
                do {
                    let respObj = try Musicroom.jsonDecoder().decode(Response<T>.self, from: data)
                    resolve(respObj.data)
                } catch {
                    reject(error)
                }
            }
            
            let task: URLSessionTask
            switch self {
                case .post:
                    
                    guard let payloadData = try? payload?.toData() else {
                        return reject(NetworkError.badRequest("bad payload for post request: \(String(describing: payload))"))
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = self.rawValue
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
                    
                    task = JoliApi.sharedUrlSession.uploadTask(with: request, from: payloadData, completionHandler: callback)
                case .get:
                    task = JoliApi.sharedUrlSession.dataTask(with: url, completionHandler: callback)
            }
            task.resume()
        }
    }
}
