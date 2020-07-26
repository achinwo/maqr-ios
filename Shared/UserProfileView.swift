//
//  UserProfileView.swift
//  Joli
//
//  Created by Anthony Chinwo on 31/12/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi


struct UserProfileView: View {
    var user: UserRecord
    
    var body: some View {
        
        return VStack(alignment: .leading) {
            Text(user.name!).font(.headline)
            Text(user.ranking.description.lowercased()).font(.footnote).foregroundColor(.gray)
        }
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView(user: SEED_DATA.users.first!.builder())
    }
}
