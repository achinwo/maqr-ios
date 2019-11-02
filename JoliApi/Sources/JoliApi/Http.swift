//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 30/10/2019.
//

import Foundation
import Promises

public typealias Json = [String: AnyObject]

protocol FlatJson {
    
}

struct Response<T: Codable>: Codable {
    let data: T
}

enum NetworkError: Error {
    case invalidUrl(URLComponents, URL)
    case invalidUrlPath(String)
    case badRequest(String)
    case badResponse(String)
}

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    
    func fetch<T: Codable>(urlPath: String, dataType: T.Type, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let payload_: String? = nil
        let baseUrl = baseUrl ?? Track.baseUrl.http
        return self.fetch(urlPath: urlPath, dataType: dataType, payload: payload_, baseUrl: baseUrl, on: on)
    }
    
    func fetch<T: Codable, P: Encodable>(urlPath: String, dataType: T.Type, payload:P?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        guard let url = URLComponents(string: urlPath) else {
            return Promise(NetworkError.invalidUrlPath(urlPath))
        }
        
        let baseUrl = baseUrl ?? Track.baseUrl.http
        return self.fetch(urlPath: url, dataType: dataType, payload: payload, baseUrl: baseUrl, on: on)
    }
    
    func fetch<T: Codable, P: Encodable>(urlPath: URLComponents, dataType: T.Type, payload:P?, baseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<T> {
        let baseUrl = baseUrl ?? Track.baseUrl.http
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        return self.fetch(url: url, dataType: dataType, payload: payload, on: on)
    }
    
    func fetch<T: Codable, P: Encodable>(url: URL, dataType: T.Type, payload:P?, on: DispatchQueue? = nil) -> Promise<T> {
        
        let on = on ?? DispatchQueue.global(qos: .default)
        let decoder = Musicroom.jsonDecoder()
        
        return Promise<T>(on: on) { (resolve, reject) in
            
            let callback = { (data: Data?, resp: URLResponse?, error: Error?) -> Void in
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
            
            let task: URLSessionTask
            switch self {
                case .post:
                    let encoder = Musicroom.jsonEncoder()
                    guard let payloadEncodable = payload, let jsonData = try? encoder.encode(payloadEncodable) else {
                        return reject(NetworkError.badRequest("bad paylod for post request: \(String(describing: payload))"))
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = HttpMethod.post.rawValue
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
                    
                    task = URLSession.shared.uploadTask(with: request, from: jsonData, completionHandler: callback)
                case .get:
                    task = URLSession.shared.dataTask(with: url, completionHandler: callback)
            }
            task.resume()
            
        }
    }
}
