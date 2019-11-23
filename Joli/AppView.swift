//
//  AppView.swift
//  Joli
//
//  Created by Anthony Chinwo on 11/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

typealias Size = ()

struct ViewOffset {
    
    var x: CGFloat?
    var y: CGFloat?
    
    func computedSize(geometry: GeometryProxy) -> CGSize {
        return CGSize(width: x ?? geometry.size.width, height: y ?? geometry.size.height)
    }
    
}

extension DbModel {
    var view: some View {
        GeometryReader(){ geometry in
            self.makeView(geometry)
        }
    }
    
    func makeView(_ geom: GeometryProxy) -> some View {
        return Text("View: \(Self.className())")
    }
}

struct DbModelView<T: DbModel>: View {
    
    var item: T
    
    init(of: T){
        item = of
    }
    
    var body: some View {
        self.item.view
    }
    
}

extension Track {
    
    func makeView(_ geom: GeometryProxy) -> some View {
        return TrackView(track: self)
    }
    
}

struct AppView: View {
    @EnvironmentObject var appState: AppState
    
    @State var settingsViewOffset: ViewOffset = ViewOffset(x: nil, y: 0)
    @State var settingsViewOffsetSize = CGSize(width: 0, height: 0)
    @State var mainViewOffset = CGSize(width: 0, height: 0)
    @State var activityIdx = 0
    
    
    
    var body: some View {
        
        GeometryReader(){ geometry in
            ZStack(alignment: .bottomTrailing) {
                
                NavigationView {
                    VStack(alignment: .leading) {
                        Picker(selection: self.$activityIdx, label: Text("Select Activity")) {
                            ForEach(0...1, id: \.self) { i in
                                Text(["Sign In", "Sign Up"][i]).tag(i).font(.largeTitle)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Text("Sign In/Sign Up")
                    }.navigationBarTitle("Account", displayMode: .large)
                        .background(Color.blue)
                }
                .edgesIgnoringSafeArea(.bottom)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                
                NavigationView {
                    MusicroomList()
                        .navigationBarItems(leading:
                            Button(action: {
                                if self.mainViewOffset.height == 0 {
                                    self.mainViewOffset = CGSize(width: 0, height: geometry.size.height)
                                    
                                }else{
                                    self.mainViewOffset = CGSize(width: 0, height: 0)
                                    
                                }
                            })  {
                                Image(systemName: "xmark")
                                Text("Sign In")
                            }, trailing:
                            Button(action: {
                                if self.settingsViewOffset.x == geometry.size.width {
                                    self.settingsViewOffset = ViewOffset(x: geometry.size.width, y: 0)
                                }else{
                                    self.settingsViewOffset = ViewOffset(x: nil, y: 0)
                                    
                                }
                                self.settingsViewOffsetSize = self.settingsViewOffset.computedSize(geometry: geometry)
                                
                            })  {
                                Image(systemName: "gear")
                                    .onTapGesture {
                                        print("Settings tapped")
                                }.padding()
                            }
//                        , trailing:
//                        Button(action: { self.appState.sceneDelegate.connect() })  {
//                            Text("Spotify")
//                        }
                    )
                }
                .animation(.linear(duration: 0.3))
                .offset(self.mainViewOffset)
                
                VStack {
                    Button(action: {
                        if self.settingsViewOffset.x == nil {
                            self.settingsViewOffset = ViewOffset(x: geometry.size.width, y: 0)
                        }else{
                            self.settingsViewOffset = ViewOffset(x: nil, y: 0)

                        }
                        self.settingsViewOffsetSize = self.settingsViewOffset.computedSize(geometry: geometry)
                    })  {
                        Image(systemName: "xmark")
                        Text("Close")
                    }.padding()
                    VStack {

                        Text("Home").background(Color.red)
                    }//.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topTrailing)
                //.frame(width: 800, height: 1600, alignment: .center)
                   // .blur(radius: 80)
                .background(Color.yellow)
                    .animation(.easeInOut(duration: 0.25))
                    .offset(self.settingsViewOffsetSize)
                
            }
            
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
