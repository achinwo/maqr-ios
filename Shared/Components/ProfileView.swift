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

#if !os(macOS)
import UIKit
#else
import AppKit
#endif

import Promises

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

public extension UIImage {
    
  func resizeImage(_ targetSize: CGSize) -> UIImage {
    let size = self.size
    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    let newSize = widthRatio > heightRatio ?  CGSize(width: size.width * heightRatio, height: size.height * heightRatio) : CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
    let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
    
    #if os(macOS)
    return self
    #else
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    self.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage!
    #endif
  }
    
}

public struct UserProfileView2: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @Binding var user: UserIdentifiable
    @State var editProfilePresented = false
    @State var logoutPresented = false
    
    var userName: String {
        return user.displayName.name ?? "Anonymous"
    }
    
    var callback: (() -> Void)?
    
    public init(user: Binding<UserIdentifiable>, callback: (() -> Void)? = nil){
        self.callback = callback
        self._user = user
    }
    
    var logoutAlertView: Alert {
        let send = Alert.Button.destructive(Text("Logout")) {
            print("hit send")
        }

        // If the cancel label is omitted, the default "Cancel" text will be shown
        let cancel = Alert.Button.cancel(Text("Cancel")) {
            print("hit abort")
        }
        
        return Alert(title: Text(Strings.reallyLogoutTitle),
                     message: Text(Strings.reallyLogoutMessage),
                     primaryButton: send,
                     secondaryButton: cancel)
    }
    
    @State var isUploadingImage = false
    
    var formView: some View {
        
        let imageCallback = { (img: UIImage?, imgName: String?, error: Error?) in
            print("image: \(String(describing: img)), error: \(String(describing: error))")
            
            guard var user = user as? User,
                  let image = img?.resizeImage(CGSize(width: 640, height: 640)) else {
                return
            }
            
            isUploadingImage = true
            
            self.api.upload(image)
                .then() { (res: URL) -> Promise<User> in
                    print("Result: \(res.absoluteString) - \(user)")
                    
                    user.imageLarge = res.lastPathComponent
                    return user.save()
                }
                .then() { updatedUser in
                    print("UpdatedUser: \(updatedUser)")
                    self.user = updatedUser
                }
                .catch { error in
                    print("uploadImage: \(error)")
                }
                .always() {
                    isUploadingImage = false
                }
        }
        
        let onSelectedCallback = user.isOwnDevice ? imageCallback : nil
        
        #if os(macOS)
        let platformImage = UIImage(systemName: "person")!
        #else
        let platformImage = UIImage.makeLetterAvatar(withUsername: self.userName)!
        #endif
        
        return Form() {
            ZStack(alignment: .center){
                
                Group(){
                    if let imageFileName = user.imageLarge,
                       let imgUrl = URL(string: "/images/\(imageFileName)", relativeTo: appCoordinator.api.baseUrlHttp) {
                        
                        ImageView(url: imgUrl, onSelected: onSelectedCallback) {
                            Text("Loading Image")
                        }
                    } else {
                        ImageView(uiImage: platformImage, callback: onSelectedCallback)
                    }
                }
                //ImageView(uiImage: UIImage.makeLetterAvatar(withUsername: self.userName)!, callback: imageCallback)
                .overlay(
                    Group() {
                        if isUploadingImage {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .foregroundColor(.white)
                        } else {
                            EmptyView()
                        }
                    }
                    .background(Colors.lightGray.opacity(0.6))
                )
                
            }
            .padding()
            
            VStack(alignment: .leading){
                Text(userName).font(.headline)
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
    
    public var contentView: some View {
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

//struct UserProfileView2_Previews: PreviewProvider {
//    
//    static var previews: some View {
//        let user = SEED_DATA.users.first!
//        
//        return NavigationView(){
//            UserProfileView2(user: .constant(user.builder())).offset(x: 0, y: 1)
//        }
//        .navigationBarItems(leading: Text("Save Changes"))
//    }
//    
//}
