//
//  AppDelegate.swift
//  Joli
//
//  Created by Anthony Chinwo on 25/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import UIKit
import AVKit
import JoliApi
import SwiftyBeaver
import UserNotifications

let logger = JoliApi.getLogger()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    #if DEBUG
    let debug = true
    #else
    let debug = false
    #endif
    
    var appState: AppState!
    var audioSession = AVAudioSession.sharedInstance()
    
    private struct Observation {
        static let VolumeKey = "outputVolume"
        static var Context = 0
    }
    
    private var  observingChanges = false

    func startObservingVolumeChanges() {
        logger.debug("[AppDelegate#startObservingVolumeChanges]")
        
        guard !observingChanges else { return }
        
        audioSession.addObserver(self, forKeyPath: Observation.VolumeKey, options: [.initial, .new], context: &Observation.Context)
        observingChanges = true
        //self.observeValue(forKeyPath: Observation.VolumeKey, of: audioSession, change: nil, context: &Observation.Context)
    }
    
    func stopObservingVolumeChanges() {
        logger.debug("[AppDelegate#stopObservingVolumeChanges]")
        
        guard observingChanges else { return }
        audioSession.removeObserver(self, forKeyPath: Observation.VolumeKey, context: &Observation.Context)
        observingChanges = false
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) -> Void {
        if context == &Observation.Context {
            guard keyPath == Observation.VolumeKey, let volume = (change?[NSKeyValueChangeKey.newKey] as? NSNumber)?.floatValue else {
                // `volume` contains the new system output volume...
                return
            }
            logger.debug("Volume: \(volume)")
            
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
    
    var env: JoliApi.Environment {
        
        get {

            guard self.debug else {
                return .production
            }
            
            let json = JoliApi.Environment.CACHED_ENV_CONFIG
            return JoliApi.Environment(rawValue: json["env"] as? String ?? JoliApi.Environment.local.rawValue) ?? .development
        }
        
        set {
            JoliApi.Environment.CACHED_ENV_CONFIG["env"] = newValue.rawValue as AnyObject
        }
        
    }
    
    func registerForPushNotifications() {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
          [weak self] granted, error in
            
          print("Permission granted: \(granted)")
          guard granted else { return }
        
          self?.getNotificationSettings()
      }
    }
    
    func getNotificationSettings() {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        print("Notification settings: \(settings)")
        
        guard settings.authorizationStatus == .authorized else { return }
        
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
    
    /// https://code.tutsplus.com/tutorials/an-introduction-to-the-usernotifications-framework--cms-27250
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        let content = response.notification.request.content
         
        switch actionIdentifier {
        case UNNotificationDismissActionIdentifier: // Notification was dismissed by user
            logger.info("[AppDelegate#userNotificationCenter] dismissed: \(content)")
            completionHandler()
        case UNNotificationDefaultActionIdentifier: // App was opened from notification
            logger.info("[AppDelegate#userNotificationCenter] launched: \(content)")
            completionHandler()
        default:
            completionHandler()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        // Process notification content
        logger.info("[AppDelegate#userNotificationCenter] willPresent: \(content.body)")
        completionHandler([.alert]) // Display notification as regular alert and play sound
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
      let token = tokenParts.joined()
        logger.info("Device Token: \(token)")
        
        appState.api.setNotificationToken(token).then() { device in
            logger.info("Token Saved: \(device)")
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
      fetchCompletionHandler completionHandler:
      @escaping (UIBackgroundFetchResult) -> Void
    ) {
      guard let aps = userInfo["aps"] as? [String: AnyObject] else {
        completionHandler(.failed)
        return
      }
        logger.info("[AppDelegate] handled notificatiom", context: aps)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register: \(error)")
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        let cloud = SBPlatformDestination(appID: "Qxn1Mn", appSecret: "21jhvbtglMuzJhilb6m97owddeQdbjkq", encryptionKey: "xVDA8e89pdb7AuxldgYsNuezdqlHriko") // to cloud
        cloud.analyticsUserName = UIDevice.current.name
        cloud.sendingPoints.threshold = 2
        
        logger.addDestination(cloud)
        
        logger.debug("[AppDelegate#willFinishLaunchingWithOptions] notifOptions:\(String(describing: launchOptions))")
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        do {
//            try audioSession.setCategory(AVAudioSession.Category.playback)
//        } catch {
//            logger.debug("Setting category to AVAudioSessionCategoryPlayback failed.")
//        }
        
//        do {
//            try audioSession.setActive(true)
//            startObservingVolumeChanges()
//        } catch {
//            logger.debug("Failed to activate audio session")
//        }
        
        if debug, let filePath = Bundle.main.path(forResource: "env", ofType: "json"),
            let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
            let json: [String: AnyObject] = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] {
            logger.debug("[Debug mode] env config: \(json)")

            JoliApi.Environment.CACHED_ENV_CONFIG.merge(json) { (_, new) in new }
        }
        
        logger.debug("[AppDelegate] application started - env:\(env), baseUrl:\(env.baseUrl), notifOptions:\(String(describing: launchOptions))")
        
        self.appState = AppState(baseUrl: env.baseUrl)
        
//        getDeliveredNotifications(completionHandler:) provides you with an array of UNNotification objects in the completion handler. This array will contain all the notifications delivered for your app which are still visible in the user's Notification Centre.
//        removeDeliveredNotifications(withIdentifiers:) removes all delivered notifications with identifiers
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { // Change `2.0` to the desired number of seconds.
           // Code you want to be delayed
            self.registerForPushNotifications()
        }
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication){
        logger.debug("[AppDelegate] App is active")
        appState.api.wsClient.connect()
        
    }

    func applicationWillResignActive(_ application: UIApplication){
        logger.debug("[AppDelegate] App is inactive")
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

