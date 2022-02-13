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
    
    public enum Action {
        case selected
        case launch
        case edit
    }
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Binding public var experiences: [StikrExperienceData]
    @Binding public var selectedExperienceUuid: String?
    public var onSelect: (Action, StikrExperienceData) -> Void
    @Namespace var namespace
    
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
                        appCoordinator.modal.close() {
                            print("Presenting share view!")
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
    
    func experienceImage(_ url: String?) -> some View {
        NetworkImage(string: url){
            ProgressView().progressViewStyle(CircularProgressViewStyle())
        }
        .aspectRatio(contentMode: .fill)
        .id(url)
    }
    
    private func experienceView(_ exp: StikrExperienceData) -> some View {
        HStack(){
            let fifthScreenWidth = screenWidth / 5
            self.experienceImage(exp.logoImageUrl)
                .frame(maxWidth: fifthScreenWidth, alignment: .center)
                .clipped()
                .padding(.trailing)
                .matchedGeometryEffect(id: "\(exp.uuid)-logoImageUrl", in: namespace)
            
            VStack(alignment: .leading){
                
                Text(exp.brandName).font(.headline).padding(.bottom, 2)
                
                if let txt = exp.landingPageText {
                    Text(txt)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .matchedGeometryEffect(id: "\(exp.uuid)-landingPageText", in: namespace)
                }
            }
            Spacer()
            
        }
        //.frame(idealHeight: screenWidth / 6)
        .overlay(self.iconImage(exp)
                    .padding(.trailing)
                    .id("\(exp.uuid)-exp-icon"))
    }
    
    func experienceViewExpanded(_ exp: StikrExperienceData) -> some View {
        
        VStack(alignment: .leading){
            
            let fifthScreenWidth = screenWidth / 5
            let isSelected = exp.uuid == self.selectedExperienceUuid
            
            HStack(){
                self.experienceImage(exp.logoImageUrl)
                    .frame(width: fifthScreenWidth, height: fifthScreenWidth, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 2)
                    .padding()
                    //.padding([.bottom, .trailing])
                    .matchedGeometryEffect(id: "\(exp.uuid)-logoImageUrl", in: namespace)
                Text(exp.brandName).font(.headline)
                Spacer()
                
                
            }
            .backgroundColor(Color.systemGroupedBackground.opacity(isSelected ? 0.6 : 0))
            .background(
                GeometryReader() { proxy in
                    NetworkImage(string: exp.bannerImageUrl) {
                        Color.clear
                    }
                    .allowsHitTesting(false)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                }.clipped()
            )
            .overlay(
                self.iconImage(exp)
                    .padding()
                    .id("\(exp.uuid)-exp-icon")
            )
            
            if let txt = exp.landingPageText {
                Text(txt)
                    .lineLimit(nil)
                    .truncationMode(.tail)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.horizontal, .bottom])
                    .matchedGeometryEffect(id: "\(exp.uuid)-landingPageText", in: namespace)
            }
            
            Spacer()
            
            HStack(){
                Spacer()
                self.editBtn(exp)
                Spacer()
                self.viewCodeBtn(exp)
                Spacer()
                self.launchBtn(exp)
                Spacer()
            }
            .padding()
        }
        .frame(idealHeight: screenHeight * 0.4)
    }
    
    func iconImage(_ exp: StikrExperienceData) -> some View {
        GeometryReader() { proxy in
            if let cls = exp.type {
                VStack(){
                    HStack(alignment: .top){
                        Spacer()
                        Image(systemName: cls.iconName)
                            .font(.headline)
                            .foregroundColor(.secondaryLabel)
                    }
                    Spacer()
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
        }
    }
    
    func viewCodeBtn(_ exp: StikrExperienceData) -> some View {
        Group(){
            if let (img, url) = self.makeQrCode(exp) {
                
                Button(){
                    appCoordinator.modal.present() {
                        return .view2(){
                            prepareCodeModal(exp, img, url)
                                .frame(width: screenWidth)
                                .eraseToAnyView()
                        }
                    }
                } label: {
                    Label("QR Code", systemImage: "qrcode")//.padding([.horizontal, .bottom]).padding(.top, 2)
                }
                .id(url)
                
            }
        }
        .matchedGeometryEffect(id: "\(exp.uuid)-view-btn", in: namespace)
    }
    
    func launchBtn(_ exp: StikrExperienceData) -> some View {
        Button(){
            self.onSelect(.launch, exp)
        } label: {
            Label("Launch", systemImage: "arrow.up.left.and.arrow.down.right")//.padding([.horizontal, .bottom]).padding(.top, 2)
        }
    }
    
    func editBtn(_ exp: StikrExperienceData) -> some View {
        Button(){
            self.onSelect(.edit, exp)
        } label: {
            Label("Edit", systemImage: "pencil")//.padding([.horizontal, .bottom]).padding(.top, 2)
        }
    }
    
    public var contentView: some View {
        ForEach(experiences){ exp in
            let isSelected = exp.uuid == self.selectedExperienceUuid
            ZStack(){
                if let selectedUid = self.selectedExperienceUuid, selectedUid == exp.uuid {
                    self.experienceViewExpanded(exp)
                } else {
                    self.experienceView(exp)
                }
            }
            .onTapGesture() {
                self.onSelect(.selected, exp)
            }
            .id("experience-\(exp.uuid)")
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondaryLabel.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
            )
            //.padding(.vertical, isSelected ? 4 : 0)
        }
        .animation(.easeInOut, value: self.selectedExperienceUuid)
    }
    
}
