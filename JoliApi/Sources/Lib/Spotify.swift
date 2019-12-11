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

}
