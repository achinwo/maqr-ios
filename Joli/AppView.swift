//
//  AppView.swift
//  Joli
//
//  Created by Anthony Chinwo on 11/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI


struct AppView: View {
    @EnvironmentObject var appState: AppState
    @State var settingsViewOffset = CGSize(width: 0, height: 0)
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
                    .navigationBarItems(trailing:
                        Button(action: {
                            if self.settingsViewOffset.width == 0 {
                                self.settingsViewOffset = CGSize(width: geometry.size.width, height: 0)

                            }else{
                                self.settingsViewOffset = CGSize(width: 0, height: 0)

                            }
                        })  {
                            Image(systemName: "xmark")
                            Text("Settings")
                        }
                    )
                    .navigationBarItems(leading:
                        Button(action: {
                            if self.mainViewOffset.height == 0 {
                                self.mainViewOffset = CGSize(width: 0, height: geometry.size.height)

                            }else{
                                self.mainViewOffset = CGSize(width: 0, height: 0)

                            }
                        })  {
                            Image(systemName: "close")
                            Text("Sign In")
                        }
                    )
                }
                .animation(.linear(duration: 0.3))
                .offset(self.mainViewOffset)
                
                VStack {
                    Button(action: {
                        if self.settingsViewOffset.width == 0 {
                            self.settingsViewOffset = CGSize(width: geometry.size.width, height: 0)

                        }else{
                            self.settingsViewOffset = CGSize(width: 0, height: 0)

                        }
                    })  {
                        Image(systemName: "close")
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
                    .offset(self.settingsViewOffset)
                
            }
            
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
