//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 11/12/2019.
//

import Foundation


public enum Spotify {
    
    public enum DeviceType: String, Codable {
        /// https://developer.spotify.com/documentation/web-api/reference/player/get-a-users-available-devices/#device-types
        
        case computer = "Computer"
        case tablet = "Tablet"
        case smartphone = "Smartphone"
        case speaker = "Speaker"
        case tv = "TV"
        case avr = "AVR"
        case stb = "STB"
        case audioDongle = "AudioDongle"
        case gameConsole = "GameConsole"
        case castVideo = "CastVideo"
        case castAudio = "CastAudio"
        case automobile = "Automobile"
        case unknown = "Unknown"
    }
    
    public struct Device: Codable, Identifiable, Hashable {
        public let id: String
        public let isActive: Bool
        public let isPrivateSession: Bool
        public let isRestricted: Bool
        public let name: String
        public let type: DeviceType
        public let volumePercent: Int
    }
    
    public struct UserProfile: Codable {
        
        public let birthdate: String
        public let country: String
        public let displayName: String
        public let email: String
        public let explicitContent: [String: Bool]
        public let externalUrls: [String: String]
//        public let followers: [String: Codable]
        public let href: String
        public let id: String
//        public let images: [[String: Codable]]
        public let product: String
        public let type: String
        public let uri: String
        
        public var isPremium: Bool {
            return product == "premium"
        }
        
    }
    
    public struct CurrentlyPlayingContent: Codable {
        public let timestamp: Int
        //public let context: Json
        public let progressMs: Int
        public let item: Track
//        public let album: Json
//        public let artists: [Json]
//        public let availableMarkets: [String]
//        public let discNumber: Int
//        public let duration_ms: 231272,`
//        public let explicit: false,
//        public let external_ids: Json
//        public let external_urls: Json
//        public let href: String
//        public let id: String
//        public let is_local: Bool
//        public let name: String
//        public let popularity: Int
//        public let preview_url: String
//        public let track_number: Int
//        public let type: String
//        public let uri: String
//        },
        public let currentlyPlayingType: String
        //public let actions: Json
        public let isPlaying: Bool
        
        public static func fromData(_ data: Data) throws -> CurrentlyPlayingContent? {
            do{
                return try Track.jsonDecoder().decode(CurrentlyPlayingContent.self, from: data)
            }catch{
                debugPrint("[CurrentlyPlayingContent] failed to decode: \(error)")
            }
            return nil
        }
    }

}
