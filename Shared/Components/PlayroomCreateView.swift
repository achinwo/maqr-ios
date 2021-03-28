//
//  PlayroomCreateView.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/03/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

public struct PlayroomCreateView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var name: String = ""
    @State var description: String = ""
    @State var themeTrackUri: String? = nil
    
    @State var selectedTrack: Playable? = nil
    
    public var contentView: some View {
        NavigationView(){
            ScrollViewReader() { scrollProxy in
                ScrollView(){
                    VStack(alignment: .leading, spacing: .zero){
                        
//                        HStack(alignment: .top){
//                            VStack(alignment: .leading) {
//                                Text("Autoplay")
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
//
//                                Text("Begin playback immediately when joining a playroom")
//                                    .font(.footnote)
//                                    .foregroundColor(Color.secondary)
//                            }
//                            .frame(maxWidth: screenWidth / 2)
//
//                            Spacer()
//
//                            Toggle("Autoplay", isOn: .constant(false))
//                                .labelsHidden()
//                                .padding()
//                        }
//                        .padding(.top)
                        
                        
                        VStack(alignment: .leading, spacing: .zero){
                            
                            Divider()
                            
                            VStack(alignment: .leading){
                                Label("Joli is in Beta", systemImage: "info.circle").font(Font.headline.weight(.semibold))
                                Text("All Playrooms will be public access by default").lineLimit(4)
                            }
                            .padding()
                            
                            Divider()
                        }
                        .background(Color.yellow.opacity(0.6))
                        .foregroundColor(Color.secondary)
                        
                        
                        let themeSongHeader = Text("Theme Song")
                            .foregroundColor(.secondary)
                            .font(Font.title.weight(.thin))
                        
                        Section(header: themeSongHeader){
                            
                            let button = Button() {
                                logger.debug("[RoomCreate] choosing a theme track")
                                
                                appCoordinator.pickTrack() { track in
                                    logger.debug("[RoomCreate] Got a track \(track.title)")
                                    self.selectedTrack = track
                                }
                                
                            } label: {
                                Text(self.selectedTrack == nil ? "Choose" : "Change")
                            }
                            
                            Group(){
                                if let track = self.selectedTrack {
                                    TrackView2(track: .constant(track)) {(track, playStates, colors) in
                                        HStack(){
                                            Divider()
                                            button
                                        }
                                        .eraseToAnyView()
                                    }
                                } else {
                                    HStack(alignment: .center){
                                        
                                        VStack(alignment: .leading) {
                                            Text("Pick a song")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("A good theme song communicates the vibe of the room to joiners")
                                                .lineLimit(3)
                                                .font(.footnote)
                                                .foregroundColor(Color.secondary)
                                        }
                                        Spacer()
                                        Divider()
                                        button
                                    }
                                }
                                
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        
                        let descriptionHeader = Text("Description")
                            .foregroundColor(.secondary)
                            .font(Font.title.weight(.thin))
                        
                        Section(header: descriptionHeader){
                            VStack(alignment: .leading){
                                Text("Name")
                                    .font(.headline)
                                TextField("What would you like to call it?", text: self.$name) { (isEditing) in
                                    
                                } onCommit: {
                                    logger.debug("[RoomCreate] committed")
                                }
                                .padding(.bottom)
                                
                                Text("Description")
                                    .font(.headline)
                                TextEditor(text: self.$description)
                                    .frame(height: screenHeight * 0.1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Colors.lightGray, lineWidth: 1)
//                                            .stroke(LinearGradient(gradient: Gradient(colors: [.green, .blue]),
//                                                                   startPoint: .topLeading,
//                                                                   endPoint: .bottomTrailing), lineWidth: 1)
                                    )
//                                    .border(LinearGradient(gradient: Gradient(colors: [.green, .blue]),
//                                                           startPoint: .topLeading,
//                                                           endPoint: .bottomTrailing),
//                                            width: 1)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        
//                        let inviteHeader = Text("Invite Participants (Optional)")
//                            .foregroundColor(.secondary)
//                            .font(Font.title.weight(.thin))
//
//                        Section(header: inviteHeader) {
//                            Text("room")
//                        }
//                        .padding()
                        
                        HStack(){
                            Spacer()
                            
                            let disabled: Bool = (
                                self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || self.selectedTrack == nil
                                    || self.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || self.creatingPlayroom
                            )
                            
                            Button(){
                                self.createMusicroom()
                            } label: {
                                HStack(){
                                    
                                    Text("Create Playroom")
                                        .fontWeight(.semibold)
                                        .font(.headline)
                                        .foregroundColor(disabled ? Color.gray : Color.purple)
                                        .padding()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 36)
                                                .stroke(disabled ? Color.gray : Color.purple, lineWidth: 2)
                                        )
                                    
                                    if self.creatingPlayroom {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(disabled)
                            Spacer()
                        }
                        .padding(.top, Sizing.medium)
                    }
                }
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle("Making a Playroom", displayMode: .automatic)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded(){
                            appCoordinator.dismissKeyboard()
                        }
                )
            }
        }
        
        
    }
    
    
    @State var creatingPlayroom: Bool = false
    
    private func createMusicroom() {
        print("Creating playroom...")
        
        let props: [MusicroomRecord.PersistedType.CodingKeys: AnyObject] = [
            .details: self.description.trimmingCharacters(in: .whitespacesAndNewlines) as AnyObject,
            .name: self.name.trimmingCharacters(in: .whitespacesAndNewlines) as AnyObject,
            .membership: Membership.membershipOpen.rawValue as AnyObject,
            .themeTrackUri: selectedTrack?.uri as AnyObject
        ]
        
        self.creatingPlayroom = true
        MusicroomRecord(properties: props)
            .save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .main)
            .then() { room in
                logger.debug("[PlayroomCreate] created: \(room)")
            }
            .catch(self.appCoordinator.globalErrorHandler())
            .always {
                self.creatingPlayroom = false
            }
    }
}


struct PlayroomCreateView_Previews: PreviewProvider {
    static var previews: some View {
        PlayroomCreateView()
    }
}
