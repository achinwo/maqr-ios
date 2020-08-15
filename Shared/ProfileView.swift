//
//  ProfileView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi

struct ProfileEditView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    var user: UserRecord
    
    var body: some View {
        return VStack() {
            Text("Hello \(user.name!)")
        }.onTapGesture {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

public struct UserProfileView2: View {
    
    var user: UserRecord
    @State var editProfilePresented = false
    @State var logoutPresented = false
    var callback: (() -> Void)?
    
    public init(user: UserRecord, callback: (() -> Void)? = nil){
        self.callback = callback
        self.user = user
    }
    
    var logoutAlertView: Alert {
        let send = ActionSheet.Button.destructive(Text("Logout")) {
            print("hit send")
        }

        // If the cancel label is omitted, the default "Cancel" text will be shown
        let cancel = ActionSheet.Button.cancel(Text("Cancel")) {
            print("hit abort")
        }
        
        return Alert(title: Text(Strings.reallyLogoutTitle),
                     message: Text(Strings.reallyLogoutMessage),
                     primaryButton: send,
                     secondaryButton: cancel)
    }
    
    var formView: some View {
        let image = UIImage.makeLetterAvatar(withUsername: user.name)!
        
        return Form() {
            ImageView(uiImage: image) { (img: UIImage?, error: Error?) in
                print("image: \(img), error: \(error)")
            }
            .padding()
            
            VStack(alignment: .leading){
                Text(user.name!).font(.headline)
                Text(user.ranking.description.lowercased())
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("Music Provider")) {
                Text("Spotify")
            }
            
            Section(header: Text("Password Reset")){
                Text("Change Password")
            }
            
            Section(header: HStack(){ Text("Trivia Areas"); Spacer(); Text("Set Defaults") }){
                VStack(){
                    
                    
                    HStack(){
                        Spacer()
                        
                    }
                }
            }
            
            HStack(alignment: .center) {
                Spacer()
                Button("LOG OUT") {
                    print("logout!")
                    self.logoutPresented.toggle()
                }
                //.fontWeight(.semibold)
                .padding(.all, Sizing.medium)
                .buttonStyle(BlackWhiteButtonStyle(white: Colors.lightGray))
                .alert(isPresented: self.$logoutPresented) {
                    self.logoutAlertView
                }
                Spacer()
            }
            //.edgesIgnoringSafeArea(.all)
            .frame(minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
            )
            //.background(Color(named: .lightGray))
            
        }
    }
    
    public var body: some View {
        let view = self.formView
//        .sheet(isPresented: self.$editProfilePresented) {
//            print("thing is dismissed!")
//        } content: {
//            NavigationView(){
//                ProfileEditView(user: user)
//            }.navigationBarTitle(Strings.photoUpload.rawValue)
//        }
//        .onTapGesture {
//            self.editProfilePresented.toggle()
//        }
            .background(Color.clear)
        .clipped()
            .edgesIgnoringSafeArea(.bottom)
        
        return view
    }
    
}

struct UserProfileView2_Previews: PreviewProvider {
    
    static var previews: some View {
        let user = SEED_DATA.users.first!
        
        return NavigationView(){
            UserProfileView2(user: user.builder()).offset(x: 0, y: 1)
        }
        .navigationBarItems(leading: Text("Save Changes"))
    }
    
}
