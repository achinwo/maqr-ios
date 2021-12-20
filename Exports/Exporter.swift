//
//  main.swift
//  Exports
//
//  Created by Anthony Chinwo on 19/12/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import SharedMacOS
import JoliCore

//public protocol Experience {
//    var dataModel: ExperienceData? { get nonmutating set }
//    var dataModelDefault: ExperienceData.Defaults { get }
//
//    var editMode: EditingState { get nonmutating set }
//
//    static var title: String { get }
//
//    static var dataKeys: [PartialKeyPath<ExperienceData>] { get }
//    static var allDataKeys: [PartialKeyPath<ExperienceData>] { get }
//    static var supportedItemTypes: Set<ExperienceItemType> { get }
//
//    static var basePath: String { get }
//    static var className: String { get }
//}

extension Experience {
    
    static func toJson() -> Json {
        let json: Json = [
            "basePath": basePath as AnyObject,
            "title": title as AnyObject,
            "dataKeys": dataKeys.compactMap() { $0.meta?.name } as AnyObject,
            "allDataKeys": allDataKeys.compactMap() { $0.meta?.name } as AnyObject,
            "supportedItemTypes": supportedItemTypes.map() { $0.rawValue } as AnyObject,
            "className": className as AnyObject,
            "attributes": allDataKeys.compactMap() { dataKey -> [String: [String: String]]? in
                guard let meta = dataKey.meta else { return nil }
                return [
                    meta.name: [
                        "type": String(describing: meta.dataType),
                        "description": meta.description,
                        "grouping": meta.grouping,
                        "id": meta.id,
                        "title": meta.title
                    ]
                ]
            } as AnyObject,
        ]
        return json
    }
    
}

@main
public struct Exporter {
    
    let destUrl: URL
    
    public init() {
        self.destUrl = URL(fileURLWithPath: ProcessInfo.processInfo.environment["dest"] ?? "./")
    }
    
    public func export() -> Void {
        
        //FileManager.default.createDirectory(at: destUrl.e, withIntermediateDirectories: false, attributes: nil)
        
        let destination = destUrl.appendingPathComponent("experiences.json")
        
        do {
            var attributes: [String: [String: String]] = [:]
            var experiences: Json = [:]
            for cls in Experiences.allCases {
                //let m = Mirror(reflecting: cls.rawValue.init(nil))
                //return m.children.map({ "DATA: \(String(describing: $0.label)) - \($0.value)" }).joined(separator: "\n")
                var obj = cls.rawValue.toJson()
                let attrs = obj.removeValue(forKey: "attributes") as? [[String: [String: String]]]
                
                experiences[cls.rawValue.basePath] = obj as AnyObject
                
                guard let attr = attrs else { continue }
                
                for val in attr {
                    attributes.merge(val, uniquingKeysWith: { (_, new) in new })
                }
            }
            
            let json: Json = [
                "attributes": attributes as AnyObject,
                "experiences": experiences as AnyObject
            ]
            
            try json.toData(writingOptions: .prettyPrinted).write(to: destination, options: .atomic)
            print("[export] wrote to \(destination)")
        } catch {
            print("[export] error: \(error)")
        }
        
    }
    
    public static func main() -> Void {
        let exporter = Self.init()
        exporter.export()
    }
    
}

