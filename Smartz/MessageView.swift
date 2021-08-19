//
//  MessageView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 17/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import MessageUI

struct MessageView: UIViewControllerRepresentable {
    var recipient: String
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var completion: () -> Void
        init(completion: @escaping ()->Void) {
            self.completion = completion
        }
        
        // delegate method
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true, completion: nil)
            completion()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator() {} // not using completion handler
    }
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = [recipient]
//        vc.body = "https://instagram.com/users/smartstikr"
//        vc.subject = "Its a new day!"
        print("Can send text: \(MFMessageComposeViewController.canSendAttachments())")
        //MFMessageComposeViewController.
        //vc.addAttachmentURL(URL(staticString: "https://instagram.com"), withAlternateFilename: "Instagram Home")
        vc.messageComposeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    typealias UIViewControllerType = MFMessageComposeViewController
}
