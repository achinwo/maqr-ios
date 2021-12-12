//
//  MessageView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 17/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import MessageUI

public struct MessageView: UIViewControllerRepresentable {
    
    public typealias UIViewControllerType = MFMessageComposeViewController
    
    let subject: String?
    var recipients: [String]?
    let body: String?
    var completion: () -> Void
    
    public init(_ subject: String? = nil, body: String? = nil, recipients: [String]? = nil, completion: @escaping () -> Void){
        self.recipients = recipients
        self.completion = completion
        self.subject = subject
        self.body = body
    }
    
    public class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        
        var completion: () -> Void
        
        init(completion: @escaping () -> Void) {
            self.completion = completion
        }
        
        // delegate method
        public func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true, completion: nil)
            completion()
        }
        
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(completion: completion) // not using completion handler
    }
    
    public func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.subject = subject
        vc.recipients = recipients
        vc.body = body // "https://instagram.com/users/smartstikr"
//        vc.subject = "Its a new day!"
        print("Can send text: \(MFMessageComposeViewController.canSendAttachments())")
        //MFMessageComposeViewController.
        //vc.addAttachmentURL(URL(staticString: "https://instagram.com"), withAlternateFilename: "Instagram Home")
        vc.messageComposeDelegate = context.coordinator
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}

    //        .sheet(isPresented: self.$isShowingMessages) {
    //            MessageView(recipient: "+447884873600")
    //                .ignoresSafeArea()
    //        }
    //        .overlay(
    //            Button("Show Messages") {
    //                self.isShowingMessages = true
    //            }
    //        )
