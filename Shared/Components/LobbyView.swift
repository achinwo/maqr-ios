//
//  LobbyView.swift
//  Joli
//
//  Created by Anthony Chinwo on 05/11/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi
import Promises
import UIKit
import MessageUI
import AVFoundation

public struct MailView: UIViewControllerRepresentable {
    
    public struct Options: Equatable {
        public let subject: String
        public let recipients: [String]
        public var body: String? = nil
    }
    
    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    var subject: String? = nil
    var recipients = [String]()
    var body: String? = nil
    
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
    
    public class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        
        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?
        
        init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>){
            _presentation = presentation
            _result = result
        }
        
        public func mailComposeController(_: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?){
            defer {
                $presentation.wrappedValue.dismiss()
            }
            
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            
            self.result = .success(result)
            
            if result == .sent {
                AudioServicesPlayAlertSound(SystemSoundID(1001))
            }
        }
        
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation,
                           result: $result)
    }
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.mailComposeDelegate = context.coordinator
        
        if let subject = subject {
            vc.setSubject(subject)
        }
        
        if let body = body {
            vc.setMessageBody(body, isHTML: true)
        }
        
        return vc
    }
    
    public func updateUIViewController(_: MFMailComposeViewController,
                                context _: UIViewControllerRepresentableContext<MailView>) {}
}

public struct LobbyView: JoliView {
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @Binding var recentTracks: [Playable]
    @Binding var liveTracks: [Playable]
    @Binding var playrooms: [Musicroom]
    @Binding var filterText: String
    @Binding var isLoading: Bool
    @Binding var preview: AppPreview?
    
    let onPlayroomSelected: ((Musicroom) -> Void)?
    
    @SceneStorage("refreshTokenSpotify") var refreshTokenSpotify: String = .empty
    @State var bannerDisplayedAt: Date? = nil
    
    @State var auths: [Auth] = []
    @State var activeSessionId: String? = nil
    
    public var tracksView: some View {
        
        var desc: String
        
        if self.liveTracks.isEmpty {
            desc = "Popular songs recently played"
        } else {
            desc = "See whats trending live — tap album art to follow along"
        }
        
        let header = HStack(){
            let headerText = "\(!self.liveTracks.isEmpty ? "Live" : "Recent") Tracks"
            VStack(alignment: .leading){
                Text(headerText)
                    .font(Font.largeTitle.weight(.thin))
                    .foregroundColor(.secondary)
                Text(desc)
                    .lineLimit(2)
                    .font(Font.subheadline.weight(.light))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.bottom, Sizing.small)
        
        let tracks: [Playable] = !self.liveTracks.isEmpty ? self.liveTracks : self.recentTracks
        
        return Section(header: header) {
            ForEach(tracks, id: \.uri) { (track: Playable) in
                let playlistUri = (track as? PlayState)?.roomId != nil ? (track as? PlayState)?.playlistUri : nil
                TrackView2(track: .constant(track), contextUri: .constant(playlistUri), useDynamicColors: false) { (track, playStates, colors) in
                        VStack() {
//                                        Button() {
//                                            //appCoordinator.
//                                        } label: {
//                                            Text("𖧊 Follow").font(Font.subhealine)
//                                        }
//                                        //.padding(.all, 3)
//                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray))
//                                        .disabled(true)
                        }
                    }
                    .frame(height: 64)
                    .id(track.uri)
            }
        }
    }
    
    @Namespace var localNamespace
    
    public var contentView: some View {
        VStack(alignment: .center){
            
            Divider()
                .opacity(self.isLoading ? 1 : 0)
            
            Group(){
                if self.auths.isEmpty && self.bannerDisplayedAt != nil {
                    SpotifyConnectButton()
                    .padding()
                }
            }
            .animation(.easeInOut)
            
            if !(self.liveTracks.isEmpty && self.recentTracks.isEmpty) {
                self.tracksView
            }
            
            if !self.playrooms.isEmpty {
                let header = VStack(alignment: .leading) {
                        
                        HStack(alignment: .top){
                            Text("Playrooms")
                            Spacer()
                            Button() {
                                print("[LobbyView] made")
                                
                                self.preview = .playroomCreate
                                //self.appCoordinator.globalModalSubject.send(.playroomCreate)
                            } label: {
                                Image(systemName: "plus").font(Font.title.weight(.thin))
                            }
                        }
                        .font(Font.largeTitle.weight(.thin))
                        .foregroundColor(.secondary)
                    
                        Text("Listen together and vote up your favorite tracks")
                            .lineLimit(2)
                            .font(Font.subheadline.weight(.light))
                            .foregroundColor(.primary)
                }
                .padding(.bottom, Sizing.small)
                
                let columns = [
                    //GridItem(.fixed(proxy.size.width / 2 - space), spacing: space),
                    //GridItem(.fixed(proxy.size.width / 2 - space), spacing: space)
                    GridItem(),
                    GridItem()
                ]
                
                Section(header: header) {
                    LazyVGrid(columns: columns) {
                        ForEach(self.playrooms, id: \.id) { room in
                            SpotifyItemView(item: room,
                                            images: room.images,
                                            titleKeyPath: \.name,
                                            subtitleKeyPath: \.details)
                                .frame(height: 64)
                                .onTapGesture {
                                    self.onPlayroomSelected?(room)
                                }
                                .matchedGeometryEffect(id: "playroom/\(room.id.description)", in: appCoordinator.namespace ?? localNamespace)
                                //.background(Color.yellow)
                                .id(room.id)
                        }
                    }
                }
                
            }
            
            //                                Group(){
            //                                    Color.white
            //                                }
            //                                .frame(width: screenWidth, height: screenWidth)
            
            Divider().padding(.vertical, Sizing.xxLarge)
            
            let header = HStack(){
                Label(){
                    Text("Settings")
                } icon: {
                    Image(systemName: "gearshape")
                        .font(Font.title.weight(.thin))
                }
                .foregroundColor(.secondary)
                .font(Font.largeTitle.weight(.thin))
                
                Spacer()
            }
            
            Section(header: header) {
                HStack(alignment: .top){
                    VStack(alignment: .leading) {
                        Text("Autoplay")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Begin playback immediately when joining a playroom")
                            .font(.footnote)
                            .foregroundColor(Color.secondary)
                    }
                    .frame(maxWidth: screenWidth / 2)
                    
                    Spacer()
                    
                    Toggle("Autoplay", isOn: .constant(false))
                        .labelsHidden()
                        .padding()
                }
                .padding(.top)
                
                HStack(alignment: .center){
                    VStack(alignment: .leading) {
                        Text("Feedback")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("General enquires, report issues or just let us know what you think")
                            .font(.footnote)
                            .foregroundColor(Color.secondary)
                    }
                    .frame(maxWidth: screenWidth / 2)
                    
                    Spacer()
                    
                    Button(){
                        let subject = "Joli iOS App Feedback - \(AppCoordinator.version)"
                        self.appCoordinator.mailOptions = .init(subject: subject, recipients: [Strings.appSupportEmail])
                    } label: {
                        Text("Submit").foregroundColor(.systemIndigo)
                    }
                    .padding()
                }
                .padding(.top)
                
                VStack(alignment: .leading){
                    HStack(){
                        Text("Active Sessions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Button() {
                            self.appCoordinator.spotifyAuthRequestedAt = Date()
                        } label: {
                            Image(systemName: "plus")
                                .font(Font.title2)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    
                    if self.auths.isEmpty {
                        SpotifyConnectButton().padding()
                    }
                    
                    ForEach(self.auths, id: \.session.token) { auth in
                        HStack() {
                            
                            let color = self.activeSessionId == auth.session.token ? Color.systemGreen : Color.systemGray
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(auth.user.name).font(.headline).foregroundColor(color)
                                Text(auth.user.ranking.description.lowercased()).font(.footnote).foregroundColor(Color.systemGray)
                            }
                            Spacer()
                            
                            VStack(alignment: .center){
                                if signingOut == auth {
                                    ProgressView()
                                } else {
                                    Button(){
                                        let action = {
                                            self.signingOut = auth

                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                self.appCoordinator.signoutSubject.send(auth)
                                                self.signingOut = nil

                                                self.auths = self.auths.filter({ $0.session.token != auth.session.token })
                                            }
                                        }
                                        appCoordinator.withAlert(Strings.reallyLogoutTitle,
                                                              message: Strings.reallyLogoutMessage,
                                                              label: "Sign Out",
                                                              action: action)
                                    } label: {
                                        Text("Sign Out")
                                    }
                                }
                            }
                            .foregroundColor(.gray)
                            .padding()
                        }
                        .padding([.top, .horizontal])
                        .id(auth.session.token)
                    }
                }
                .padding(.bottom, 120)
                .padding(.top)
                .onReceive(self.appCoordinator.authsSubject) { auths in
                    self.auths = auths
                }
                
            }
            .id("settings")
            
        }
        .padding()
        .onReceive(appCoordinator.authSubject) { auth in
            self.refreshTokenSpotify = auth?.user.refreshTokenSpotify ?? .empty
        }
        .onReceive(appCoordinator.$activeSessionToken) { activeSessionId in
            self.activeSessionId = activeSessionId
        }
        .onAppear() {
            
            guard bannerDisplayedAt == nil else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                self.bannerDisplayedAt = Date()
            }
        }
    }
    
    @State var signingOut: Auth? = nil
    
}

public extension Musicroom {
    
    var images: [Spotify.Image] {
        return [self.imageLarge, self.imageSmall, self.imageMedium].compactMap() { url in
            guard let url = url else { return nil }
            
            return Spotify.Image(url: url)
        }
    }
    
}

//struct LobbyView_Previews: PreviewProvider {
//    static var previews: some View {
//        LobbyView()
//    }
//}
