//
//  JoyMeterView.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI

public enum HeartLevel: CGFloat {
    
    case empty = 0
    case quarter = 25
    case half = 50
    case third = 75
    case full = 100
    
    public init(score: CGFloat) {
        guard score > 0 else {
            self = .empty
            return
        }
        
        guard score < HeartLevel.full.rawValue else {
            self = .full
            return
        }
        
        switch score {
        case 0..<HeartLevel.quarter.rawValue:
            self = .empty
        case HeartLevel.quarter.rawValue..<HeartLevel.half.rawValue:
            self = .quarter
        case HeartLevel.half.rawValue..<HeartLevel.third.rawValue:
            self = .half
        case HeartLevel.third.rawValue..<HeartLevel.full.rawValue:
            self = .third
        default:
            self = .half
        }
    }
    
    public var next: HeartLevel {
        switch self {
            case .empty:
                return .quarter
            case .quarter:
                return .half
            case .half:
                return .third
            case .third:
                return .full
            case .full:
                return .full
        }
    }

    public static func += (lhs: inout HeartLevel, rhs: HeartLevel) {

    }
    
    public static func + (lhs: HeartLevel, rhs: HeartLevel) {

    }
    
    public func actualOf(_ fullValue: CGFloat) -> CGFloat {
        guard self == .empty else {
            return self.rawValue
        }
        
        return (self.rawValue / 100.0) * fullValue
    }
}

public struct Hearts: CustomStringConvertible {
    
    public var description: String {
        return "♥️(\(level))⨯\(count)"
    }
    
    public var level: HeartLevel = .empty
    public var count: Int = .zero
    
    public init(score: CGFloat){
        self.count = Int(score / HeartLevel.full.rawValue)
        let rem = abs(score).truncatingRemainder(dividingBy: HeartLevel.full.rawValue)
        self.level = HeartLevel(score: rem)
    }
    
    public var score: CGFloat {
        return (HeartLevel.full.rawValue * CGFloat(count)) + level.rawValue
    }
    
    public var isEmpty: Bool {
        return score == .zero
    }
    
    public static func -= (lhs: inout Hearts, rhs: HeartLevel) -> Hearts {
        return Hearts(score: 0)
    }
}

struct JoyMeterView: View {
    
    @Binding var heartLevel: HeartLevel
    @State var heartCount: Int = 0
    @State var width: CGFloat = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
    @State var labelColor: Color = .gray
    
    init(_ heartLevel: Binding<HeartLevel>, heartCount: Int = 0, width: CGFloat? = nil, labelColor: Color? = nil){
        self._heartLevel = heartLevel
        self.heartCount = heartCount
        self.width = width ?? UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        self.labelColor = labelColor ?? .gray
    }
    
    init(_ heartLevel: Binding<HeartLevel>, heartCount: Int = 0, textStyle: UIFont.TextStyle = .largeTitle, labelColor: Color? = nil){
        self.init(heartLevel, heartCount: heartCount, width: UIFont.preferredFont(forTextStyle: textStyle).pointSize, labelColor: labelColor)
    }
    
    
    var body: some View {
        let getOffset = { () -> CGFloat in
            guard heartLevel.rawValue > 0 else {
                return width * -1
            }
            
            let levelVal = heartLevel.rawValue / 100.0 * width
            return (width - levelVal) * -1
        }
        
        return ZStack(){
            let offset: CGFloat = getOffset()
            
            Image(systemName: "heart")
                .resizable()
                .font(.system(size: width, weight: .light))
                .frame(width: width, height: width)
                .overlay(Rectangle().background(Color.primary).offset(x: offset, y: 0))
                .mask(Image(systemName: "heart.fill").font(.system(size: width)))
                .onChange(of: self.heartLevel) { newLevel in
                    guard self.heartLevel == .full else {
                        return
                    }
                    
                    self.heartCount += 1
                }
            
            if self.heartCount > 1 {
                let offset = width / 1.16
                Text("×\(self.heartCount)").foregroundColor(labelColor).font(.footnote)
                    .offset(x: offset, y: width / 4)
                    .frame(minWidth: width)
                    //.colorMultiply(.primary)
                    .animation(.spring())
            }
        }
        
    }
}


struct JoyMeterView_Previews: PreviewProvider {
    
    static var previews: some View {
        let level: Binding<HeartLevel> = .constant(.full)
        return JoyMeterView(level, heartCount: 5, textStyle: .largeTitle)
    }
}
