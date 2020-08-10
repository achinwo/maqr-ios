//
//  ExploreView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine

public enum SearchResult {
    case section(String)
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
            GridItem(),
            GridItem(),
            GridItem()
        ]
    }
    
    @State var results: [SearchResult]
    
    public init(_ results: [SearchResult]){
        self._results = State(initialValue: results)
    }
    
    public var body: some View {
        return VStack(){
            LazyVGrid(columns: columns, pinnedViews: [.sectionHeaders]) {
                Section(header: Text("Test")) {
                    
                }
            }
        }
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
    @State var searchResults: [SearchResult]? = nil
    
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
        
        return VStack() {
            SearchBar(text: $model.query)
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
            Divider()
            if let searchResults = searchResults {
                SearchResultView(searchResults)
            } else if appCoordinator.isSearching {
                ProgressView().padding()
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

public struct SearchBar: View {
    
    @Binding var text: String
    @State private var isEditing = false
 
    public var body: some View {
        HStack {
 
            TextField("Search", text: $text)
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
                .padding(.horizontal, 10)
                .onTapGesture {
                    self.isEditing = true
                }
 
            if isEditing {
                Button(action: {
                    self.isEditing = false
                    self.text = ""
 
                }) {
                    Text("Cancel")
                }
                .padding(.trailing, Sizing.medium)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
    }
}
