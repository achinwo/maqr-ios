//
//  SwiftUIView.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//
import UIKit
import SwiftUI
import JoliCore

struct AppPreviewView: View {
    
    @Binding var preview: AppPreview?
    var animation: Namespace.ID
    
    var body: some View {
        ZStack(){
            
            VStack(spacing: .zero){
                Divider()
                Spacer(minLength: .zero)
                
                if let preview = self.preview {
                    switch preview {
                        case .userProfile(let user):
                            UserProfileView2(user: user)
                                .background(Color.clear)
                        case .view(let scrollAxis, let viewFunc):
                            ScrollView(scrollAxis ?? .vertical){
                                viewFunc().clipped()
                            }
                    }
                } else {
                    Text("No Preview.")
                }
                Spacer(minLength: .zero)
                Divider()
            }
            
            let largeTitleSize = UIFont.preferredFont(forTextStyle: .title1).pointSize
            VStack(alignment: .trailing){
                HStack(){
                    Spacer()
                    Image(systemName: "xmark")
                        .font(Font.title.weight(.light))
                        .foregroundColor(.gray)
                        .opacity(0.9)
                        .background(Circle()
                                        .frame(width: largeTitleSize * 1.4, height: largeTitleSize * 1.6)
                                        .foregroundColor(Colors.lightGray.opacity(0.8)))
                        
                        .padding([.top, .trailing], Sizing.medium)
                }
                .padding()
                .onTapGesture() {
                    self.preview = nil
                }
                //.frame(maxWidth: Sizing.large, maxHeight: Sizing.large)
                Spacer()
            }
        }
        
    }
}

struct Preview_Previews: PreviewProvider {
    
    struct SampleView: View {
        @Namespace var namespace
        @State var preview: AppPreview? = .userProfile(SEED_DATA.users.first!.builder())
        
        var body: some View {
            return AppPreviewView(preview: self.$preview, animation: namespace)
        }
    }
    
    
    static var previews: some View {
        SampleView()
    }
}
