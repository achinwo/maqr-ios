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
                Text("×\(self.heartCount)").foregroundColor(labelColor).font(.footnote)
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
    @Binding var searchText: String
    
    @State var isSearching = false
    @State var searchbarActive = false
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var activeDevice: Spotify.Device?
    @State var volume: CGFloat = 30
    
    public init(_ users: [User], isExpanded: Binding<Bool>? = nil, searchText: Binding<String>? = nil){
        self._users = State(initialValue: users)
        self._isExpanded = isExpanded ?? .constant(true)
        self._searchText = searchText ?? .constant("")
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
        
        let mainView = DisclosureGroup(isExpanded: self._isExpanded) {
            
            let width = Sizing.xxxLarge
            
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, alignment: .center) {
                    
                    Image(systemName: "plus.circle")
                        .renderingMode(.original)
                        .resizable()
                        .font(.system(size: width, weight: Font.Weight.thin, design: .default))
                        .frame(width: width, height: width)
                        .foregroundColor(.gray)
                    
                    ForEach(users, id: \.self) { user in
                        Image(uiImage: UIImage.makeLetterAvatar(withUsername: user.name)!)
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: width, height: width)
                            .clipShape(Circle())
                            .overlay(
                                Group() {
                                    if user.id == 3 {
                                        Text("invited")
                                            .fontWeight(.thin)
                                            .padding([.leading, .trailing], 4)
                                            .foregroundColor(.white)
                                            .background(Color.secondary)
                                            .font(.footnote)
                                            .clipShape(Capsule())
                                    } else {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: max(width / 4, 15), height: max(width / 4, 15))
                                    }
                                }
                                .offset(x: width / 3, y: width / 3)
                            ).onTapGesture {
                                self.heartLevel = self.heartLevel != .full ? self.heartLevel.next : .empty
                                
                                print("Tapping Image: \(Sizing.xxLarge)")
                            }
                    }
                }
                .padding()
            }
            .background(Colors.lightGray.opacity(0.3))
            .cornerRadius(Sizing.large)
            .animation(.spring())
        } label: {
            
            let devices: [Spotify.Device] = [
                Spotify.Device(name: "Devialet Phantom", type: .smartphone, isActive: true, id: "test_device3"),
                Spotify.Device(name: "Joli Player", type: .computer, isActive: true, id: "test_device1"),
                Spotify.Device(name: "Microwave", type: .speaker, isActive: true, id: "test_device4"),
                
                Spotify.Device(name: "Cyber Truck", type: .automobile, isActive: true, id: "test_device5"),
                Spotify.Device(name: "Living Room", type: .tv, isActive: true, id: "test_device6")
            ]
            
            HStack(){
                Image(systemName: "person.2").font(Font.title2.weight(.thin))
                Text(label)
                    .font(Font.caption.weight(.light))
                    .offset(x: -4, y: 0)
                Spacer()
                Button(){
                    self.appCoordinator.sheet.show(){
                        DevicesView(activeDevice: self.$activeDevice, volume: self.$volume, devices: devices)
                    }
                } label: {
                    Image(systemName: "hifispeaker")
                }
                .font(Font.title.weight(.ultraLight))
                
                Spacer()
                JoyMeterView($heartLevel, textStyle: .title3)
                    .foregroundColor(.red)
                    .font(Font.title.weight(.ultraLight))
                    .offset(x: !(self.isExpanded || users.isEmpty) ? Sizing.small / 2 * -1 : 0, y: 0)
                //.alignmentGuide(.custom) { dims in dims[.custom] }
                
                Spacer()
                Button(){
                    self.searchbarActive.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(Font.title2.weight(.ultraLight))
                }
                Spacer()
            }
            .padding()
            .padding(.leading, .zero)
            .frame(minWidth: screenWidth / 2)
            .background(Color.gray.opacity(0.001))
            .onTapGesture(){
                withAnimation(){
                    self.isExpanded.toggle()
                }
            }
        }
        
        
        return VStack(alignment: .center, spacing: .zero){
            
            if self.searchbarActive {
                SearchBar(text: self.$searchText, isEditing: self.$isSearching)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Colors.lightGray.opacity(self.isSearching ? 0 : 0.9), lineWidth: 1))
                    .padding(.top, Sizing.medium)
                    .background(Color.clear)
            }
            mainView
        }
        .onChange(of: self.isSearching) { value in
            if self.searchbarActive && !value {
                self.searchbarActive = false
            }
        }
        .accentColor(.primary)
        .padding(.trailing, Sizing.medium)
        .padding(.leading, Sizing.medium)
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
