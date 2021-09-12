//
//  MyExperiencesView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 08/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

public struct MyExperiencesView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Binding public var experiences: [StikrExperienceData]
    @Binding public var selectedExperienceUuid: String?
    public var onSelect: (StikrExperienceData) -> Void
    
    public var contentView: some View {
        VStack(){
            let headerMyExperiences = HStack(){
                Label(){
                    Text("My Experiences")
                } icon: {
                    Image(systemName: "infinity")
                        .font(Font.title.weight(.thin))
                }
                .foregroundColor(.secondary)
                .font(Font.largeTitle.weight(.thin))
                
                Spacer()
            }
            .padding()
            
            Section(header: headerMyExperiences) {
                ForEach(experiences){ exp in
                    HStack(){
                        NetworkImage(string: exp.logoImageUrl){
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64, alignment: .center)
                        .padding()
                        
                        VStack(alignment: .leading){
                            
                            Text(exp.brandName).font(.headline)
                            
                            if let txt = exp.landingPageText {
                                Text(txt)
                                    .lineLimit(3)
                                    .truncationMode(.tail)
                            }
                        }
                        Spacer()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(exp.uuid == self.selectedExperienceUuid ? 0.6 : 0), lineWidth: 1)
                    )
                    .onTapGesture() {
                        self.onSelect(exp)
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }

}

//struct MyExperiencesView_Previews: PreviewProvider {
//    static var previews: some View {
//        MyExperiencesView()
//    }
//}
