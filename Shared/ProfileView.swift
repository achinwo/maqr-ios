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

struct UserProfileView2: View {
    
    var user: UserRecord
    @State var editProfilePresented = false
    
    var body: some View {
        let image = UIImage.makeLetterAvatar(withUsername: user.name)!
        
        return VStack(alignment: .center) {
            
            ImageView(uiImage: image) { (img: UIImage?, error: Error?) in
                print("image: \(img), error: \(error)")
            }.padding()
            
            Text(user.name!).font(.headline)
            Text(user.ranking.description.lowercased())
                .font(.footnote)
                .foregroundColor(.gray)
            Divider()
            Spacer()
        }
        .sheet(isPresented: self.$editProfilePresented) {
            print("thing is dismissed!")
        } content: {
            NavigationView(){
                ProfileEditView(user: user)
            }.navigationBarTitle(Strings.photoUpload.rawValue)
        }
        .onTapGesture {
            self.editProfilePresented.toggle()
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
}

struct UserProfileView2_Previews: PreviewProvider {
    
    static var previews: some View {
        let user = SEED_DATA.users.first!
        
        return NavigationView(){
            UserProfileView2(user: user.builder())
        }.navigationTitle(user.name)
    }
    
}
