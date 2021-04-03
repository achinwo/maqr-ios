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

public enum AppPreview: View, Equatable {
    
    public static func == (lhs: AppPreview, rhs: AppPreview) -> Bool {
        switch (lhs, rhs) {
        case (.userAccount, .userAccount):
            return true
        default:
            return false
        }
    }
    
    public var body: some View {
        switch self {
            case .userProfile(let user):
                UserProfileView2(user: .constant(user))
                    .background(Color.clear)
                    .id(user.emailAddress.email)
            case .view(let scrollAxis, let viewFunc):
                ScrollView(scrollAxis ?? .vertical){
                    viewFunc().clipped()
                }
            case .track(let track):
                VStack() {
                    NetworkImage(string: track.albumCoverUrl) {
                        Text("\(track.title)")
                    }
                }
            case .playroomCreate:
                PlayroomCreateView()
                    .background(Color.clear)
            default:
                EmptyView()
        }
    }
    
    case userAccount
    case userProfile(UserIdentifiable)
    case track(Track)
    case view(Axis.Set? = nil, () -> AnyView)
    case playroomCreate
}

struct AppPreviewView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Binding var preview: AppPreview?
    @Binding var currentUser: User?
    var animation: Namespace.ID
    
    var contentView: some View {
        ZStack(){
            
            VStack(spacing: .zero){
                Divider()
                Spacer(minLength: .zero)
                
                if let currentUser = currentUser, preview == .userAccount {
                    UserProfileView2(user: .constant(currentUser))
                } else if let preview = self.preview {
                    preview.environmentObject(appCoordinator)
                } else {
                    Text("No Preview.")
                }
                Spacer(minLength: .zero)
                Divider()
            }
            .matchedGeometryEffect(id: "preview", in: animation)
            
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
            return AppPreviewView(preview: self.$preview,
                                  currentUser: .constant(SEED_DATA.users.first),
                                  animation: namespace)
        }
    }
    
    
    static var previews: some View {
        SampleView()
    }
}
