//
//  main.swift
//  Exports
//
//  Created by Anthony Chinwo on 19/12/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import SharedMacOS

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

@main
public struct Exporter {
    
    let destUrl: URL
    
    public init() {
        self.destUrl = URL(fileURLWithPath: ProcessInfo.processInfo.environment["dest"] ?? "./")
    }
    
    public func export() -> Void {
        
        //FileManager.default.createDirectory(at: destUrl.e, withIntermediateDirectories: false, attributes: nil)
        let lines = Experiences.all().map() { cls -> String in
            let m = Mirror(reflecting: cls.init(nil))
            return m.children.map({ "DATA: \(String(describing: $0.label)) - \($0.value)" }).joined(separator: "\n")
        }.joined()
        
        let destination = destUrl.appendingPathComponent("experiences.txt")
        
        do {
            try lines.write(to: destination, atomically: true, encoding: .utf8)
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

