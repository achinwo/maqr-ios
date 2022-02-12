//
//  AboutView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 12/02/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore
import AVKit

struct AboutView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    @State var feebackText: String = .empty
    
    var whoWeAreText: String {
        """
SmartStikr was created with the end user in mind, to fill a gaping hole in the e-commerce consumer experience by streamlining inefficient processes to create futuristic and seamless experiences. Our App clips curates novel experiences for your business which allows customers to interact with your business on an intimate level designed to nurture that customer service relationship from a different angle that is guaranteed to expand your business reach and make your customers Stik with you.
"""
    }
    
    var infoView: some View {
        VStack(){
            Image("smartz_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: screenWidth / 3, maxHeight: screenWidth / 3)
            Text("Smart Stikr").font(.headline.weight(.light)).foregroundColor(.tertiaryLabel).padding([.bottom])
            (Text("Welcome to the ").font(.title.weight(.light)).foregroundColor(.tertiaryLabel)
             + Text("Paperless ").font(.title.weight(.light)).foregroundColor(.secondaryLabel)
             + Text("Future").font(.title.weight(.light)).foregroundColor(.tertiaryLabel))
                .multilineTextAlignment(.center)
            
            Text(whoWeAreText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding()
            
            GeometryReader(){ proxy in
                YouTubeView(playerState: YouTubeControlState(.url(URL(staticString: "https://youtu.be/JjwIdYIFSSo"))), autoplay: false)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: proxy.size.width)
                    .frame(height: screenWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(height: screenWidth)
            .frame(maxWidth: screenWidth - 20)
            
            Divider().padding()
            self.mainView
        }
    }
    
    func sectionView(_ section: ProductSection) -> some View {
        let groupView = Group(){
            if case let .video(player) = section.asset {
                VideoPlayer(player: player)
                    .frame(height: screenWidth - 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.secondaryLabel, lineWidth: 1))
            } else if case let .image(imageName) = section.asset {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: screenWidth - 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else if case let .symbol(systemName) = section.asset {
                Image(systemName: systemName)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .font(.largeTitle)
                    .frame(maxWidth: screenWidth / 2)
            } else if case let .youtube(youtubeId) = section.asset {
                
                GeometryReader(){ proxy in
                    YouTubeView(playerState: YouTubeControlState(youtubeId), autoplay: false)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: proxy.size.width)
                        .frame(height: screenWidth)
                }
                .frame(height: screenWidth)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
            .padding(.vertical)
            .frame(maxWidth: screenWidth - 20)
        
        return Section(header: Text(section.title).font(.title2)){
            VStack(){
                Text(section.subtitle)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.light))
                    .foregroundColor(.secondaryLabel)
                    .lineLimit(nil)
                    //.fixedSize(horizontal: false, vertical: true)
                
                if let learnMore = section.learnMore {
                    Link("Learn More...", destination: learnMore).padding()
                }
                
                if let bullets = section.bulletpoints {
                    VStack(alignment: .leading) {
                        ForEach(bullets, id: \.self) { bulletpoint in
                            HStack(){
                                Image(systemName: "circlebadge.fill").renderingMode(.original)
                                Text(bulletpoint)
                            }
                            .font(Font.subheadline)
                            .padding(.vertical, 2)
                            .padding(.leading, Sizing.small)
                        }
                    }
                    .padding(.vertical)
                }
                
                groupView
                
                if let subtitle2 = section.subtitle2 {
                    Text(subtitle2)
                        .multilineTextAlignment(.center)
                        .font(.subheadline.weight(.light))
                        .foregroundColor(.secondaryLabel)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    var mainView: some View {
        VStack(){
            ForEach(sections){ section in
                self.sectionView(section)
                    .padding([.bottom, .horizontal])
                
            }
        }
    }
    
    let sections: [ProductSection] = [
        ProductSection(asset: .image("sise_box_ofada"),
                       title: "Services",
                       //subtitle: "Reasons To Choose SmartStikr",
                       subtitle: "No matter your e-commerce business type, SmartStikr has an innovative solution for you. Our App clips can be used for anything from welcoming guests to your restaurant or business place, providing options for customers to reach waiting staff during the dine-in process and check out with apple pay, providing interactive step by step instructions for your meal prep boxes and even up to solutions for AirBnB and Uber guests and many more. There is no limit to our innovative and interactive solutions for SmartStikr. In all of these we limit and sometimes eliminate the need for paper and we streamline the process of doing business with your business, ultimately saving you money, time and eliminating redundancy.",
                       bulletpoints: [
                        "Organised and Impressive dine-In check in processes",
                        "Seamlessly Interact with customers",
                        "Curate more intimate relationships with customers",
                        "Easily direct and improve re-order percentage",
                        "Easy & Quick “jump-to” opportunities for specific product categories that can be tailored to different groups",
                        "AirBnB Check-in and Check out processes",
                       ]
                      ),
        
        ProductSection(asset: .image("app_clip_choices"),
                       title: "The Technology - Automatically Downloading Codes",
                       subtitle: "Apple’s App Clips technology was introduced to the world in May 2020. The technology behind these scannable codes give them a notable advantage over traditional QR codes. Whereas QR Codes redirect customers to the App Store to download the app, App Clip codes take customers directly to the experience by automating the download step on the customers behalf, significantly improving convenience, driving engagement and reducing session abandonment.",
                       learnMore: URL(string: "https://developer.apple.com/app-clips/")!
                      ),
        
        ProductSection(asset: .youtube(.url(URL(staticString: "https://youtu.be/P4016ZGlbVc"))),
                       title: "Rich Customer Experience",
                       subtitle: "Our mission here at SmartStikr is simple. We want to give e-commerce businesses the ability to seamlessly organise, market and streamline their business processes and interact with customers in the language they speak using impressive user friendly technology while saving our planet at the same time."),
        
        ProductSection(asset: .youtube(.url(URL(staticString: "https://youtu.be/_Ly3UEV9NnE"))),
                       title: "Go Contactless",
                       subtitle: "Stikrs support NFC for a contactless experience."),
        
        ProductSection(asset: .symbol("leaf.fill"),
                       title: "Want to Help go Sustainable",
                       subtitle: "SmartStikr is committed to creating a greener planet by reducing paper waste and taking advantage of technology that will propel e-commerce industry to the future and forefront of technological advancement. Join us in our green earth commitment"),
        
        
        
    ]
    
    var feedbackView: some View {
        ScrollView(){
            VStack(){
                VStack(){
                    
                    
                    Section(header: Text("Get in Touch").font(.largeTitle)) {
                        Text("We'd love to hear from you!").font(.subheadline.weight(.light)).padding(.bottom).multilineTextAlignment(.center).lineLimit(5)
                        
                        TextEditor(text: self.$feebackText)
                            .frame(height: screenWidth / 2)
                            .overlay(
                                VStack(alignment: .leading){
                                    if feebackText.isEmpty {
                                        Text("Enter your message here").padding().foregroundColor(.tertiaryLabel)
                                        Spacer()
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                    }
                    .padding()
                    
                    Button(){
                        print("submitted help!")
                        let subject = "SmartStikr iOS App Feedback - \(AppCoordinator.version)"
                        self.appCoordinator.modal.presentMailComposer(.init(subject: subject, recipients: [Strings.appSupportEmail], body: feebackText))
                    } label: {
                        HStack(){
                            Spacer()
                            Text("Send Message")
                                .font(.title3)
                                .foregroundColor(.label)
                            Spacer()
                        }
                    }
                    .background(Color.systemIndigo)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    ))
                    .frame(width: screenWidth - 150, height: 60)
                    .accentColor(.white)
                    .buttonStyle(OutlineButton())
                    .padding()
                }
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.bottom)
                .padding(.bottom)
                .overlay(
                    GeometryReader(){ _ in
                        VStack(){
                            Image("smartz_logo")
                                .resizable()
                                .frame(width: screenWidth / 6, height: screenWidth / 6)
                                .clipShape(Circle())
                                .offset(x: 0, y: (screenWidth / 24) * -1)
                                .shadow(radius: 1)
                            Spacer()
                        }
                    }
                )
                
                HStack(){
                    Spacer()
                    
                    Link(destination: URL(social: .instagramUser("smartstikr"))) {
                        VStack(){
                            Image("instagram_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                            Text("Follow Us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                            Text("@smartstikr").font(.body.weight(.semibold)).foregroundColor(.primary)
                        }
                        .padding()
                    }
                    
                        //                                        VStack(){
                        //                                            Image("fbk_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                        //                                            Text("Share us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                        //                                            Text("#madewithsise").font(.body.weight(.semibold)).foregroundColor(.primary)
                        //                                        }
                        //                                        .padding()
                    
                    Spacer()
                }
                //.padding(.top, safeAreaInsets.top)
                //.padding(.bottom, safeAreaInsets.bottom * 4)
                .animation(.easeInOut)
                
                Link("Privacy Policy", destination: URL(staticString: "https://smartstikr.com/uk/legal/privacy-policy/")).padding()
                Link("Our Terms of Use", destination: URL(staticString: "https://smartstikr.com/uk/legal/terms_and_conditions/")).padding(.bottom)
                Link("License Agreement", destination: URL(staticString: "https://smartstikr.com/uk/legal/end_user_license_agreement/")).padding(.bottom)
                
            }
            .frame(width: screenWidth - 100)
            .padding(.top)
        }
        .frame(minWidth: screenWidth)
        
    }
    
    var contentView: some View {
        VStack(){
            infoView
            Divider().padding(.vertical)
            feedbackView
        }
        .padding(.bottom, safeAreaInsets.bottom * 4)
    }
}
