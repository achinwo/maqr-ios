//
//  ExploreView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import JoliCore
import JoliApi

let spotifyEngine = Search.Engine("FakeSpotify", categories: [.tracks, .playlists, .artists, .shows, .episodes, .albums])

public struct ExploreView: JoliView {
    
    static var searchengines: [Search.Engine] {
        return [spotifyEngine,
                Search.Engine("Joli", categories: .playrooms)
        ]
    }
    
    let geoProxy: GeometryProxy
    @StateObject var model = SearchStore()
    
    var searchAreas: Set<Search.Category> {
        var categories: Set<Search.Category> = []
        
        for cat in Search.Category.allCases {
            for engine in Self.searchengines {
                guard engine.supportedCategories.contains(cat) else {
                    continue
                }
                categories.insert(cat)
            }
        }
        
        return categories
    }
    
    @State var selectedAreas: Set<Search.Category> = [.tracks, .artists, .albums]
    
    @State var searchResults: [Search.ResultView] = []
    
    @State var searchResultPublisher: AnyCancellable? = nil
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var searchbarRect: CGRect? = nil
    
    
    public init(geoProxy: GeometryProxy) {
        self.geoProxy = geoProxy
    }
    
    var areasFiltered: Set<Search.Category> {
        return self.searchAreas
    }
    
    var suggestionsView: some View {
        return Label("Nothing here", systemImage: "magnifyingglass")
    }
    
    var resultsByCategory: [Search.Category: [Search.ResultView]] {
        //var res:  = [:]
//        for resultView in self.searchResults {
//            let result = resultView.result
//
//            if var catResults = res[result.category] {
//                catResults.append(resultView)
//            } else {
//                res[result.category] = [resultView]
//            }
//        }
        
        let res = self.searchResults.reduce(into: [Search.Category: [Search.ResultView]]()) { store, res in
            store[res.result.category, default: []].append(res)
        }
        
        return res
    }
    
    public var body: some View {
        
        let searchBar = VStack(alignment: .center, spacing: 0) {
            SearchBar(text: $model.query)
                .padding(.bottom, Sizing.small)
                .padding(.horizontal, Sizing.medium)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(){
                    ForEach(Array(self.areasFiltered).sorted()) { area in
                        Button() {
                            guard !selectedAreas.contains(area) else {
                                selectedAreas.remove(area)
                                return
                            }
                            selectedAreas.insert(area)
                            
                            print("Selected: \(selectedAreas)")
                        } label: {
                            HStack(){
                                if appCoordinator.isSearching.contains(area) && selectedAreas.contains(area) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .fixedSize()
                                        .frame(width: 4, height: 4)
                                        .padding(.all, 2)
                                }
                                Text(area.labelPlural)
                                    .layoutPriority(1000)
                                    .tag(area).font(.subheadline)
                            }
                            .animation(.easeInOut)
                            .padding()
                        }
                        //.disabled(true)
                        .buttonStyle(BlackWhiteButtonStyle(inverted: selectedAreas.contains(area)))
                    }
                }
            }
            .padding(.bottom, Sizing.small)
            Divider()
        }
        
//        let x = VStack(alignment: .leading) {
//            //Text("Testing test")
//            ForEach(Array(resultsByCategory.sorted(by: >)), id: \.0) { key, value in
//                value
//            }
//        }
        
        return ZStack(alignment: .top) {
            
                //let top = (searchbarRect?.maxY ?? geoProxy.safeAreaInsets.top) //- geoProxy.safeAreaInsets.top
                let edges = EdgeInsets(top: 180, leading: 0, bottom: 0, trailing: 0)
                if !searchResults.isEmpty {
                    //SearchResultView(searchResults, edgeInsets: edges)
                    
                    List(){
                        let array = Array(resultsByCategory.sorted(by: { $0.key.label > $1.key.label }).enumerated())
                        
                        ForEach(array, id: \.offset) { (idx, item) in
                            let header = HStack(){
                                Text("\(item.key.emoji ?? "")\(item.key.emoji == nil ? "" : " ")\(item.key.labelPlural)")
                                Spacer()
                                Button() {
                                    print("[ExploreView] See all: \(item.key)")
                                } label: {
                                    Label("See All", systemImage: "arrow.up.left.and.arrow.down.right")
                                }
                            }
                            .padding(.top, idx == 0 ? 185 : nil)
                            
                            Section(header: header) {
                                self.renderContent(item.key, item.value)
                                    .listRowInsets(EdgeInsets(top: Sizing.medium, leading: 0, bottom: Sizing.medium, trailing: 0))
                            }
                            //.clipped()
                        }
                    }
                    //.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .listStyle(GroupedListStyle())
                    //.padding(.top, edges.top)
                    .animation(.easeInOut)
                    .padding(.bottom, geoProxy.safeAreaInsets.bottom > screenHeight / 4 ? geoProxy.safeAreaInsets.bottom : 0)
                } else {
                    VStack(alignment: .center, spacing: .zero){
                        self.suggestionsView.padding()//.foregroundColor(.white)
                    }
                    .animation(.spring())
                    .padding(.top, edges.top)
                    .frame(width: screenWidth)
                    .padding(.bottom, geoProxy.safeAreaInsets.bottom)
                }
            
            searchBar
                .accentColor(.primary)
                .padding(.top, geoProxy.safeAreaInsets.top)
                //.anchorPreference(key: BoundsPreferenceKey.self, value: .bounds) { $0 }
                .background(
                    GeometryReader { geometry in
                        //Rectangle()
                        //.fill(Color.clear)
                        return Color.white.opacity(0.86)
                            .preference(key: BoundsPreferenceKey.self,
                                        value: geometry.frame(in: .named("myZstack")))
                    }
                )
            
            
        }
        .coordinateSpace(name: "myZstack")
        .onChange(of: selectedAreas){ areas in
            self.updateSubscriptions()
        }
        .onAppear(){
            self.updateSubscriptions()
        }
        
    }
    
    private func renderContent(_ key: Search.Category, _ views: [Search.ResultView]) -> some View {
        return VStack(alignment: .leading, spacing: .zero){
            ForEach(Array(views.enumerated()), id: \.offset) { itm in
                
                switch itm.element.result.category {
                    case .tracks:
                        itm.element
                            .frame(width: UIScreen.main.bounds.width, height: 68)
                            .id(itm.element.id)
                    default:
                        itm.element.frame(height: 65)
                            .id(itm.element.id)
                }
                
                //                                        if idx + 1 < resultViews.count {
                //                                            Divider().padding()
                //                                        }
            }
        }
    }
    
    private func updateSubscriptions() {
        if let cancel = self.searchResultPublisher {
            cancel.cancel()
            print("[searchResultPublisher] cancelled: \(cancel)")
        }
        
        self.searchResultPublisher = model.$query
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .userInteractive))
            .map() { q -> AnyPublisher<[Search.ResultView], Never> in
                
                guard !q.isEmpty else {
                    return Just([]).eraseToAnyPublisher()
                }
                
                var isSearching = appCoordinator.isSearching
                
                for opt in Search.Category.allCases {
                    guard spotifyEngine.supportedCategories.contains(opt) else {
                        continue
                    }
                    
                    isSearching.insert(opt)
                }
                
                DispatchQueue.main.async {
                    appCoordinator.isSearching = isSearching
                }
                
                return spotifyEngine.search(q, self.selectedAreas) { (q, categories, limit) in
                    
                    return Future<[Search.ResultView], Never>() { promise in
                        api.searchTracks(q: q, categories: categories, limit: limit)
                            .then(){ res in
                                let views = self.makeResultViews(q: q, res: res)
                                promise(.success(views))
                            }
                            .catch() { error in
                                print("[searchTracks] error: \(error)")
                                promise(.success([]))
                            }
                            .always() {
                                
                                var isSearching = appCoordinator.isSearching
                                
                                for opt in Search.Category.allCases {
                                    isSearching.remove(opt)
                                }
                                
                                DispatchQueue.main.async {
                                    appCoordinator.isSearching = isSearching
                                }
                            }
                    }.eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.searchResults, on: self)
            
        
        print("[searchResultPublisher] created: \(String(describing: searchResultPublisher))")
    }
    
    func makeResultViews(q: Search.Query, res: Spotify.SearchResult) -> [Search.ResultView] {
        
        var results: [Search.ResultView] = []
        
        func appendViews<T>(_ items: [T], _ category: Search.Category, convert: (T, Search.Result) -> Search.ResultView?) {
            items.enumerated()
                .forEach() { item in
                    let res = Search.Result((item.offset, items.count), q: q, category: category, engine: spotifyEngine)
                    
                    guard let view = convert(item.element, res) else {
                        return
                    }
                    
                    results.append(view)
                }
        }
        
        appendViews(res.tracks, .tracks) { track, result in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    TrackView2(track: .constant(track)).eraseToAnyView()
                }
            }
        }
        
        appendViews(res.albums, .albums) { album, result in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    SpotifyItemView(item: album,
                                    images: album.images,
                                    titleKeyPath: \.name,
                                    subtitleKeyPath: \.releaseDate)
                        .eraseToAnyView()
                }
            }
        }
        
        appendViews(res.artists, .artists) { artist, result in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    ArtistView(artist: artist)
                    .eraseToAnyView()
                }
            }
        }
        
        appendViews(res.playlists, .playlists) { playlist, result in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    SpotifyItemView(item: playlist,
                                    images: playlist.images,
                                    titleKeyPath: \.name,
                                    subtitleKeyPath: \.description)
                    .eraseToAnyView()
                }
            }
        }
        
        appendViews(res.episodes, .episodes) { episode, result in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    SpotifyItemView(item: episode,
                                    images: episode.images,
                                    titleKeyPath: \.name,
                                    subtitleKeyPath: \.description)
                    .eraseToAnyView()
                }
            }
        }
        
        appendViews(res.shows, .shows) { show, result in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    SpotifyItemView(item: show,
                                    images: show.images,
                                    titleKeyPath: \.name,
                                    subtitleKeyPath: \.description)
                    .eraseToAnyView()
                }
            }
        }
        
        return results
    }
}

public struct SpotifyItemView<Item>: View {
    
    @State var item: Item
    let images: [Spotify.Image]?
    let titleKeyPath: KeyPath<Item, String>
    let subtitleKeyPath: KeyPath<Item, String>
    
    public var body: some View {
        HStack(){
            NetworkImage(string: images?.smallestImage?.url){
                Image(systemName: "music.note.list")
                    .resizable()
                    .foregroundColor(.white)
                    .background(Color.gray)
                    .frame(width: 64, height: 64, alignment: .bottomLeading)
            }
            .frame(width: 64, height: 64, alignment: .bottomLeading)

            VStack(alignment: .leading){
                Text(item[keyPath: titleKeyPath]).font(.body)

                Text(item[keyPath: subtitleKeyPath])
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

public struct ArtistView: View {
    @State var artist: Spotify.Artist
    
    public var body: some View {
        HStack(){
            NetworkImage(string: artist.images?.smallestImage?.url){
                PersonGenericImage()
                    .frame(width: 64, height: 64, alignment: .bottomLeading)
            }
            .frame(width: 64, height: 64, alignment: .bottomLeading)
            .clipShape(Circle())
            
            VStack(alignment: .leading){
                Text(artist.name).font(.body)
                
                if let genres = artist.genres {
                    Text(genres.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

public extension Array where Element == Spotify.Image {
    
    var smallestImage: Spotify.Image? {
        return self.last
    }
    
    var largestImage: Spotify.Image? {
        return self.first
    }
    
    var mediumImage: Spotify.Image? {
        guard count >= 2 else {
            return self.largestImage
        }
        return self[1]
    }
    
}

struct DarkBlueShadowProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ProgressView(configuration)
            .shadow(color: Color(red: 0, green: 0, blue: 0.6),
                    radius: 4.0, x: 1.0, y: 2.0)
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader() { geoProxy in
            ExploreView(geoProxy: geoProxy)
        }
    }
}
