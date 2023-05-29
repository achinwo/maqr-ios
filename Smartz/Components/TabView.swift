//
//  TabView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 28/05/2023.
//  Copyright © 2023 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI

struct TabContentViewSample: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var currentTab: Int = 0
    @State var tabNames: [String] = ["Test 1", "Test 2"]
    
    var contentView: some View {
        ZStack(alignment: .top) {
            TabView(selection: self.$currentTab) {
                VStack(){
                    Text("View 1")
                }
                .tag(0)
                
                VStack(){
                    Text("View 2")
                }
                .tag(1)
                
                VStack(){
                    Text("View 3")
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.all)
            
            TabBarView(currentTab: self.$currentTab, tabNames: self.$tabNames)
                .frame(minWidth: screenWidth)
        }
    }
}

struct TabBarView: View {
    @Binding var currentTab: Int
    @Binding var tabNames: [String]
    
    @Namespace var namespace
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(zip(self.tabNames.indices, self.tabNames)), id: \.0) {
                    index, name in
                    TabBarItem(currentTab: self.$currentTab,
                               namespace: namespace.self,
                               label: name,
                               index: index)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
        .background(alignment: .bottom){
            Color.gray.opacity(0.2).frame(height: 2)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct TabBarItem: View {
    @Binding var currentTab: Int
    let namespace: Namespace.ID
    
    var label: String
    var index: Int
    
    var body: some View {
        Button {
            self.currentTab = index
        } label: {
            VStack {
                Spacer()
                Text(label)
                    .padding(.horizontal, 10)
                    .foregroundColor(currentTab == index ? .primary : .secondary)
                    
                    if currentTab == index {
                        Color.black
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline",
                                                   in: namespace,
                                                   properties: .frame)
                        
                    } else {
                        Color.clear.frame(height: 2)
                    }
                
            }
            .animation(.spring(), value: self.currentTab)
        }
        .buttonStyle(.plain)
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        TabContentViewSample()
            .environmentObject(AppCoordinator())
    }
    
}
