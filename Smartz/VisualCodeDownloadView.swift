//
//  VisualCodeDownloadView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 15/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import os

struct VisualCodeDownloadView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    @State var downloaded = false
    
    func iCloudDirectoryCreate(_ completionHanlder: (() -> Void)? = nil) {
        //let line = "Hello World"
        let url = api.baseUrlHttp.appendingPathComponent("/downloads/codes.zip")
        let fileName = "codes-\(UUID().uuidString).zip"
        let localDocsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        
        let localFile = localDocsURL.appendingPathComponent(fileName)
        ///downloads/code.zip
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        
        let task = api.urlSession.dataTask(with: req) { data, response, error in
            
            guard error == nil else {
                print("[code fetch] error: \(String(describing: error))")
                return
            }
            
            guard let data = data else {
                print("[code fetch] no data returned")
                return
            }
            
            do {
                //try line.write(to: localFile, atomically: true, encoding: .utf8)
                //let data = try Data(contentsOf: URL(staticString: "https://192.168.1.233:8080/downloads/codes.zip"))
                try data.write(to: localFile)
            } catch {
                os_log("Failed to export...", log: OSLog.default, type: .error)
            }
            
            guard let iCloudDocsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
                print("Unable to obtain documents path url")
                return
            }
            
            let iCloudFile = iCloudDocsURL.appendingPathComponent(fileName)
            
            if !FileManager.default.fileExists(atPath: iCloudDocsURL.path, isDirectory: nil) {
                try? FileManager.default.createDirectory(at: iCloudDocsURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            do {
                try FileManager.default.copyItem(at: localFile, to: iCloudFile)
            } catch {
                os_log("Failed to move to iCloud...", log: OSLog.default, type: .error)
            }
            
            
            print("saved: \(iCloudFile)")
            completionHanlder?()
        }
        
        task.resume()
    }
    
    
    var contentView: some View {
        VStack(){
            
            VStack(){
                
                (Text("Download ") + Text("Stikrs ").italic() + Text("to iCloud Drive"))
                    .font(.title.weight(.light))
                    .foregroundColor(.secondary)
                    .padding()
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                
                
                Divider().padding(.bottom)
                
                Image(systemName: "externaldrive.fill.badge.icloud")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: screenWidth / 2.4)
                    .padding([.bottom, .horizontal])
                    .padding(.vertical)
                
                Button(){
                    
                    guard !downloaded else {
                        appCoordinator.share(text: "Your file", url: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/austin-chan-ukzHlkoz1IE-unsplash.jpg"))
                        return
                    }
                    
                    self.iCloudDirectoryCreate() {
                        self.presentToast("Done", subTitle: "Saved to iCloud Drive", type: .complete(.green)) { _ in
                            self.downloaded = true
                        }
                    }
                } label: {
                    HStack(){
                        Spacer()
                        Label(downloaded ? "Share .zip File" : "Save .zip to iCloud", systemImage: downloaded ? "square.and.arrow.up" : "icloud.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(downloaded ? .white : .secondarySystemGroupedBackground)
                        Spacer()
                    }
                }
                .background(downloaded ? .systemIndigo : Color.white)
                .clipShape(RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                ))
                .frame(width: screenWidth - 100, height: 60)
                .accentColor(downloaded ? .systemIndigo.opacity(0.6) : .secondary)
                .buttonStyle(OutlineButton())
            }
            .frame(width: screenWidth - 100)
            .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.bottom)
            .padding(.top, safeAreaInsets.top * 2)
            (Text("Note: ") + Text("Code Designer ").fontWeight(.semibold) + Text("is in beta and subject to change with future updates"))
                .frame(width: screenWidth - 100)
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
    }
}

