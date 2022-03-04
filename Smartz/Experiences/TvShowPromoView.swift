//
//  TvShowPromoView.swift
//  Joli
//
//  Created by Anthony Chinwo on 06/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import JoliCore

#if !os(macOS)
import SharedUI
#endif

struct TvShowCastInfo: Codable, Identifiable {
    let name: String
    let characterName: String
    let imageUrl: URL
    let bio: String
    let dataType: ExperienceItemType
    
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

public struct TvShowPromoView: Experience, JoliView {
    
    public static var title: String = "Trailer"
    public static var basePath = "ebrand"
    public static var iconName: String = "star.bubble"
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
            \ExperienceData.bannerVideoUrl,
            \ExperienceData.bannerImageUrl,
            \ExperienceData.backgroundImageUrl,
            \ExperienceData.items,
        ]
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return [.person, .product]
    }
    
    @Binding public var editMode: EditingState
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public let dataModelDefault = ExperienceData.Defaults()
    
    @State public var dataModel: ExperienceData?
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    @State var arrivedAt: Date? = Date()
//    @State var trailerUrl = URL(string: "https://storage.googleapis.com/joli-app-bucket/images/crazyworld_netflix_trailer.mp4")!
    //"https://drive.google.com/uc?export=download&id=1thleK6efGtQ_hzTinD6jgHryLnkWBnHC")!
    var castMembers: [TvShowCastInfo] {
        var castMembers: [TvShowCastInfo] = []
        
        for itm in self.dataModel?.items ?? [] {
            
            guard let title = itm.title,
                  let subtitle = itm.subtitle,
                  let alias = itm.aliasTitle,
                  let imgName = itm.imageName,
                  let url = URL(string: imgName) else {
                continue
            }
            
            castMembers.append(TvShowCastInfo(name: title, characterName: alias, imageUrl: url, bio: subtitle, dataType: itm.experienceItemType))
        }
        
        return castMembers
    }
    
    @AppStorage("isvideomuted-crazyworld") var isVideoMuted = false
    
    public init(_ data: ExperienceData? = nil, editMode: Binding<EditingState> = .constant(.inactive)){
        self._editMode = editMode
        self._dataModel = State(initialValue: data)
        self._videoLocalUrl = State(initialValue: FileManager.default.fileExists(atPath: cacheFileUrl.path) ? cacheFileUrl : nil)
        
        //let url = appCoordinator.api.baseUrlHttp
        //.fromExperienceData(crazyworldData, baseUrl: url)
        //ExperienceData.fromExperienceData(crazyworldData, baseUrl: url)
        self._dataModel = State(initialValue: data)
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
    
    @State var videoLocalUrl: URL? = nil
    
    var releaseText: String {
        let releaseDate = dataModel?.releaseDate ?? dataModelDefault.releaseDate
        guard releaseDate > Date() else {
            return "Out Now"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd"
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return "Coming\n\(dateFormatter.string(from: releaseDate))"
    }
    
    @State var youtube: YouTubeControlState = .init()
    
    var productItems: [ExperienceDataItem] {
        return dataModel?.items.filter() { $0.experienceItemType == .product } ?? []
    }
    
    var infoView: some View {
        ScrollViewReader() { proxy in
            ScrollView(showsIndicators: false){
                VStack(spacing: .zero){
                    //PlayerView(url: videoLocalUrl ?? dataModel?.bannerVideoUrl ?? dataModelDefault.bannerVideoUrl, isMuted: self.isVideoMuted)
                    // FIXME: dbindex stikr_experience_data_item_experience_item_type_check
                    let bannerImageView = NetworkImage(url: dataModel?.bannerImageUrl ?? dataModelDefault.bannerImageUrl){
                        ProgressView()
                    }
                    
                    Group(){
                        
                        if dataModel?.bannerVideoUrl == nil {
                            bannerImageView
                        }  else {
                            GeometryReader(){ proxy in
                                    YouTubeView(playerState: youtube)
                                }
                                .onAppear(){
                                    youtube.playVideo()
                                }
                                .background(
                                    VStack(){
                                        bannerImageView
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
                                    .frame(maxHeight: PlayerView.bounds.width / 2)
                                    .clipped()
                                )
                        }
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: screenWidth * 0.8)
                    .frame(maxWidth: screenWidth)
                    .clipped()
                    
                    NetworkImage(url: dataModel?.logoImageUrl ?? dataModelDefault.logoImageUrl){
                            ProgressView()
                        }
                        //.resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        //.frame(width: screenWidth * 0.7)
                        .frame(maxHeight: screenWidth / (productItems.isEmpty ? 5 : 2))
                        .padding()
                        .padding(.top)
                        .padding(.bottom)
                        //.offset(x: 0, y: -200)
                        .id(dataModel?.logoImageUrl ?? dataModelDefault.logoImageUrl)
                        //.backgroundColor(.green)
                    
                    //
                    if productItems.isEmpty {
                        let instaUsername = dataModel?.releasePlatformInstaUsername ?? dataModelDefault.releasePlatformInstaUsername
                        Link(destination: URL(social: .instagramUser(instaUsername))) {
                            HStack(alignment: .center, spacing: .zero){
                                (Text(releaseText).font(.subheadline.weight(.semibold)))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundColor(.primary)
                                    .padding(.trailing)
                                    .lineLimit(1)
                                    .fixedSize()

                                RoundedRectangle(cornerRadius: 4).frame(width: 1.5, height: screenWidth / 10).foregroundColor(.primary)

                                let url = dataModel?.releasePlatformLogoUrl ?? dataModelDefault.releasePlatformLogoUrl
                                NetworkImage(url: url){
                                    ProgressView()
                                }
                                .aspectRatio(contentMode: .fit)
                                .frame(height: screenWidth / 8)
                                .padding(4)
                                .id(url)
                                //.background(Color.pink)
                            }
                        }
                        .frame(maxHeight: screenWidth / 8)
                        .padding(.bottom)
                    }
                    
                    VStack(){
                        (Text(dataModel?.landingPageText ?? dataModelDefault.landingPageText)
                            .font(.subheadline.weight(.light))
                            //.foregroundColor(dataModel?.brandColorSecondary ?? dataModelDefault.brandColorSecondary)
                        )
                        .padding()
                        .padding(.top)
                        .multilineTextAlignment(.center)
                        
                        if !castMembers.isEmpty {
                            Divider().padding(.vertical)
                            
                            Button(){
                                appCoordinator.modal.present() {
                                    .view2(){
                                        TvShowCastTabView(menu: castMembers, dividerColor: dataModel?.brandColorAccent ?? .yellow)
                                            .frame(width: screenWidth)
                                            .eraseToAnyView()
                                    }
                                }
                            } label: {
                                Label(){
                                    Text(productItems.isEmpty ? " Meet The Cast" : " See Our Products")
                                } icon: {
                                    Image(systemName: productItems.isEmpty ? "rectangle.stack.person.crop" : "bag.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(dataModel?.brandColorAccent ?? Color.yellow)
                                        .frame(height: 24)
                                    
                                }
                                .font(.title3.weight(.light))
                                .accentColor(dataModel?.brandColorAccent ?? Color.yellow)
                            }
                            .frame(height: 60)
                            .padding(.bottom)
                        }
                    }
                    .frame(width: screenWidth - 100)
                    .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                    .fixedSize(horizontal: false, vertical: true)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.bottom)
                    .padding(.bottom)
                    .id("body")
                    
                    VStack(){
                        if productItems.isEmpty {
                            Link(destination: URL(social: .instagramUser(dataModel?.releasePlatformInstaUsername ?? dataModelDefault.releasePlatformInstaUsername))) {
                                VStack(){
                                    NetworkImage(url: dataModel?.releasePlatformLogoUrl ?? dataModelDefault.releasePlatformLogoUrl){
                                        ProgressView()
                                    }
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: screenWidth / 3)
                                    .frame(maxHeight: screenWidth / 6)
                                    Text(releaseText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")).font(.callout.weight(.light)).foregroundColor(.secondaryLabel)
                                    Text("@\(dataModel?.releasePlatformInstaUsername ?? dataModelDefault.releasePlatformInstaUsername)").font(.body.weight(.semibold)).foregroundColor(.primary)
                                }//@naijaonnetflix itsacrazyworld_tvseries
                            }
                            .padding(.bottom)
                        }
                        
                        Link(destination: URL(social: .instagramUser(dataModel?.socialInstagramUsername ?? dataModelDefault.socialInstagramUsername))) {
                            VStack(){
                                Image("instagram_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                                Text("Follow us").font(.callout.weight(.light)).foregroundColor(.secondaryLabel)
                                Text("@\(dataModel?.socialInstagramUsername ?? dataModelDefault.socialInstagramUsername)").font(.body.weight(.semibold)).foregroundColor(.primary)
                            }
                        }
                        .padding(.bottom)
                        
                    }
                    .padding(.bottom)
                    
                    Spacer()

                }
                //.frame(idealHeight: screenHeight * 1.5)
                .padding(.bottom, max(100, safeAreaInsets.bottom))
                //.padding(.top, safeAreaInsets.top)
            }
            .background(
                NetworkImage(url: dataModel?.backgroundImageUrl ?? dataModelDefault.backgroundImageUrl){
                    Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                        .resizable()
                }
                .aspectRatio(contentMode: .fill)
            )
            .onAppear(){
                let url = dataModel?.bannerVideoUrl ?? dataModelDefault.bannerVideoUrl
                
                if self.youtube.videoId != .url(url) {
                    self.youtube = YouTubeControlState(.url(url))
                }
            }
        }
    }
    
    public var contentView: some View {
        NavigationView(){
            ZStack(){
                infoView
                    .frame(width: screenWidth, height: screenHeight)
                    .onAppear(){
                    }
            }
            .edgesIgnoringSafeArea(.vertical)
            #if !os(macOS)
            .navigationBarHidden(true)
            #endif
        }
        .edgesIgnoringSafeArea(.vertical)
        #if !os(macOS)
        .showEditPencil(.constant(.readonly))
        #endif
    }
    
}


struct TvShowCastTabView: View {
    
    @State var menu: [TvShowCastInfo]
    @State var dividerColor: Color
    @State private var selectedTab: Int = 0
    
    var tabNames: [String] {
        return menu.map() { $0.name }
    }
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    func castView(_ info: TvShowCastInfo) -> some View {
        VStack(alignment: .leading){
            let isProduct = info.dataType == .product
            Spacer()
            Spacer()
            
            if isProduct {
                Spacer()
            }
            
            VStack(){
                
                let header = VStack(){
                    Text(info.name).font(.largeTitle.weight(.ultraLight))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    (isProduct ? Text("") : Text("as ").font(.callout).foregroundColor(.secondaryLabel) ) + Text(info.characterName).font(.title3)
                    Rectangle().frame(height: 1).foregroundColor(dividerColor.opacity(0.7)).padding(.horizontal)
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
            #if !os(macOS)
            .background(BlurView(colorScheme == .dark ? .systemThinMaterialDark : .systemThinMaterialLight))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 24))
            Spacer()
        }
        .frame(width: screenWidth, height: screenHeight)
        .background(
            ZStack(){
                NetworkImage(url: info.imageUrl){
                    VStack(){
                        ProgressView()
                        Spacer()
                        Spacer()
                    }
                }
                .aspectRatio(contentMode: .fill)
                .frame(minHeight: screenHeight)
                .frame(width: screenWidth)
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
#if !os(macOS)
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
#endif
        }
        
        //}
    }
}
