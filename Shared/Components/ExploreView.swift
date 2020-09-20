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


public extension Search.Engine {
    
    func search(_ q: String, _ categories: Set<Search.Category>, limit: Int = 10, api: JoliApi) -> AnyPublisher<[Search.ResultView], Never> {
        
        return Future<[Search.ResultView], Never>() { promise in
            api.searchTracks(q: q, categories: categories, limit: limit)
                .then(){ res in
                    let tracks = res.tracks.enumerated()
                        .map() { trackItem -> Search.ResultView in
                            let res = Search.Result((trackItem.offset, res.tracks.count), q: q, category: .tracks, engine: self)
                            
                            return Search.ResultView(result: res){
                                TrackView2(track: .constant(trackItem.element)).eraseToAnyView()
                            }
                        }
                    
                    let artists = res.artists.enumerated()
                        .map() { item -> Search.ResultView in
                            let artist = item.element
                            let res = Search.Result((item.offset, res.artists.count), q: q, category: .artists, engine: self)
                            
                            return Search.ResultView(result: res){
                                HStack(){
                                    NetworkImage(url: artist.externalUrls.spotify){
                                        PersonGenericImage()
                                            .frame(width: 64, height: 64, alignment: .bottomLeading)
                                    }
                                    VStack(){
                                        Text(artist.name).font(.body)
                                    }
                                }
                                .eraseToAnyView()
                            }
                        }
                    
                    promise(.success(tracks + artists))
                }
                .catch() { error in
                    print("[searchTracks] error: \(error)")
                    promise(.success([]))
                }
        }.eraseToAnyPublisher()
    }
    
}

let spotifyEngine = Search.Engine("FakeSpotify", categories: [.tracks, .playlists, .artists])

public struct ExploreView: JoliView {
    
    static var searchengines: [Search.Engine] {
        return [spotifyEngine, Search.Engine("Joli", categories: .playrooms)]
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
    
    @State var selectedAreas: Set<Search.Category> = [.tracks, .artists]
    
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
                            Text(area.label)
                                .padding()
                                .tag(area).font(.headline)
                        }
                        //.disabled(true)
                        .buttonStyle(BlackWhiteButtonStyle(inverted: selectedAreas.contains(area)))
                    }
                }
            }
            .padding(.bottom, Sizing.small)
            Divider()
            
            if appCoordinator.isSearching {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
            }
        }
        
        return ZStack(alignment: .top) {
            ScrollView(.vertical){
                let top = (searchbarRect?.maxY ?? geoProxy.safeAreaInsets.top) //- geoProxy.safeAreaInsets.top
                let edges = EdgeInsets(top: 180, leading: 0, bottom: 0, trailing: 0)
                if !searchResults.isEmpty {
                    //SearchResultView(searchResults, edgeInsets: edges)
                    
                    VStack(){
                        ForEach(searchResults){ res in
                            res
                        }
                    }
                    .padding(.top, edges.top)
                    .animation(.easeInOut)
                } else {
                    VStack(alignment: .center, spacing: .zero){
                        self.suggestionsView.padding()//.foregroundColor(.white)
                    }
                    .animation(.spring())
                    .padding(.top, edges.top)
                    .frame(width: screenWidth)
                    //.background(Colors.lightGray)
                }
            }
            .padding(.bottom, geoProxy.safeAreaInsets.bottom)
            
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
                
                return spotifyEngine.search(q, self.selectedAreas, api: appCoordinator.api)
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.searchResults, on: self)
            
        
        print("[searchResultPublisher] created: \(String(describing: searchResultPublisher))")
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
