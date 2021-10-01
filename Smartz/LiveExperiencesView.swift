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
import QRCode

public struct LiveExperiencesView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Binding public var experiences: [StikrExperienceData]
    @Binding public var selectedExperienceUuid: String?
    public var onSelect: (StikrExperienceData) -> Void
    
    private func makeQrCode(_ data: StikrExperienceData) -> UIImage? {

        guard let vizCode = data.visualcodes?.last,
              let url = URL(string: vizCode.url),
              let img = try? QRCode(url: url, color: UIColor(hex: "#29304B"), backgroundColor: UIColor(hex: "#E1E5EE"), size: CGSize(width: screenWidth - 100, height: screenWidth - 100))?.image() else {
            return nil
        }
        return img
    }
    
    private func experienceView(_ exp: StikrExperienceData) -> some View {
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
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                HStack(){
                    Spacer()
                    if let img = self.makeQrCode(exp) {
                        
                        Button(){
                            let preview: AppPreview = .view2(){
                                NavigationView(){
                                    ScrollView(){
                                        VStack(){
                                            Image(uiImage: img).padding()
                                            if let txt = exp.landingPageText {
                                                Text(txt).multilineTextAlignment(.center)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(10)
                                                    .font(.body.weight(.light))
                                                    .padding()
                                            }
                                            Spacer()
                                        }
                                    }
                                    .navigationTitle(exp.brandName)
                                }
                                .frame(width: screenWidth)
                                .eraseToAnyView()
                            }
                            
                            appCoordinator.globalModalSubject.send(preview)
                        } label: {
                            Label("View Code", systemImage: "qrcode").padding([.horizontal, .bottom]).padding(.top, 2)
                        }
                    }
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
    
    public var contentView: some View {
        VStack(){
            let headerMyExperiences = HStack(alignment: .center){
                Image(systemName: "bookmark")
                    .font(Font.title.weight(.thin))
                VStack(alignment: .leading){
                    Text("Live Experiences").font(.title)
                    Text("Your active brand experiences.").font(.caption) + Text("Pull down to refresh.").font(.caption.weight(.semibold))
                }
                Spacer()
            }
            .foregroundColor(.secondary)
            .font(Font.largeTitle.weight(.thin))
            .padding()
            
            Section(header: headerMyExperiences) {
                ForEach(experiences){ exp in
                    self.experienceView(exp)
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
