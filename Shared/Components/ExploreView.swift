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
    
    func search(_ q: String, _ categories: Set<Search.Category>, api: JoliApi) -> AnyPublisher<[Search.ResultView], Never> {
        
        return Future<[Search.ResultView], Never>() { promise in
            api.searchTracks(q: q, categories: categories)
                .then(){ res in
                    let res = res.tracks.enumerated()
                        .map() { trackItem -> Search.ResultView in
                            let res = Search.Result((trackItem.offset, res.tracks.count), q: q, category: .tracks, engine: self)
                            
                            return Search.ResultView(result: res){
                                TrackView2(track: .constant(trackItem.element)).eraseToAnyView()
                            }
                        }
                    promise(.success(res))
                }
                .catch() { error in
                    print("[searchTracks] error: \(error)")
                    promise(.success([]))
                }
        }.eraseToAnyPublisher()
    }
    
}

let spotifyEngine = Search.Engine("FakeSpotify", categories: [.tracks, .playlists])

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
    
    @State var selectedAreas: Set<Search.Category> = []
    
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
                let edges = EdgeInsets(top: top, leading: 0, bottom: 0, trailing: 0)
                if !searchResults.isEmpty {
                    //SearchResultView(searchResults, edgeInsets: edges)
                    
                    LazyVStack(){
                        ForEach(searchResults){ res in
                            res
                        }
                    }
                    .animation(.easeInOut)
                } else {
                    VStack(alignment: .center, spacing: .zero){
                        self.suggestionsView.padding()//.foregroundColor(.white)
                    }
                    .padding(.top, edges.top)
                    .frame(width: screenWidth)
                    //.background(Colors.lightGray)
                }
            }
            .offset(x: 0, y: 180)
            
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
        .onAppear(){
            guard self.searchResultPublisher == nil else {
                return
            }
            
            self.searchResultPublisher = model.$query
                .removeDuplicates()
                .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .userInteractive))
                .map() { q -> AnyPublisher<[Search.ResultView], Never> in
                    
                    guard !q.isEmpty else {
                        return Just([]).eraseToAnyPublisher()
                    }
                    
                    return spotifyEngine.search(q, [.tracks], api: appCoordinator.api)
                }
                .switchToLatest()
                .receive(on: RunLoop.main)
                .assign(to: \.searchResults, on: self)
                
            
            print("[searchResultPublisher] created: \(String(describing: searchResultPublisher))")
        }
        
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
