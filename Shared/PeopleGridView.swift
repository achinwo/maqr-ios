//
//  PeopleGridView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import LetterAvatarKit

struct PeopleGridView: View {
    
    let rows = [
        GridItem(.fixed(100)),
    ]
    
    @Binding var isExpanded: Bool
    @State var users: [User]
    
    public init(_ users: [User], isExpanded: Binding<Bool>? = nil){
        self._users = State(initialValue: users)
        self._isExpanded = isExpanded ?? .constant(true)
    }
    
    var stickyHeaderView: some View {
        RoundedRectangle(cornerRadius: 25.0, style: .continuous)
            .fill(Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .overlay(
                Text("Section")
                    .foregroundColor(Color.white)
                    .font(.largeTitle)
            )
    }
    
    var body: some View {
        var label = ""
        
        if !(self.isExpanded || users.isEmpty) {
            label = "\(label)\(users.count)" //•
        }
        
        return DisclosureGroup(isExpanded: self._isExpanded) {
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, alignment: .center, pinnedViews: [.sectionHeaders]) {
                    
                    Image(systemName: "plus.circle")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                    
                    ForEach(users, id: \.self) { user in
                        Image(uiImage: UIImage.makeLetterAvatar(withUsername: user.name)!)
                            .resizable()
                            .renderingMode(.original)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .overlay(
                                Group() {
                                    if user.id == 3 {
                                        Text("invited")
                                            .padding([.leading, .trailing], 3)
                                            .foregroundColor(.white)
                                            .background(Color.gray)
                                            .font(.footnote)
                                            .clipShape(Capsule())
                                    } else {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                .offset(x: 18, y: 18)
                            )
                    }
                }
            }
            .padding()
        } label: {
            HStack(){
                Image(systemName: "person.2.fill").font(.title2)
                Text(label)
                Spacer()
            }
            .padding()
            .frame(minWidth: screenWidth / 2)
            .background(Color.gray.opacity(0.001))
            .onTapGesture(){
                withAnimation(){
                    self.isExpanded.toggle()
                }
            }
        }
        .padding(.trailing, Sizing.medium)
    }
    
}

struct PeopleGridView_Previews: PreviewProvider {
    
    @State static var isExpanded = true
    
    static var previews: some View {
        let users = SEED_DATA.users
        return VStack() {
            PeopleGridView(users, isExpanded: Self.$isExpanded).padding()
            Spacer()
        }
    }
}
