//
//  AppDelegate.swift
//  Joli
//
//  Created by Anthony Chinwo on 25/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import UIKit
import AVKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    
    var appState = AppState()
    var audioSession = AVAudioSession.sharedInstance()
    
    private struct Observation {
        static let VolumeKey = "outputVolume"
        static var Context = 0

    }

    func startObservingVolumeChanges() {
        print("[AppDelegate#startObservingVolumeChanges]")
        audioSession.addObserver(self, forKeyPath: Observation.VolumeKey, options: [.initial, .new], context: &Observation.Context)
        //self.observeValue(forKeyPath: Observation.VolumeKey, of: audioSession, change: nil, context: &Observation.Context)
    }
    
    func stopObservingVolumeChanges() {
        print("[AppDelegate#stopObservingVolumeChanges]")
        audioSession.removeObserver(self, forKeyPath: Observation.VolumeKey, context: &Observation.Context)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) -> Void {
        if context == &Observation.Context {
            guard keyPath == Observation.VolumeKey, let volume = (change?[NSKeyValueChangeKey.newKey] as? NSNumber)?.floatValue else {
                // `volume` contains the new system output volume...
                return
            }
            print("Volume: \(volume)")
            
            let computedVolume = Int(volume * 100)
            
//            if let deviceVol = appState.spotifyDevice?.volumePercent, (computedVolume - deviceVol) > 25 {
//                computedVolume = (computedVolume - deviceVol) / 2 // half the requested volume
//            }
            
            
            self.appState.api.fetchSpotifyDevices(on: DispatchQueue.main)
                .then() { devices in
                    
                    guard let activeIdx = devices.firstIndex(where: { $0.isActive }) else {
                        return
                    }
                    
                    self.appState.api.setVolume(computedVolume, deviceId: devices[activeIdx].id)
            }
            
            //observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
//        do {
//            try audioSession.setActive(true)
//            startObservingVolumeChanges()
//        } catch {
//            print("Failed to activate audio session")
//        }
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication){
        print("[AppDelegate] App is active")
        appState.api.wsClient.connect()
        
    }

    func applicationWillResignActive(_ application: UIApplication){
        print("[AppDelegate] App is inactive")
        appState.api.wsClient.disconnect()
        stopObservingVolumeChanges()
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

