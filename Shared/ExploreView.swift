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

public enum SearchResult: Identifiable {
    public var id: String {
        switch self {
        case .tracks(let tracks):
            return tracks.map { $0.uri }.joined(separator: "/")
        }
    }
    
    case tracks([Playable])
}
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

public enum SearchResultLayout: Identifiable {
    
    public var id: String {
        switch self {
        case .sixGrid(_):
            return "sixGrid"
        case .threeGrid(_):
            return "threeGrid"
        }
    }
    
    case threeGrid([SearchResult])
    case sixGrid([SearchResult])
    
    static func auto(_ results: [SearchResult]) -> [SearchResultLayout] {
        var res: [SearchResultLayout] = []
        for chunk in results.chunked(into: 6){
            res.append(.sixGrid(chunk))
        }
        return res
    }
}

public enum SearchResultSection: Identifiable {
    
    public var id: String {
        switch self {
        case .basic(let name, _):
            return name
        }
    }
    
    case basic(name: String, layout: [SearchResultLayout])
}

enum SearchResultCategory: String, CaseIterable, Identifiable {
    
    var id: String {
        return self.rawValue
    }
    
    case sports
    case movies
    case songs
    case culture
    case places
    case history
}

public struct SearchResultView: View {
    
    var columns: [GridItem] {
        return [
            GridItem(.adaptive(minimum: screenWidth / 6, maximum: screenWidth / 3)),
            GridItem(.adaptive(minimum: screenWidth / 6, maximum: screenWidth / 3)),
            GridItem(.adaptive(minimum: screenWidth / 6, maximum: screenWidth / 3))
        ]
    }
    
    @State var resultSections: [SearchResultSection]
    
    var results: [SearchResult] {
        var res: [SearchResult] = []
        for section in resultSections {
            switch section {
            case .basic(_, let layouts):
                for layout in layouts {
                    switch layout {
                    case .sixGrid(let results), .threeGrid(let results):
                        res.append(contentsOf: results)
                    }
                }
            }
        }
        return res
    }
    
    public init(_ results: [SearchResultSection]){
        self._resultSections = State(initialValue: results)
    }
    
    public func trackView(_ track: Playable) -> some View {
        return VStack(){
            NetworkImage(imageURL: URL(string: track.albumCoverUrl)!, placeholderImage: UIImage(systemName: "heart")!)
            Text(track.title).font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
    
    public func layoutContentBasic(_ layout: SearchResultLayout) -> some View {
        return VStack(){
            switch layout {
            case .sixGrid(let results), .threeGrid(let results):
                
                ForEach(results){ result in
                    switch result {
                    case .tracks(let tracks):
                        LazyVGrid(columns: columns) {
                            ForEach(tracks, id: \.uri) { track in
                                self.trackView(track)
                            }
                        }
                    }
                }
            }
        }
    }
    
    public var body: some View {
//        ScrollView(.vertical, showsIndicators: true){
//            ZStack(){
        return List(){
                    ForEach(resultSections) { section in
                        switch section {
                        case .basic(let name, let layouts):
                            Section(header: Text(name)) {
                                VStack(){
                                    ForEach(layouts) { layout in
                                        self.layoutContentBasic(layout)
                                    }
                                }
                                .frame(width: screenWidth, height: screenWidth)
                                .fixedSize()
                                .clipped()
                            }.background(Color.clear)
                        }
                    }
                }.listStyle(GroupedListStyle())//.padding(.top, Sizing.medium)
    }
}

final class SearchStore: ObservableObject {
    
    @Published var query: String = ""

    func fetch() {
//        $query
//            .map { URL(string: $0) }
//            .flatMap { URLSession.shared.dataTaskPublisher(for: $0) }
//            .sink { print($0) }
    }
}

public struct ExploreView: View {
    
    @StateObject var model = SearchStore()
    @State var searchAreas: Set<SearchResultCategory> = Set(SearchResultCategory.allCases)
    @State var selectedAreas: Set<SearchResultCategory> = []
    @State var searchResults: [SearchResult] = [.tracks(Array(SEED_DATA.tracks[0...10]))]
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var cancellSet: Set<AnyCancellable> = []
    
    public init(){
        //let cancellable = $searchTxt
            
    }
    
    var areasFiltered: Set<SearchResultCategory> {
        return self.searchAreas
    }
    
    var suggestionsView: some View {
        return Label("Nothing here", systemImage: "magnifyingglass")
    }
    
    public var body: some View {
        let ts: [SearchResult] = [.tracks(Array(SEED_DATA.tracks[10...20]))]
        let cs: [SearchResult] = [.tracks(Array(SEED_DATA.tracks[20...30]))]
        
        let sections: [SearchResultSection] = [
            .basic(name: "Tracks", layout: SearchResultLayout.auto(searchResults)),
            .basic(name: "Videos", layout: SearchResultLayout.auto(ts)),
            .basic(name: "Podcasts", layout: SearchResultLayout.auto(cs)),
        ]
        return VStack(alignment: .center, spacing: 0) {
            SearchBar(text: $model.query)
                .padding(.bottom, Sizing.small)
                .padding(.horizontal, Sizing.medium)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(){
                    ForEach(Array(self.areasFiltered)) { area in
                        Button() {
                            guard !selectedAreas.contains(area) else {
                                selectedAreas.remove(area)
                                return
                            }
                            selectedAreas.insert(area)
                            
                            print("Selected: \(selectedAreas)")
                        } label: {
                            Text(area.rawValue.capitalized)
                                .padding()
                                .tag(area).font(.headline)
                        }
                        .buttonStyle(BlackWhiteButtonStyle(inverted: selectedAreas.contains(area)))
                    }
                }
            }
            .padding(.bottom, Sizing.small)
            Divider()
            
            if appCoordinator.isSearching {
                ProgressView(value: nil, total: 100).padding()
            }
            
            if !searchResults.isEmpty {
                SearchResultView(sections)
            } else {
                VStack(alignment: .center, spacing: .zero){
                    self.suggestionsView.padding()//.foregroundColor(.white)
                }
                .frame(width: screenWidth)
                //.background(Colors.lightGray)
            }
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

public struct SearchBar: View {
    
    @Binding var text: String
    @Binding var isEditing: Bool
    @State private var isEditing_ = false
    
    private let useInternalState: Bool
    
    public init(text: Binding<String>, isEditing: Binding<Bool>? = nil){
        self.useInternalState = isEditing == nil
        self._text = text
        self._isEditing = isEditing ?? .constant(false)
    }
 
    public var body: some View {
        let isEditing = self.useInternalState ? self.isEditing_ : self.isEditing
        return HStack {
 
            TextField("Search", text: $text)
                .font(Font.callout.weight(.light))
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                 
                        if isEditing {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                //.padding(.horizontal, 10)
                .onTapGesture {
                    self.setIsEditing(true)
                }
 
            if isEditing {
                Button(action: {
                    self.setIsEditing(false)
                    self.text = ""
 
                }) {
                    Text("Cancel").fontWeight(.light)
                }
                .padding(.trailing, Sizing.medium)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }
    
    private func setIsEditing(_ value: Bool){
        self.isEditing = value
        self.isEditing_ = value
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
    }
}
