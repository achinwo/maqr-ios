//
//  CodeDesignerView.swift
//  Joli
//
//  Created by Anthony Chinwo on 17/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground

public struct CodeDesignerWorkflowView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @State var selectedTab = 0
    
    @State var selectedExperience: String? = nil
    
    var tabNames: [String] {
        return [
            "Pick an Experience",
            "Customise Experience",
            "Customise Code",
            "Confirm & Pay",
        ]
    }
    
    var pickExperienceView: some View {
        VStack(){
            Text("Pick Experience")
            //Spacer()
            Button(){
                selectedExperience = "hello"
                selectedTab = selectedTab + 1
            } label: {
                Text("Next").font(.title).foregroundColor(.fixedWhite)
            }
        }
    }
    
    var customiseExperienceView: some View {
        VStack(){
            Text("Customise Experience")
        }
    }
    
    var customiseCodeView: some View {
        VStack(){
            Text("Customise Code")
        }
    }
    
    var confirmAndPayView: some View {
        VStack(){
            Text("Confirm & Pay")
        }
    }
    
    var views: [(view: AnyView, index: Int)] {
        var vs: [(view: AnyView, index: Int)] = [
         (pickExperienceView
            .background(Color.blue)
            .eraseToAnyView(), 0),
        ]
        
        if let selectedExperience = selectedExperience {
            vs.append((
                customiseExperienceView
                    .background(Color.green)
                    .eraseToAnyView(), 1
            ))
        }
        
        if let selectedExperience = selectedExperience {
            vs.append((
                customiseCodeView
                    .background(Color.purple)
                    .eraseToAnyView(), 2
            ))
        }
        
        if let selectedExperience = selectedExperience {
            vs.append((
                confirmAndPayView
                    .background(Color.purple)
                    .eraseToAnyView(), 3
            ))
        }
        
        print("Views count: \(vs.count)")
        return vs
    }
    
    public var contentView: some View {
        ZStack(){
            TabView(selection: $selectedTab) {
                ForEach(self.views, id: \.index){ item in
                    item.view
                        .tag(item.index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
            
            HStack(){
                VStack(alignment: .leading){
                    Text(tabNames[selectedTab])
                        .font(.title)
                        .padding([.trailing, .leading, .top])
                    Text("Step \(selectedTab + 1) of \(tabNames.count)")
                        .font(.caption)
                        .foregroundColor(.secondaryLabel)
                        .padding([.trailing, .leading, .bottom])
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
}

public struct CodeDesignerView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public var contentView: some View {
        VStack(){
            Image("appclipcode_with_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: screenWidth / 2)
                .overlay(
                    GeometryReader() { proxy in
                        Text("Coming Soon")
                            .fixedSize(horizontal: true, vertical: true)
                            .font(.title)
                            .foregroundColor(.fixedWhite)
                            .padding()
                            .padding(.horizontal, proxy.size.height / 8)
                            .background(Color.fixedGray)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .offset(x: proxy.size.width / 2 * -1, y: proxy.size.height / 4)
                            .rotationEffect(.degrees(-45), anchor: .leading)
                    }
                )
                .clipped()
            Button(){
                self.appCoordinator.globalModalSubject.send(
                    .view2() {
                        GeometryReader(){ proxy in
                            CodeDesignerWorkflowView()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .background(Color.pink)
                        }
                        .environmentObject(appCoordinator)
                        .eraseToAnyView()
                    }
                )
            } label: {
              Text("Create Code")
            }
        }
//        Text("App Clip Code Generator").font(.largeTitle).multilineTextAlignment(.center).foregroundColor(.primary).padding()
//        Text("Design and download custom auto-downloading App Clip codes for your brand!").font(.title2).foregroundColor(.secondaryLabel).padding(.horizontal).multilineTextAlignment(.center)
    }
    
}
