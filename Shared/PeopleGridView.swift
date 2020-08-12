//
//  PeopleGridView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import LetterAvatarKit


struct BlurView: UIViewRepresentable {
    
    let style: UIBlurEffect.Style
    
    init(_ style: UIBlurEffect.Style = .systemMaterial) {
        self.style = style
    }
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: self.style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: self.style)
        uiView.isUserInteractionEnabled = false
    }
    
}

struct JoyMeterView: View {
    
    @Binding var heartLevel: HeartLevel
    @State var heartCount: Int = 0
    @State var width: CGFloat = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
    
    enum HeartLevel: CGFloat {
        case empty = 0
        case quarter = 26
        case half = 42
        case third = 74
        case full = 100
        
        var next: HeartLevel {
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
        
        func actualOf(_ fullValue: CGFloat) -> CGFloat {
            guard self == .empty else {
                return self.rawValue
            }
            
            return (self.rawValue / 100.0) * fullValue
        }
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
                    .font(.system(size: width))
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
                Text("×\(self.heartCount)").foregroundColor(.gray).font(.footnote)
                    .offset(x: offset, y: width / 4)
                    .frame(minWidth: width)
                    //.colorMultiply(.primary)
                    .animation(.spring())
            }
        }
        
    }
}

struct PeopleGridView: View {
    
    let rows = [
        GridItem(.fixed(100)),
    ]
    
    @Binding var isExpanded: Bool
    @State var users: [User]
    
    public init(_ users: [User], isExpanded: Binding<Bool>? = nil){
        self._users = State(initialValue: users)
        self._isExpanded = isExpanded ?? .constant(true)
    }
    
    var stickyHeaderView: some View {
        RoundedRectangle(cornerRadius: 25.0, style: .continuous)
            .fill(Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .overlay(
                Text("Section")
                    .foregroundColor(Color.white)
                    .font(.largeTitle)
            )
    }
    
    
    @State var heartLevel: JoyMeterView.HeartLevel = .full
    
    var body: some View {
        var label = ""
        
        if !(self.isExpanded || users.isEmpty) {
            label = "\(label)\(users.count)" //•
        }
        
        return DisclosureGroup(isExpanded: self._isExpanded) {
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, alignment: .center, pinnedViews: [.sectionHeaders]) {
                    
                    Image(systemName: "plus.circle")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                    
                    ForEach(users, id: \.self) { user in
                        Image(uiImage: UIImage.makeLetterAvatar(withUsername: user.name)!)
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .overlay(
                                Group() {
                                    if user.id == 3 {
                                        Text("invited")
                                            .padding([.leading, .trailing], 3)
                                            .foregroundColor(.white)
                                            .background(Color.gray)
                                            .font(.footnote)
                                            .clipShape(Capsule())
                                    } else {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                .offset(x: 18, y: 18)
                            ).onTapGesture {
                                self.heartLevel = self.heartLevel != .full ? self.heartLevel.next : .empty
                                
                                print("Tapping Image")
                            }
                    }
                }
            }
            .padding()
        } label: {
            HStack(){
                Image(systemName: "person.2.fill").font(.title2)
                Text(label)
                Spacer()
                JoyMeterView(heartLevel: $heartLevel, width: UIFont.preferredFont(forTextStyle: .title2).pointSize)
                    .foregroundColor(.red)
                    
                Spacer()
            }
            .padding()
            .frame(minWidth: screenWidth / 2)
            .background(Color.gray.opacity(0.001))
            .onTapGesture(){
                withAnimation(){
                    self.isExpanded.toggle()
                }
            }
        }
        .accentColor(.primary)
        .padding(.trailing, Sizing.medium)
        .animation(.spring())
    }
}

struct PeopleGridView_Previews: PreviewProvider {
    
    @State static var isExpanded = true
    
    static var previews: some View {
        let users = SEED_DATA.users
        return VStack() {
            PeopleGridView(users, isExpanded: Self.$isExpanded).padding()
            Spacer()
        }
    }
}
