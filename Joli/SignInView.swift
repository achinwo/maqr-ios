//
//  SignInView.swift
//  Joli
//
//  Created by Anthony Chinwo on 09/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

struct SignUpView: View {
    
    @Environment(\.presentationMode) var presentation
    @State var newUser: User
     
    var body: some View {
        Form {
            Section(header: Text("Personal information")) {
                TextField("type something...", text: $newUser.name)
            }

            Section {
                Button("Save") {
                    self.presentation.wrappedValue.dismiss()
                }
            }
        }.navigationBarTitle(Text(newUser.name))
    }
    
}

struct SignInView: View {
    
    
    var body: some View {
        Text("Sign In...")
    }
    
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
    }
}
