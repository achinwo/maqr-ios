//
//  AppLocation.swift
//  Joli
//
//  Created by Anthony Chinwo on 24/07/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import Foundation

public struct Regex: ExpressibleByStringLiteral, Equatable {
    
    fileprivate let expression: NSRegularExpression
    private let regexString: String
    
    public init(stringLiteral: String) {
        self.regexString = stringLiteral
        do {
            self.expression = try NSRegularExpression(pattern: stringLiteral, options: [])
        } catch {
            print("Failed to parse \"\(stringLiteral)\" as a regular expression")
            self.expression = try! NSRegularExpression(pattern: ".*", options: [])
        }
    }
    
    public func match(_ input: String) -> Bool {
        let result = expression.rangeOfFirstMatch(in: input, options: [],
                                                  range: NSRange(input.startIndex..., in: input))
        return NSEqualRanges(result, NSMakeRange(NSNotFound, 0))
    }
    
    public func matchGroups(_ string: String) -> [String: String]? {
        guard let nameRegex = try? NSRegularExpression(pattern: "\\(\\?\\<(\\w+)\\>", options: []) else {
            return nil
        }
        
        let nameMatches = nameRegex.matches(in: regexString, options: [], range: NSMakeRange(0, regexString.count))
        let names = nameMatches.map { (textCheckingResult) -> String in
            return (regexString as NSString).substring(with: textCheckingResult.range(at: 1))
        }
        
        guard let regex = try? NSRegularExpression(pattern: regexString, options: []) else {
            return nil
        }
        
        let result = regex.firstMatch(in: string, options: [], range: NSMakeRange(0, string.count))
        var dict = [String: String]()
        
        for name in names {
            guard let nsRange = result?.range(withName: name), let range = Range(nsRange, in: string) else {
                continue
            }
            
            dict[name] = String(string[range])
        }
        return dict.isEmpty ? nil : dict
    }
    
    public static let phone: Regex = "^(\\+\\d{1,2}\\s)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}$"
}

public extension Regex {
    static func ~=(pattern: Regex, value: String) -> Bool {
        return pattern.match(value)
    }
}

public enum AppLocation: RawRepresentable, CustomStringConvertible, Equatable {
    
    case invited(String) // joli.live/r/abc
    case playroom(String)
    case rsvp(String)
    case reward(String)
    case product(String, String)
    
    case experienceMeal(String)
    case experienceBrand(String)
    case experienceCook(String)
    case experienceReorderNow(String)
    case experienceWeddingEvent(String, URL?)
    case experienceBio(String)
    case experienceEshop(String, String?)
    
    case unset
    case home
    case upgrade
    case error
    
    static var `default` = "/"
    
    public init?(rawValue: String) {
        let patterns = AppLocation.patterns
        
        if let matches = patterns.invited.matchGroups(rawValue), let inviteId = matches["inviteId"] {
            self = .invited(inviteId)
        } else if let matches = patterns.playroom.matchGroups(rawValue), let roomId = matches["roomId"] {
            self = .playroom(roomId)
        } else if let matches = patterns.experienceMeal.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceMeal(experienceId)
        } else if let matches = patterns.experienceBrand.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceBrand(experienceId)
        } else if let matches = patterns.experienceCook.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceCook(experienceId)
        } else if let matches = patterns.experienceReorderNow.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceReorderNow(experienceId)
        } else if let matches = patterns.experienceBio.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceBio(experienceId)
        } else if let matches = patterns.experienceWeddingEvent.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceWeddingEvent(experienceId, nil)
        } else if let matches = patterns.experienceEshop.matchGroups(rawValue), let experienceId = matches["experienceId"] {
            self = .experienceEshop(experienceId, nil)
        } else if let matches = patterns.rsvp.matchGroups(rawValue), let eventId = matches["eventId"] {
            self = .rsvp(eventId)
        } else if let matches = patterns.reward.matchGroups(rawValue), let rewardUid = matches["rewardId"] {
            self = .reward(rewardUid)
        } else if let matches = patterns.product.matchGroups(rawValue),
                  let storeId = matches["storeId"],
                  let productId = matches["productId"] {
            self = .product(storeId, productId)
        } else if rawValue == AppLocation.upgrade.rawValue {
            self = .upgrade
        } else if rawValue == AppLocation.default {
            self = .home
        } else if rawValue.isEmpty {
            self = .unset
        } else {
            return nil
        }
        
    }
    
    public var isExperience: Bool {
        return experienceId != nil
    }
    
    public var experienceId: String? {
        switch self {
            case .experienceMeal(let expId),
                    .experienceCook(let expId),
                    .experienceBrand(let expId),
                    .experienceReorderNow(let expId),
                    .experienceBio(let expId),
                    .experienceWeddingEvent(let expId, _),
                    .experienceEshop(let expId, _):
                return expId
            default:
                return nil
        }
    }
    
    public var rawValue: String {
        switch self {
            case .upgrade:
                return "/upgrade"
            case .invited(let inviteId):
                return "/i/\(inviteId)"
            case .playroom(let roomId):
                return "/r/\(roomId)"
            case .unset:
                return .empty
            case .rsvp(let eventId):
                return "/rsvp/b/\(eventId)"
            case .reward(let uid):
                return "/ir/\(uid)"
            case .product(let storeId, let pId):
                return "/s/\(storeId)/\(pId)"
            case .experienceMeal(let experienceId):
                return "/emeal/\(experienceId)"
            case .experienceBrand(let experienceId):
                return "/ebrand/\(experienceId)"
            case .experienceCook(let experienceId):
                return "/ecook/\(experienceId)"
            case .experienceBio(let experienceId):
                return "/ebio/\(experienceId)"
            case .experienceWeddingEvent(let experienceId, _):
                return "/ewed/\(experienceId)"
            case .experienceReorderNow(let experienceId):
                return "/p/\(experienceId)"
            case .experienceEshop(let experienceId, _):
                return "/eshop/\(experienceId)"
            default:
                return AppLocation.default
        }
    }
    
    static var patterns = (
        home: Regex("^/$"),
        invited: Regex("^/(playroom/invite|i)/(?<inviteId>.+)$"),
        playroom: Regex("^/r/(?<roomId>.+)$"),
        rsvp: Regex("^/rsvp/b/(?<eventId>.+)$"),
        reward: Regex("^/ir/(?<rewardId>.+)$"),
        product: Regex("^/s/(?<storeId>.+)/(?<productId>.+)$"),
        experienceMeal: Regex("^/emeal/(?<experienceId>.+)$"),
        experienceBrand: Regex("^/ebrand/(?<experienceId>.+)$"),
        experienceCook: Regex("^/ecook/(?<experienceId>.+)$"),
        experienceReorderNow: Regex("^/p/(?<experienceId>.+)$"),
        experienceWeddingEvent: Regex("^/ewed/(?<experienceId>.+)$"),
        experienceBio: Regex("^/ebio/(?<experienceId>.+)$"),
        experienceEshop: Regex("^/eshop/(?<experienceId>.+)$")
    )
    
    public var description: String {
        guard self != .unset else {
            return "\(Self.self)(<unset>)"
        }
        
        return "\(Self.self)(\(rawValue))"
    }
    
}

public extension AppLocation {
    
    init?(_ activity: NSUserActivity){
        guard let incomingUrl = activity.webpageURL else {
            logger.error("[AppLocation] unable to resolve activity: \(activity)")
            return nil
        }
        
        self.init(incomingUrl)
    }
    
    init?(_ url: URL){
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            logger.error("[AppLocation] unable to resolve: \(url)")
            return nil
        }
        
        if case let .experienceWeddingEvent(expId, _) = Self.init(rawValue: components.path), let url = components.url {
            self = .experienceWeddingEvent(expId, url)
        } else {
            self.init(rawValue: components.path)
        }
        
    }
    
}
