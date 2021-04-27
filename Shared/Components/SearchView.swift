//
//  SearchView.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

struct BoundsPreferenceData {
    let viewIdx: Int
    let bounds: Anchor<CGRect>
}

struct BoundsPreferenceKey: PreferenceKey {
    typealias Value = CGRect?
    
    static var defaultValue: Value = nil///BoundsPreferenceData()
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

final class SearchStore: ObservableObject {
    
    @Published var query: String = ""
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
                .background(Color(.systemGroupedBackground))
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


//struct SearchView_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchView()
//    }
//}
