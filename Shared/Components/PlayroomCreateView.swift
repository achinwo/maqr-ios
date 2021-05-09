//
//  PlayroomCreateView.swift
//  Joli
//
//  Created by Anthony Chinwo on 27/03/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import Promises

public struct PlayroomView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    let playroom: Playroom
    @Namespace var localNamespace
    
    @State var themeTracks: [Track] = []
    
    public init(room: Playroom){
        self.playroom = room
    }
    
    public var contentView: some View {
        ScrollViewReader() { scrollProxy in
            ScrollView(){
                VStack() {
                    Text(playroom.name)
                        .font(.largeTitle)
                        .matchedGeometryEffect(id: "playroom/\(playroom.musicroom.id)/name",
                                               in: appCoordinator.namespace ?? localNamespace)
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        if let track = themeTracks.first {
                            let themeSongHeader = Text("Theme Song")
                                .foregroundColor(.secondary)
                                .font(Font.title.weight(.thin))
                            
                            Section(header: themeSongHeader){
                                TrackView2<Never>(track: .constant(track), playroom: .constant(playroom), useDynamicColors: false)
                                    .id("playroom/\(playroom.name)/theme/\(track.uri)")
                            }
                            
                            .padding()
                        }
                        
                        let descriptionHeader = Text("Description")
                            .foregroundColor(.secondary)
                            .font(Font.title.weight(.thin))
                        
                        Section(header: descriptionHeader){
                            Text(playroom.details)
                                .lineLimit(10)
                                .font(.subheadline)
                        }
                        .padding()
                    }
                    
                    Spacer()
                    Button() {
                        self.appCoordinator.synchronizePlayroom(playroom.musicroom)
                    } label: {
                        Text("Synchronize Playlist")
                    }
                    .padding()
                    Spacer()
                }
            }
        }
        .onReceive(playroom.$themeTracks, assign: \.themeTracks, target: self)
    }
    
}

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
                        .background(Color.systemYellow.opacity(0.6))
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
                                    .id(track.uri)
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
                                            .stroke(Color.tertiarySystemBackground, lineWidth: 1)
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
                        self.eventView
                            .padding()
                        
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
                                        .foregroundColor(disabled ? Color.systemGray : Color.systemPurple)
                                        .padding()
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 36)
                                                .stroke(disabled ? Color.systemGray : Color.systemPurple, lineWidth: 2)
                                        )
                                    
                                    if self.creatingPlayroom {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(disabled)
                            Spacer()
                        }
                        .padding(.vertical, Sizing.medium)
                    }
                }
                .edgesIgnoringSafeArea(.bottom)
                .if(!isMacOs){ view in
                    #if os(macOS)
                    view
                    #else
                    view
                    .navigationBarTitle("Making a Playroom", displayMode: .automatic)
                    #endif
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded(){
                            appCoordinator.dismissKeyboard()
                        }
                )
            }
        }
        
        
    }
    
    var eventView: some View {
        let themeSongHeader = Text("Event\(eventEnabled ? .empty : " (optional)")")
            .foregroundColor(.secondary)
            .font(Font.title.weight(.thin))
        
        let sectionBody = HStack(alignment: .center){
            VStack(alignment: .leading) {
                Text("Enable event setup")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Is this playroom associated with an event such as birthday or wedding?")
                    .lineLimit(3)
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
            }
            Spacer()
            
            Toggle("Event Enabled", isOn: self.$eventEnabled)
                .labelsHidden()
                .padding()
        }
        
        return Group(){
            if self.eventEnabled {
                DisclosureGroup(isExpanded: self.$eventSectionExpanded){
                    VStack(){
                        sectionBody
                        DatePicker("Starts", selection: $eventStartsAt, displayedComponents: [.hourAndMinute, .date])
                        DatePicker("Ends", selection: $eventEndsAt, displayedComponents: [.hourAndMinute, .date])
                    }
                    .padding(.horizontal)
                } label: {
                    themeSongHeader
                }
            } else {
                Section(header: themeSongHeader){
                    sectionBody
                        .padding(.horizontal)
                }
            }
        }
        .animation(.easeInOut)
        
    }
    
    @State var eventSectionExpanded = true
    @State var eventEnabled: Bool = false
    @State var creatingPlayroom: Bool = false
    @State var eventStartsAt = Date()
    @State var eventEndsAt = Date()
    
    private func createEvent(_ room: Musicroom) -> Promise<Event> {
        
        var event = EventRecord()
        event.endsAt = eventEndsAt
        event.startsAt = eventStartsAt
        event.title = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        event.subtitle = self.description.trimmingCharacters(in: .whitespacesAndNewlines)
        event.roomId = room.id
        
        return event
            .save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .main)
            .catch(self.appCoordinator.globalErrorHandler())
    }
    
    private func createMusicroom() {
        print("Creating playroom...")
        
        let name = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let props: [MusicroomRecord.PersistedType.CodingKeys: AnyObject] = [
            .details: self.description.trimmingCharacters(in: .whitespacesAndNewlines) as AnyObject,
            .name: name as AnyObject,
            .membership: Membership.membershipOpen.rawValue as AnyObject,
            .themeTrackUri: selectedTrack?.uri as AnyObject
        ]
        
        self.creatingPlayroom = true
        MusicroomRecord(properties: props)
            .save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .main)
            .then() { room in
                logger.debug("[PlayroomCreate] created: \(room)")
                
                let onComplete = {
                    presentToast("\(name) created", type: .complete(.green)) { _ in
                        self.appCoordinator.globalPreviewSubject.send(nil)
                    }
                }
                
                guard !eventEnabled else {
                    self.createEvent(room)
                        .then(){ event in
                            onComplete()
                        }
                    return
                }
                
                onComplete()
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
