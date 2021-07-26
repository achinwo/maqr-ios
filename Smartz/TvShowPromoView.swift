//
//  TvShowPromoView.swift
//  Joli
//
//  Created by Anthony Chinwo on 06/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import Combine
import JoliCore

struct TvShowCastInfo: Codable, Identifiable {
    let name: String
    let characterName: String
    let imageUrl: URL
    let bio: String
    
    var id: String {
        return name
    }
    
    public static func load(from bundle: Bundle? = nil) throws -> [Self]? {
        //https://storage.googleapis.com/joli-app-bucket/images/joey_sherway_data.json
        
        let decoder = Musicroom.jsonDecoder()
        let bundle = bundle ?? Bundle.main
        
        guard let filePath = bundle.path(forResource: "show_cast_data", ofType: "json") else {
            print("Unable to load file!")
            return nil
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let obj: [Self] = try decoder.decode([Self].self, from: data)
        
        return obj
    }
}

struct TvShowPromoView: Experience, JoliView {
    
    static var title: String {
        "Trailer"
    }
    
    static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
            \ExperienceData.bannerVideoUrl,
            \ExperienceData.bannerImageUrl,
            \ExperienceData.backgroundImageUrl,
        ]
    }
    
    
    @Binding var editMode: EditMode
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let dataModel: ExperienceData
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    @State var arrivedAt: Date? = Date()
    @State var trailerUrl = URL(string: "https://storage.googleapis.com/joli-app-bucket/images/crazyworld_netflix_trailer.mp4")!//"https://drive.google.com/uc?export=download&id=1thleK6efGtQ_hzTinD6jgHryLnkWBnHC")!
    @State var menu: [TvShowCastInfo] = []
    @AppStorage("isvideomuted-crazyworld") var isVideoMuted = false
    
    public init(_ data: ExperienceData? = nil, editMode: Binding<EditMode> = .constant(.inactive)){
        self.dataModel = data ?? ExperienceData()
        self._editMode = editMode
        
        self._videoLocalUrl = State(initialValue: FileManager.default.fileExists(atPath: cacheFileUrl.path) ? cacheFileUrl : nil)
    }
    
    public init(_ data: ExperienceData? = nil) {
        self.init(data, editMode: .constant(.inactive))
    }
    
    var cacheFileUrl: URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectoryUrl = urls[0]
        let fileUrl = cachesDirectoryUrl.appendingPathComponent("crazyworld_netflix_trailer_saved.mp4")
        return fileUrl
    }
    
    func fetchVideo(_ force: Bool = false){
        print("[fetchVideo] loading video...")
            
        if force && FileManager.default.fileExists(atPath: cacheFileUrl.path) {
            try? FileManager.default.removeItem(atPath: cacheFileUrl.path)
        }
        
        guard !FileManager.default.fileExists(atPath: cacheFileUrl.path) else {
            self.videoLocalUrl = cacheFileUrl
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let data = try? Data(contentsOf: trailerUrl) else {
                print("Video fetch failed!")
                return
            }
            
            guard Int(data.count) / (1000 * 1000) > 0 else {
                print("Video file size is too small")
                return
            }
            
            FileManager.default.createFile(atPath: cacheFileUrl.path, contents: data)
            
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB] // optional: restricts the units to MB only
            bcf.countStyle = .file
            let string = bcf.string(fromByteCount: Int64(data.count))
            //https://storage.googleapis.com/joli-app-bucket/images/crazyworld_netflix_trailer.mp4
            print("Wrote video to cache: \(cacheFileUrl.path) (\(string))")
        }
    }
    
    @State var videoLocalUrl: URL? = nil
    
    var infoView: some View {
        ScrollViewReader() { proxy in
            ScrollView(showsIndicators: false){
                VStack(spacing: .zero){
                    PlayerView(url: videoLocalUrl ?? trailerUrl, isMuted: self.isVideoMuted)
                        .background(
                            VStack(){
                                Image("poster_crazy_world_lowres")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .overlay(
                                        VStack(){
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .shadow(radius: 10)
                                            Text("Loading trailer...")
                                                .font(.caption2.weight(.light))
                                                .padding(.top)
                                                .shadow(radius: 10)
                                        }
                                        .foregroundColor(.primary)
                                        .padding()
                                        .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                    )
                                Spacer()
                            }
                            .frame(maxHeight: UIScreen.main.bounds.width / 2)
                            .clipped()
                        )
                        .overlay(
                            GeometryReader(){ proxy in
                                VStack(){
                                    Spacer()
                                    HStack(){
                                        Spacer()
                                        Button(){
                                            isVideoMuted.toggle()
                                        } label: {
                                            Image(systemName: isVideoMuted ? "speaker.slash.circle.fill" : "speaker.wave.2.circle.fill")
                                                .resizable()
                                                .frame(width: 32, height: 32)
                                                .foregroundColor(.primary.opacity(0.5))
                                                .padding(8)
                                        }
                                        .background(
                                            BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding()
                                    }
                                }
                            }
                        )
                        //.fixedSize()
                    
                    Image("logo_crazyworld")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: screenWidth * 0.7)
                        .padding()
                        .padding(.vertical)
                        //.offset(x: 0, y: -200)
                        .id("brand")
                    //
                    Link(destination: URL(string: "https://www.instagram.com/naijaonnetflix/")!) {
                        HStack(alignment: .center, spacing: .zero){
                            (Text("Coming ").font(.subheadline)
                                + Text("July 25th").font(.subheadline.weight(.semibold)))
                                .foregroundColor(.primary)
                                .padding(.trailing)
                                .lineLimit(1)
                                .fixedSize()

                            RoundedRectangle(cornerRadius: 4).frame(width: 1.5, height: screenWidth / 10).foregroundColor(.primary)

                            Image("logo_netflix").resizable().aspectRatio(contentMode: .fit).frame(height: screenWidth / 8)//.background(Color.pink)
                        }
                    }
                    .frame(maxHeight: screenWidth / 8)
                    .padding(.bottom)
                    
                    VStack(){
                        (Text("“It’s a crazy world” ").font(.subheadline.weight(.semibold))
                            + Text("is a modern-day 30-minute sitcom created by Amanda Ebeye and majorly directed by KC Muel and Amanda Ebeye. It tells the story of a very wealthy man with three women and three kids. It’s a hilarious sitcom that addresses the competition women go through in general trying to outdo themselves and constantly vying for the man’s attention. In this case, these women would use any means available to them, with social media being their number one go-to tool. \n\nThe other two women are constantly trying to win the favorite spot which the first wife already occupies as he constantly reminds them that besides pregnancy and the kids from the other women; he’s a man with a one-man-one-woman personality. So they try every way they can to win that spot, employing social media tools, the last wife and the kids’ area always on Instagram, Snapchat, Facebook, living a lie, making their worlds look perfect when it is not.")
                            .font(.subheadline.weight(.light))
                        )
                        .padding()
                        .multilineTextAlignment(.center)
                        
                        Divider().padding(.vertical)
                        
                        TvShowCastButtonView(menu: $menu)
                            .frame(height: 60)
                            .padding(.bottom)
                    }
                    .frame(width: screenWidth - 100)
                    .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                    .fixedSize(horizontal: false, vertical: true)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.bottom)
                    .padding(.bottom)
                    .id("body")
                    
                    VStack(){
                        Link(destination: URL(string: "https://www.instagram.com/naijaonnetflix/")!) {
                            VStack(){
                                Image("logo_netflix").resizable().aspectRatio(contentMode: .fit).frame(width: screenWidth / 3)
                                Text("Coming July 25th").font(.callout.weight(.light)).foregroundColor(.secondaryLabel)
                                Text("@naijaonnetflix").font(.body.weight(.semibold)).foregroundColor(.primary)
                            }
                        }
                        .padding(.bottom)
                        
                        Link(destination: URL(string: "https://www.instagram.com/itsacrazyworld_tvseries/")!) {
                            VStack(){
                                Image("instagram_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                                Text("Follow us").font(.callout.weight(.light)).foregroundColor(.secondaryLabel)
                                Text("@itsacrazyworld_tvseries").font(.body.weight(.semibold)).foregroundColor(.primary)
                            }
                        }
                        .padding(.bottom)
                        //https://www.instagram.com/explore/tags/madewithsise/
                        
                        
                    }
                    .padding(.bottom)
                    
                    Spacer()
//                    Link("Restaurant Menu Icon by Icons8", destination: URL(string: "https://icons8.com/icon/tmr075NtT7e6/restaurant-menu")!)
//                        .font(.caption)
                }
                .frame(minHeight: screenHeight * 1.6)
                .padding(.bottom, max(100, safeAreaInsets.bottom))
                //.padding(.top, safeAreaInsets.top)
            }
            .background(Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
            )
            .onAppear(){
                self.menu = (try? TvShowCastInfo.load()) ?? []
                
                guard self.videoLocalUrl == nil else { return }
                
                fetchVideo()
            }
        }
    }
    
    var contentView: some View {
        NavigationView(){
            ZStack(){
                infoView
                    .frame(width: screenWidth, height: screenHeight)
                    .onAppear(){
                    }
            }
            .edgesIgnoringSafeArea(.vertical)
            .navigationBarHidden(true)
        }
        .edgesIgnoringSafeArea(.vertical)
        .showEditPencil(.constant(.readonly))
    }
    
}

struct TvShowCastButtonView: JoliView {
    
    @Binding var menu: [TvShowCastInfo]
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    var contentView: some View {
        Button(){
            
            let preview: AppPreview = .view2(){
                TvShowCastView(menu: menu)
                    .frame(width: screenWidth)
                    .frame(minHeight: screenHeight - safeAreaInsets.top)
                    .eraseToAnyView()
            }
            
            appCoordinator.globalModalSubject.send(preview)
        } label: {
            Label(){
                Text(" Meet The Cast")
            } icon: {
                Image(systemName: "rectangle.stack.person.crop")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.orange)
                    .frame(height: 24)
                
            }
            .font(.title3.weight(.light))
            .accentColor(Color.yellow)
        }
    }
    
}


struct TvShowCastView: View {
    
    @State var menu: [TvShowCastInfo]
    @State private var selectedTab: Int = 0
    
    var tabNames: [String] {
        return menu.map() { $0.name }
    }
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    func castView(_ info: TvShowCastInfo) -> some View {
        ScrollView(.vertical){
            VStack(alignment: .leading){
                Spacer()
                Spacer()
                VStack(){
                    
                    let header = VStack(){
                        Text(info.name).font(.largeTitle.weight(.ultraLight))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text("as ").font(.callout).foregroundColor(.secondaryLabel) + Text(info.characterName).font(.title3)
                        Rectangle().frame(height: 1).foregroundColor(.yellow.opacity(0.7)).padding(.horizontal)
                    }
                    
                    VStack(spacing: .zero){
                        header
                        Text(info.bio)
                            .font(.subheadline.weight(.light))
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                }
                .frame(width: screenWidth - 100)
                .background(BlurView(colorScheme == .dark ? .systemThinMaterialDark : .systemThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                Spacer()
            }
            .frame(minHeight: screenHeight)
            .frame(width: screenWidth)
        }
        .background(
            ZStack(){
                NetworkImage(url: info.imageUrl){
                    ProgressView()
                }
                .clipped()
            }
        )
    }
    
    var body: some View {
        //NavigationView(){
        ZStack(){
            
            TabView(selection: $selectedTab) {
                ForEach(Array(menu.enumerated()), id: \.offset) { item in
                    self.castView(item.element)
                        .frame(maxWidth: screenWidth)
                        .clipped()
                        .tag(item.offset + 1)
                }
            }
            .navigationTitle(Text(tabNames.count > selectedTab ? tabNames[selectedTab] : ""))
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
        
        //}
    }
}
