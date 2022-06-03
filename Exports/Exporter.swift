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
import EFQRCode
import AppKit
import Algorithms

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
                        "type": meta.dataTypeName,
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

extension NSImage {
        /// Generates a CIImage for this NSImage.
        /// - Returns: A CIImage optional.
    func ciImage() -> CIImage? {
        guard let data = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            return nil
        }
        
        let ci = CIImage(bitmapImageRep: bitmap)
        return ci
    }
    
        /// Generates an NSImage from a CIImage.
        /// - Parameter ciImage: The CIImage
        /// - Returns: An NSImage optional.
    static func fromCIImage(_ ciImage: CIImage) -> NSImage {
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

public struct AppClipCodeStyle: Identifiable {
    public let index: Int
    public let foregroundColor: NSColor
    public let backgroundColor: NSColor
    
    public var id: Int {
        return index
    }
}

public let appClipsTypes: [AppClipCodeStyle] = [
    //AppClipCodeStyle(index: 12, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "007AFF")),
    AppClipCodeStyle(index: 0, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "000000")),
    //AppClipCodeStyle(index: 2, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "777777")),
//    AppClipCodeStyle(index: 4, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "FF3B30")),
//    AppClipCodeStyle(index: 6, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "EE7733")),
//    AppClipCodeStyle(index: 8, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "33AA22")),
//    AppClipCodeStyle(index: 10, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "00A6A1")),
//    AppClipCodeStyle(index: 14, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "5856D6")),
//    AppClipCodeStyle(index: 16, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "CC73E1")),
]

func allCodeStyles() -> [AppClipCodeStyle] {
    var appClipsStyles: [AppClipCodeStyle] = []
    
    for item in appClipsTypes {
        let inv = AppClipCodeStyle(index: item.index + 1, foregroundColor: item.backgroundColor, backgroundColor: item.foregroundColor)
        appClipsStyles.append(contentsOf: [item, inv])
    }
    
    return appClipsStyles
}

func makeQrCode(_ path: URL, logoText: Int? = nil, backgroundColor: UIColor = .init(hex: "#f5f6fa"), foregroundColor: UIColor = .init(hex: "#29304B")) -> (UIImage, URL)? {
    
    var icon: CGImage? = nil
    
    if let logoText = logoText, logoText < 100 {
        
        var newInt: String = logoText < 10 ? "0\(logoText)" : logoText.description
        newInt = logoText == 1 ? "HT" : newInt
        
        let figOne = newInt[newInt.startIndex]
        let figTwo = newInt[newInt.index(before: newInt.endIndex)]
        
        
        let bgColorHex = "ffffff" //UIColor.white.hexString
        let colorHex = "000000" //UIColor.black.hexString
        let color = colorHex.suffix(from: colorHex.index(after: colorHex.startIndex))
        let bgColor = bgColorHex.suffix(from: bgColorHex.index(after: bgColorHex.startIndex))
        
        if let url = URL(string: "https://ui-avatars.com/api/?name=\(figOne)+\(figTwo)&bold=true&font-size=0.7&size=512&color=\(color)&background=\(bgColor)") {
            icon = NSImage(contentsOf: url)?.ciImage()?.cgImage
        }
    }
    
    guard let img = EFQRCode.generate(for: path.absoluteString,
                                        size: EFIntSize(width: 1080, height: 1080),
                                        backgroundColor: backgroundColor.cgColor,
                                        foregroundColor: foregroundColor.cgColor,
                                        icon: icon,
                                        pointStyle: .square,
                                        isTimingPointStyled: true
            ) else {
        return nil
    }
    
    return (UIImage(cgImage: img, size: .init(width: 1080, height: 1080)), path)
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
            
            try json.toData(writingOptions: [.prettyPrinted, .sortedKeys]).write(to: destination, options: .atomic)
            print("[export] wrote to \(destination)")
        } catch {
            print("[export] error: \(error)")
        }
        
    }
    
    public static func main() -> Void {
//        let exporter = Self.init()
//        exporter.export()
        print("starting...")
        //let logoUrl = URL(fileURLWithPath: "/Users/anthony/Downloads/chinyerum_wedding_foods/image8.png")
        
        let fourthyCodes = [allCodeStyles()[1]].cycled(times: 50)
        
        for (offset, element) in fourthyCodes.enumerated() {
            
            guard
                let (image, _) = makeQrCode(URL(string: "https://maqr.co/ewed/lizmanfred?table=\((offset + 1).description)")!, logoText: offset + 1,
                                            backgroundColor: element.backgroundColor, foregroundColor: element.foregroundColor),
                let data = image.jpegData() else {
                print("unable to genrate QR code")
                return
            } //Users/anthony/Downloads/chinyerum_wedding_foods/tables
            
            try? data.write(to: URL(fileURLWithPath: "/Users/anthony/Downloads/chinyerum_wedding_foods/tables/qr_code_\(offset).jpg"), options: .atomic)
            print("Write file complete - \(offset)")
        }
    }
    
}

