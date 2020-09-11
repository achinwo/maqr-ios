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
        case .playrooms(let rooms):
            return rooms.map { $0.id.description }.joined(separator: "/")
        case .tracks(let tracks):
            return tracks.map { $0.uri }.joined(separator: "/")
        case .users(let users):
            return users.map { $0.id.description }.joined(separator: "/")
        }
    }
    
    public var tracks: [Playable]? {
        guard case let .tracks(tracks) = self else {
            return nil
        }
        
        return tracks
    }
    
    public var users: [User]? {
        guard case let .users(users) = self else {
            return nil
        }
        
        return users
    }
    
    public var playrooms: [Musicroom]? {
        guard case let .playrooms(rooms) = self else {
            return nil
        }
        
        return rooms
    }
    
    public var items: [Any] {
        return self.playrooms ?? self.tracks ?? self.users ?? []
    }
    
    case playrooms([Musicroom])
    case tracks([Playable])
    case users([User])
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == SearchResult {
    
    func toLayouts() -> [SearchResultLayout] {
        var res: [SearchResultLayout] = []
        for result in self {
            switch result {
            case .playrooms(let rooms):
                for chunk in rooms.chunked(into: 3) {
                    res.append(Int.random(in: 0...10) % 2 == 0 ? .sixGrid([.playrooms(chunk)]) : .threeList([.playrooms(chunk)]))
                }
            case .tracks(let tracks):
                for chunk in tracks.chunked(into: 6) {
                    res.append(Int.random(in: 0...10) % 2 == 0 ? .sixGrid([.tracks(chunk)]) : .threeList([.tracks(chunk)]))
                }
            case .users(let users):
                for chunk in users.chunked(into: 3) {
                    res.append(Int.random(in: 0...10) % 2 == 0 ? .sixGrid([.users(chunk)]) : .threeList([.users(chunk)]))
                    //res.append(.threeGrid([.tracks(chunk)]))
                }
            }
        }
        return res
    }
    
}

public enum SearchResultLayout: View {
    
    var columns: [GridItem] {
        return [
            GridItem(.adaptive(minimum: screenWidth / 6, maximum: screenWidth / 3)),
            GridItem(.adaptive(minimum: screenWidth / 6, maximum: screenWidth / 3)),
            GridItem(.adaptive(minimum: screenWidth / 6, maximum: screenWidth / 3))
        ]
    }
    
    public func trackView(_ track: Playable) -> some View {
        return VStack(){
            NetworkImage(url: track.albumCoverUrl) {
                ProgressView(value: nil, total: 100)
            }
            .frame(width: 64, height: 64)
            Text(track.title).font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
    
    public var body: some View {
        let onRoomTap = {
            
        }
        return VStack(){
            switch self {
                case .sixGrid(let results), .threeGrid(let results):
                    ForEach(results){ result in
                        LazyVGrid(columns: columns) {
                            if let tracks = result.tracks {
                                ForEach(tracks, id: \.uri) { track in
                                    self.trackView(track)
                                }
                            } else if let users = result.users {
                                ForEach(users) { user in
                                    VStack() {
                                        Group(){
                                            if let urlStr = user.imageLarge,
                                               let url = URL(string: "/images/\(urlStr)", relativeTo: URL(string: "https://192.168.1.173:8080")) {
                                                NetworkImage(url: url) {
                                                    PersonGenericImage()
                                                        .frame(width: 64, height: 64)
                                                }
                                                .frame(width: 64, height: 64)
                                            } else {
                                                PersonGenericImage()
                                                    .frame(width: 64, height: 64)
                                            }
                                        }
                                        .clipShape(Circle())
                                        Text(user.name).font(.body)
                                    }
                                    //CircleImage(url: user.im)
                                }
                            } else if let rooms = result.playrooms {
                                ForEach(rooms) { room in
                                    VStack(){
                                        Images.stockPhotoPartyPeople.image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                        Text(room.name)
                                    }.onTapGesture(perform: onRoomTap)
                                }
                            }
                        }
                    }
                case .threeList(let results):
                    ForEach(results){ result in
                        if let tracks = result.tracks {
                            TrackList(tracks: .constant(tracks as! [Track]))
                        } else if let users = result.users {
                            List {
                                ForEach(users) { user in
                                    Text("\(user.name)").font(.body)
                                    //CircleImage(url: user.im)
                                }
                            }
                        } else if let rooms = result.playrooms {
                            ForEach(rooms) { room in
                                VStack(){
                                    Images.stockPhotoPartyPeople.image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                    Text(room.name)
                                }.onTapGesture(perform: onRoomTap)
                            }
                        }
                    }
            }
        }
    }
    
    case threeGrid([SearchResult])
    case sixGrid([SearchResult])
    case threeList([SearchResult])
    
}

public enum SearchResultSection: Identifiable, View {
    
    public var id: String {
        switch self {
        case .basic(let name, _):
            return name
        }
    }
    
    public var body: some View {
        switch self {
            case .basic(let name, let layouts):
                Section(header: Text(name)) {
                    VStack(){
                        ForEach(Array(layouts.enumerated()), id: \.offset) { idx, layout in
                            layout//.background([Color.red, Color.yellow, Color.blue].randomElement())
                            
                            if idx + 1 < layouts.count {
                                Divider().padding()
                            }
                        }
                    }
                    //.frame(width: screenWidth, height: screenWidth)
                    //.fixedSize()
                    .clipped()
                }
                .background(Color.clear)
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
    //case culture
    case places
    //case history
    case playrooms
}

public struct SearchResultView: View {
    
    
    @State var resultSections: [SearchResultSection]
    
    var results: [SearchResult] {
        var res: [SearchResult] = []
        for section in resultSections {
            switch section {
            case .basic(_, let layouts):
                for layout in layouts {
                    switch layout {
                    case .sixGrid(let results), .threeGrid(let results), .threeList(let results):
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
    
    public var body: some View {
//        ScrollView(.vertical, showsIndicators: true){
//            ZStack(){
        return List(){
                    ForEach(resultSections) { section in
                        section
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

extension Array: View where Element == SearchResultSection {
    
    public var body: some View {
        return SearchResultView(self)
    }
}

public struct ExploreView: JoliView {
    
    @StateObject var model = SearchStore()
    @State var searchAreas: Set<SearchResultCategory> = Set(SearchResultCategory.allCases)
    @State var selectedAreas: Set<SearchResultCategory> = []
    @State var searchResults: [SearchResult] = [.tracks(Array(SEED_DATA.tracks[50...60]))]
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
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
        let rooms: [SearchResult] = [.playrooms(Array(SEED_DATA.musicrooms))]
        
        let sections: [SearchResultSection] = [
            .basic(name: "Tracks", layout: searchResults.toLayouts()),
            .basic(name: "Playrooms", layout: rooms.toLayouts()),
            .basic(name: "Users", layout: [SearchResult.users(SEED_DATA.users)].toLayouts()),
            .basic(name: "Playlists", layout: ts.toLayouts()),
            .basic(name: "Podcasts", layout: cs.toLayouts()),
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
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
            }
            
            if !searchResults.isEmpty {
                sections
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
