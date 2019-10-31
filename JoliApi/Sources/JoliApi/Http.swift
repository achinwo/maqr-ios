//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 30/10/2019.
//

import Foundation

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
}
