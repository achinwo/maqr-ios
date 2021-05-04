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
    
    public enum SelectionMode {
        case single
        case multiple
    }
    
    public init(items: Binding<[Item]>, selections: Binding<[Item.ID]>, mode: SelectionMode = .single, onSelection: @escaping (Item) -> Void, @ViewBuilder content: @escaping (Item) -> Content) {
        self._items = items
        self.content = content
        self.onSelection = onSelection
        self._selections = selections
        self.mode = mode
    }
    
    public init(items: Binding<[Item]>, selections: Binding<[Item.ID]>, mode: SelectionMode = .single, @ViewBuilder content: @escaping (Item) -> Content) {
        self._items = items
        self.content = content
        self._selections = selections
        self.mode = mode
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
    
    public var contentView: some View {
        LazyVGrid(columns: columns, spacing: Sizing.medium){
            
            ForEach(items) { device in
                Button(){
                    logger.debug("[DevicesView] setting active device: \(String(describing: device))")
                    self.onSelection?(device)
                } label: {
                    content(device)
                }
                .padding()
                .background(selections.contains(device.id) ? Color.tertiarySystemBackground : Color.clear)
                .cornerRadius(20)
            }
        }
    }
    
}

//struct GridChooserView_Previews: PreviewProvider {
//    static var previews: some View {
//        GridChooserView()
//    }
//}
