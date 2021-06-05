//
//  MailView.swift
//  Joli
//
//  Created by Anthony Chinwo on 10/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
import MessageUI
#endif

import AVFoundation

public struct MailViewOptions: Equatable {
    
    public init(subject: String, recipients: [String], body: String? = nil) {
        self.subject = subject
        self.recipients = recipients
        self.body = body
    }
    
    public let subject: String
    public let recipients: [String]
    public var body: String? = nil
}

#if os(macOS)
public struct MailView {
    public typealias Options = MailViewOptions
}
#else
public struct MailView: UIViewControllerRepresentable {
    
    public init(result: Binding<Result<MFMailComposeResult, Error>?>, subject: String? = nil, recipients: [String] = [String](), body: String? = nil) {
        self.subject = subject
        self.recipients = recipients
        self.body = body
        self._result = result
    }
    
    public typealias Options = MailViewOptions
    
    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    var subject: String? = nil
    var recipients = [String]()
    var body: String? = nil
    
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
    
    public class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        
        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?
        
        init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>){
            _presentation = presentation
            _result = result
        }
        
        public func mailComposeController(_: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?){
            defer {
                $presentation.wrappedValue.dismiss()
            }
            
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            
            self.result = .success(result)
            
            if result == .sent {
                AudioServicesPlayAlertSound(SystemSoundID(1001))
            }
        }
        
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation,
                           result: $result)
    }
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.mailComposeDelegate = context.coordinator
        
        if let subject = subject {
            vc.setSubject(subject)
        }
        
        if let body = body {
            vc.setMessageBody(body, isHTML: true)
        }
        
        return vc
    }
    
    public func updateUIViewController(_: MFMailComposeViewController,
                                context _: UIViewControllerRepresentableContext<MailView>) {}
}
#endif
