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
    let cornerRadius: CGFloat?
    
    public enum SelectionMode {
        case single
        case multiple
    }
    
    public enum LayoutStyle {
        case grid(Int)
        case list
        
        public static var grid: LayoutStyle {
            return .grid(2)
        }
    }
    
    public init(items: Binding<[Item]>, selection: Binding<Item.ID?>, layout: LayoutStyle = .grid, cornerRadius: CGFloat? = 20, onSelection: @escaping (Item) -> Void, @ViewBuilder content: @escaping (Item) -> Content) {
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
        self.cornerRadius = cornerRadius
    }
    
    public init(items: Binding<[Item]>, selections: Binding<[Item.ID]>, layout: LayoutStyle = .grid, cornerRadius: CGFloat? = 20, @ViewBuilder content: @escaping (Item) -> Content) {
        self._items = items
        self.content = content
        self._selections = selections
        self.mode = .multiple
        self.layout = layout
        self.cornerRadius = cornerRadius
    }
    
    private func onSelect(_ item: Item) {
        guard mode == .multiple else {
            self.selections = [item.id]
            return
        }
         
        if self.selections.contains(item.id) {
            self.selections.removeAll(where: { $0 == item.id })
        } else {
            self.selections.append(item.id)
        }
    }
    
    private var forEachView: some View {
        ForEach(items) { item in
            Button(){
                self.onSelect(item)
                self.onSelection?(item)
            } label: {
                content(item)
            }
            .cornerRadius(cornerRadius ?? .zero)
            .id(item.id)
        }
    }
    
    public var contentView: some View {
        Group(){
            if case let .grid(columnCount) = layout {
                let columns = (0 ..< columnCount).map() { _ in GridItem() }
                
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
