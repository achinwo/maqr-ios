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

public final class ImageSaver: NSObject {
    
    var completion: ((Error?) -> Void)?
    
    func writeToPhotoAlbum(image: UIImage, completion: ((Error?) -> Void)? = nil) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        self.completion?(error)
    }
    
}

public struct LiveExperiencesView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Binding public var experiences: [StikrExperienceData]
    @Binding public var selectedExperienceUuid: String?
    public var onSelect: (StikrExperienceData) -> Void
    
    private func makeQrCode(_ data: StikrExperienceData) -> (UIImage, URL)? {

        guard let vizCode = data.visualcodes?.last,
              let url = URL(string: vizCode.url),
              let img = try? QRCode(url: url, color: UIColor(hex: "#29304B"), backgroundColor: UIColor(hex: "#E1E5EE"), size: CGSize(width: screenWidth - 100, height: screenWidth - 100))?.image() else {
            return nil
        }
        return (img, url)
    }
    
    @State var isShowingMessages = false
    
    @State var autoResetting = AutoResetSubject<Bool, Never, DispatchQueue>(false, delay: 3, scheduler: DispatchQueue.main)
    @State var savedToPhotos = false
    
    private func prepareCodeModal(_ exp: StikrExperienceData, _ image: UIImage, _ url: URL) -> some View {
        NavigationView(){
            ScrollView(){
                VStack(){
                    
                    Button(){
                        self.autoResetting.send(true)
                        
                        ImageSaver()
                            .writeToPhotoAlbum(image: image) { error in
                                print("saving image: error=\(String(describing: error))")
                            }
                    } label: {
                        Image(uiImage: image)
                            .scaleEffect(savedToPhotos ? 1.2 : 1)
                            .sheet(isPresented: $isShowingMessages) {
                                MessageView("Share Experience", body: url.absoluteString) {
                                    print("Messages closed")
                                }
                                .ignoresSafeArea()
                            }
                            .onReceive(self.autoResetting) { value in
                                self.savedToPhotos = value
                                print("savedToPhotos: \(self.savedToPhotos)")
                            }
                    }
                    .padding([.horizontal, .top])
                    
                    
                    Group(){
                        if savedToPhotos {
                            Text("Saved QR code to Photos!")
                        } else {
                            Text("Tap to save to Photos")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondaryLabel)
                    .padding(.bottom)
                    .animation(.spring(), value: savedToPhotos)
                    
                    if let txt = exp.landingPageText {
                        Text(txt).multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .lineLimit(10)
                            .font(.body.weight(.light))
                            .padding()
                    }
                    
                    Button(){
                        isShowingMessages = true
                    } label: {
                        HStack(){
                            Spacer()
                            Label("Share via Messages", systemImage: "message.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .backgroundColor(.blue)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    ))
                    .frame(width: screenWidth - 100, height: 60)
                    .buttonStyle(OutlineButton())
                    
                    Spacer()
                }
            }
            .navigationTitle(exp.brandName)
            .toolbar(id: "experience-actions-\(exp.uuid)") {
                ToolbarItem(id: "share-experience-\(exp.uuid)", placement: .navigationBarLeading, showsByDefault: true){
                    Button(){
                        appCoordinator.globalModalSubject.send(nil)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7){
                            appCoordinator.share(text: "Here's an interactive experience for you! \(url.absoluteString)", url: url){ sent in
                                print("shared \(exp.uuid): \(sent)")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                }
            }
        }
        //.id(savedToPhotos)
    }
    
    private func experienceView(_ exp: StikrExperienceData) -> some View {
        
        return HStack(){
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
                    if let (img, url) = self.makeQrCode(exp) {
                        
                        Button(){
                            let preview: AppPreview = .view2(){
                                prepareCodeModal(exp, img, url)
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
//                Image(systemName: "bookmark")
//                    .font(Font.title.weight(.thin))
                VStack(alignment: .leading){
                    Text("Live Experiences").font(.title)
                    Text("Your active brand experiences.").font(.caption) + Text(" Pull down to refresh.").font(.caption.weight(.semibold))
                }
                Spacer()
            }
            .foregroundColor(.secondary)
            .font(Font.largeTitle.weight(.thin))
            .padding()
            
            Section(header: headerMyExperiences) {
                ForEach(experiences){ exp in
                    self.experienceView(exp)
                        .id("experience-\(exp.uuid)")
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
