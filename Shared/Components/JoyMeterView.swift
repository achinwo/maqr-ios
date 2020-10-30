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
    
    public func subtracting(_ level: HeartLevel) -> Hearts? {
        guard score >= level.rawValue else {
            return nil
        }
        
        return Hearts(score: score - level.rawValue)
    }
}

struct JoyMeterView: View {
    
    @Binding private var heartLevelBinding: Hearts?
    @State var width: CGFloat = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
    @State var labelColor: Color = .gray
    @State var backgroundColor: Color = .clear
    
    var hearts: Hearts {
        return self.heartLevelBinding ?? Hearts(score: HeartLevel.empty.rawValue)
    }
    
    init(_ hearts: Binding<Hearts?>, width: CGFloat? = nil, labelColor: Color? = nil, backgroundColor: Color?  = nil){
        self._heartLevelBinding = hearts
        self.width = width ?? UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        self.labelColor = labelColor ?? .gray
        self.backgroundColor = backgroundColor ?? self.backgroundColor
    }
    
    init(_ heartLevel: Binding<Hearts?>, textStyle: UIFont.TextStyle = .largeTitle, labelColor: Color? = nil, backgroundColor: Color? = nil){
        self.init(heartLevel, width: UIFont.preferredFont(forTextStyle: textStyle).pointSize, labelColor: labelColor, backgroundColor: backgroundColor)
    }
    
    var body: some View {
        let getOffset = { () -> CGFloat in
            guard self.hearts.level.rawValue > 0 else {
                return width * -1
            }

            let levelVal = self.hearts.level.rawValue / 100.0 * width
            return (width - levelVal) * -1
        }
        
        return ZStack(){
            let offset: CGFloat = getOffset()
            
            Image(systemName: "heart")
                .resizable()
                .font(.system(size: width, weight: .light))
                .frame(width: width, height: width)
                .overlay(Rectangle().background(Color.primary).offset(x: offset, y: 0))
                .background(self.backgroundColor)
                .mask(Image(systemName: "heart.fill").font(.system(size: width, weight: .light)))
            
            if self.hearts.count >= 1 {
                let offset = width / 1.32
                Text("×\(self.hearts.count)").foregroundColor(labelColor).font(.footnote)
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
        //let level: Binding<HeartLevel?> = .constant(.full)
        return JoyMeterView(.constant(Hearts(score: 5)), textStyle: .largeTitle)
    }
}
