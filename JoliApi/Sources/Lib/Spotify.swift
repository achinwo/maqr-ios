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
    
    public struct UserProfile {
        
    }

}
