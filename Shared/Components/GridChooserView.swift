//
//  GridChooserView.swift
//  Joli
//
//  Created by Anthony Chinwo on 04/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI

public struct GridChooserView<Item: Identifiable, Content: View>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Binding var items: [Item]
    @Binding var selections: [Item.ID]
    
    var onSelection: ((Item) -> Void)? = nil
    let content: (Item) -> Content
    let mode: SelectionMode
    let layout: LayoutStyle
    
    public enum SelectionMode {
        case single
        case multiple
    }
    
    public enum LayoutStyle {
        case grid
        case list
    }
    
    public init(items: Binding<[Item]>, selection: Binding<Item.ID?>, layout: LayoutStyle = .grid, onSelection: @escaping (Item) -> Void, @ViewBuilder content: @escaping (Item) -> Content) {
        self._items = items
        self.content = content
        self.onSelection = onSelection
        
        self._selections = Binding<[Item.ID]>(){
            guard let id = selection.wrappedValue else {
                return []
            }
            
            return [id]
        } set: { ids in
            selection.wrappedValue = ids.first
        }
        
        self.mode = .single
        self.layout = layout
    }
    
    public init(items: Binding<[Item]>, selections: Binding<[Item.ID]>, layout: LayoutStyle = .grid, @ViewBuilder content: @escaping (Item) -> Content) {
        self._items = items
        self.content = content
        self._selections = selections
        self.mode = .multiple
        self.layout = layout
        self.onSelection = self.onSelect(_:)
    }
    
    private func onSelect(_ item: Item) {
        guard mode == .multiple else {
            self.selections = [item.id]
            return
        }
         
        guard !self.selections.contains(item.id) else {
            return
        }
        
        self.selections.append(item.id)
    }
    
    var columns: [GridItem] {
        return [
            GridItem(),
            GridItem(),
        ]
    }
    
    private var forEachView: some View {
        ForEach(items) { item in
            Button(){
                self.onSelection?(item)
            } label: {
                content(item)
            }
            .cornerRadius(20)
            .id(item.id)
        }
    }
    
    public var contentView: some View {
        Group(){
            if layout == .grid {
                LazyVGrid(columns: columns, spacing: Sizing.medium){
                    forEachView
                }
            } else {
                VStack(){
                    forEachView
                }
            }
        }
    }
    
}

//struct GridChooserView_Previews: PreviewProvider {
//    static var previews: some View {
//        GridChooserView()
//    }
//}
