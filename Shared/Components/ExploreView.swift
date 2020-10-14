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
import GradientLoadingBar


struct GradientLoadingBarView: UIViewRepresentable {
    
    //let isAnimating: Bool
    //let style: UIActivityIndicatorView.Style

    func makeUIView(context: Context) -> GradientActivityIndicatorView {
        let view = GradientActivityIndicatorView()
        return view
    }

    func updateUIView(_ uiView: GradientActivityIndicatorView, context: Context) {
        //isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}


public extension Search.Category {
 
    mutating func empty() {
        for cat in Self.allCases {
            self.remove(cat)
        }
    }
    
}

let spotifyEngine = Search.Engine("FakeSpotify", categories: [.tracks, .playlists, .artists, .shows, .episodes, .albums])

let joliEngine = Search.Engine("Joli", categories: .playrooms)

public struct ExploreView: JoliView {
    
    static var searchengines: [Search.Engine] {
        return [spotifyEngine, joliEngine]
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
    
    @State var selectedAreas: Set<Search.Category> = [.tracks, .artists, .albums, .playrooms]
    
    @State var searchResults: [Search.ResultView] = [] {
        
        didSet {
            DispatchQueue.main.async {
                appCoordinator.isSearching.empty()
            }
        }
    }
    
    @AppStorage("explore.search.term") var currentSearchTerm: String = ""
    
    @State var searchResultPublisher: AnyCancellable? = nil
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var searchbarRect: CGRect? = nil
    @Binding var playroom: Musicroom?
    @Binding var selectedViewId: String
    
    public init(geoProxy: GeometryProxy, playroom: Binding<Musicroom?>, selectedViewId: Binding<String>) {
        self.geoProxy = geoProxy
        self._playroom = playroom
        self._selectedViewId = selectedViewId
    }
    
    var areasFiltered: Set<Search.Category> {
        return self.searchAreas
    }
    
    var suggestionsView: some View {
        return Group() {
            if currentSearchTerm.isEmpty {
                Label("Nothing here", systemImage: "magnifyingglass")
            } else {
                Label("Searching \"\(currentSearchTerm)\"...", systemImage: "text.magnifyingglass")
            }
        }
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
            
            
            GradientLoadingBarView()
                .opacity(appCoordinator.isSearching.isEmpty ? 0 : 1)
                .animation(.easeInOut(duration: 0.2))
                .frame(height: appCoordinator.isSearching.isEmpty ? 0 : 2)
            
            Divider()
        }
        
        return ZStack(alignment: .top) {
            
                //let top = (searchbarRect?.maxY ?? geoProxy.safeAreaInsets.top) //- geoProxy.safeAreaInsets.top
                let edges = EdgeInsets(top: 180, leading: 0, bottom: 0, trailing: 0)
                if !searchResults.isEmpty {
                    //SearchResultView(searchResults, edgeInsets: edges)
                    
                    List(){
                        let array = Array(resultsByCategory.sorted(by: { $0.key.rawValue < $1.key.rawValue }).enumerated())
                        
                        ForEach(array, id: \.offset) { (idx, item) in
                            let header = HStack(){
                                Text("\(item.key.emoji ?? "")\(item.key.emoji == nil ? "" : " ")\(item.key.labelPlural)")
                                Spacer()
                                Button() {
                                    print("[ExploreView] See all: \(item.key)")
                                    self.seeAllKey = self.seeAllKey == item.key ? nil : item.key
                                } label: {
                                    Image(systemName: self.seeAllKey == item.key ? "rotate.left.fill" : "rotate.right")
                                        .font(.subheadline)
                                        //.resizable()
                                }
                            }
                            .padding(.top, idx == 0 ? 185 : nil)
                            
                            Section(header: header) {
                                ZStack(){
                                    VStack(){
                                        GeometryReader() { proxy in
                                            Text("Flipped it!").font(.largeTitle)
                                        }
                                    }
                                    .background(Colors.lightGray)
                                    //.opacity(self.seeAllKey == item.key ? 1 : 0)
                                    .zIndex(self.seeAllKey == item.key ? 10 : 0)
                                    .rotation3DEffect(self.seeAllKey != item.key ? Angle(degrees: -180) : Angle.zero, axis: (0, 90, 0))
                                        
                                    self.renderContent(item.key, item.value)
                                        .background(Color.white)
                                        //.opacity(self.seeAllKey == item.key ? 0 : 1)
                                        .zIndex(self.seeAllKey == item.key ? 0 : 10)
                                        .rotation3DEffect(self.seeAllKey == item.key ? Angle(degrees: 180) : Angle.zero, axis: (0, 90, 0))
                                }
                                .listRowInsets(EdgeInsets(top: Sizing.small, leading: 0, bottom: Sizing.small, trailing: 0))
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
            
            guard !currentSearchTerm.isEmpty else {
                return
            }
            
            self.model.query = currentSearchTerm
        }
        
    }
    
    @State var seeAllKey: Search.Category? = nil
    
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
    
    // MARK: - Spotify Search
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
                    
                    DispatchQueue.main.async {
                        appCoordinator.isSearching.empty()
                        currentSearchTerm = .empty
                    }
                    
                    return Just([]).eraseToAnyPublisher()
                }
                
                DispatchQueue.main.async {
                    appCoordinator.isSearching.insert(spotifyEngine.supportedCategories.union(joliEngine.supportedCategories))
                    currentSearchTerm = q
                }
                
                let spotifyPub = spotifyEngine.search(q, self.selectedAreas) { (q, categories, limit) in
                    
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
                    }.eraseToAnyPublisher()
                }
                
                let joliPub = joliEngine.search(q, self.selectedAreas) { (q, categories, limit) in
                    
                    return Future<[Search.ResultView], Never>() { promise in
                        guard var url = URLComponents(string: "/api/search") else {
                            return promise(.success([]))
                        }
                        
                        let typeStr = Array(categories).map() { $0.label.lowercased() }.joined(separator: ",")
                        url.queryItems = [
                            URLQueryItem(name: "q", value: q),
                            URLQueryItem(name: "type", value: typeStr),
                            URLQueryItem(name: "limit", value: limit.description),
                        ]
                        
                        HttpMethod.Fetch.get(url: url,
                                             dataType: [Musicroom].self,
                                             baseUrl: api.baseUrlHttp,
                                             urlSession: api.urlSession,
                                             on: .global(qos: .userInitiated))
                            .then(){ rooms in
                                let views = self.makeResultViews(q: q, playrooms: rooms, engine: joliEngine)
                                promise(.success(views))
                            }
                            .catch() { error in
                                print("[searchTracks] error: \(error)")
                                promise(.success([]))
                            }
                    }.eraseToAnyPublisher()
                }
                
                return Publishers.CombineLatest(spotifyPub, joliPub)
                    .scan([Search.ResultView]()) { current, pair -> [Search.ResultView] in
                        return pair.0 + pair.1
                    }
                    .handleEvents() { subs in
                        print("Subscription: \(subs.combineIdentifier)")
                    } receiveOutput: { values in
                        print("in output handler, received \(values.count)")
                    } receiveCompletion: { _ in
                        DispatchQueue.main.async {
                            appCoordinator.isSearching.empty()
                        }
                    } receiveCancel: {
                        DispatchQueue.main.async {
                            appCoordinator.isSearching.empty()
                        }
                    } receiveRequest: { demand in
                        print("received demand: \(demand.description)")
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.searchResults, on: self)
            
        
        print("[searchResultPublisher] created: \(String(describing: searchResultPublisher))")
    }
    
    func makeResultViews(q: Search.Query, playrooms: [Musicroom], engine: Search.Engine) -> [Search.ResultView] {
        
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
        
        appendViews(playrooms, .playrooms) { room, result -> Search.ResultView in
            Search.ResultView(result: result){
                GeometryReader() { proxy in
                    SpotifyItemView(item: room,
                                    images: [],
                                    titleKeyPath: \.name,
                                    subtitleKeyPath: \.details)
                        .onTapGesture {
                            print("[Explore] tapped: \(room)")
                            self.selectedViewId = "views.listen"
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, qos: .userInteractive, flags: .enforceQoS){
                                self.playroom = room
                            }
                        }
                        .eraseToAnyView()
                }
            }
        }
        return results
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
                    TrackView2(track: .constant(track), activeDevice: .constant(nil)).eraseToAnyView()
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
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.gray)
                    .frame(width: 64, height: 64, alignment: .bottomLeading)
            }
            .frame(width: 64, height: 64, alignment: .bottomLeading)
            .clipped()

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
            ExploreView(geoProxy: geoProxy, playroom: .constant(nil), selectedViewId: .constant(.empty))
        }
    }
}
