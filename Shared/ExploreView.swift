//
//  ExploreView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI

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

public struct ExploreView: View {
    @State var searchTxt = ""
    @State var searchAreas: [SearchResultCategory] = SearchResultCategory.allCases
    @State var selectedAreas: Set<SearchResultCategory> = []
    
    public init(){
        
    }
    
    var areasFiltered: [SearchResultCategory] {
        return self.searchAreas
    }
    
    public var body: some View {
        
        return VStack {
            SearchBar(text: $searchTxt)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(){
                    ForEach(self.areasFiltered) { area in
                        Button() {
                            print("Selected: \(area)")
                        } label: {
                            Text(area.rawValue.capitalized)
                                .padding()
                                .tag(area).font(.headline)
                        }
                        .buttonStyle(BlackWhiteButtonStyle())
                    }
                }
            }
            Divider()
        }
        
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
    }
}

public struct SearchBar: View {
    
    @Binding var text: String
    @State private var isEditing = false
 
    public var body: some View {
        HStack {
 
            TextField("Search ...", text: $text)
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
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing))
                .animation(.default)
            }
        }
    }
}
