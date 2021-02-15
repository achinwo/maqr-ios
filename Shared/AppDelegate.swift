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
import UserNotifications
import Promises


var appDelegateSingleton: AppDelegate!

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    #if DEBUG
    let debug = true
    #else
    let debug = false
    #endif
    
    var appState: AppState!
    var audioSession = AVAudioSession.sharedInstance()
    
    var window: UIWindow?
    
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
    
    deinit {
        self.stopObservingVolumeChanges()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) -> Void {
        if context == &Observation.Context {
            guard keyPath == Observation.VolumeKey, let volume = (change?[NSKeyValueChangeKey.newKey] as? NSNumber)?.floatValue else {
                // `volume` contains the new system output volume...
                return
            }
            logger.debug("Volume: \(volume)")
            
            let computedVolume = Int(volume * 100)
            
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
        guard self.debug else {
            return .production
        }
        
        let json = JoliApi.Environment.CACHED_ENV_CONFIG
        return JoliApi.Environment(rawValue: json["env"] as? String ?? JoliApi.Environment.local.rawValue) ?? .development
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
        completionHandler([.list]) // Display notification as regular alert and play sound
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
        logger.info("[AppDelegate] handled notificatiom: \(String(describing: aps))")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register: \(String(describing: error))")
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        appDelegateSingleton = self
        
        UNUserNotificationCenter.current().delegate = self
        
        if debug {
            JoliApi.Environment.loadEnvConfig()
        }
        
        self.appState = AppState(baseUrl: self.env.baseUrl, serverVersion: nil)
        
        //logger.addDestination(ServerDestination(url: self.env.baseUrl.http, urlSession: self.appState.api.urlSession))
        
        logger.debug("[AppDelegate#willFinishLaunchingWithOptions] notifOptions:\(String(describing: launchOptions))")
        return true
    }
    
    /// - Tag: PerformAction
    func application(_ application: UIApplication,
             performActionFor shortcutItem: UIApplicationShortcutItem,
             completionHandler: @escaping (Bool) -> Void) {
        // Alternatively, a shortcut item may be passed in through this delegate method if the app was
        // still in memory when the Home screen quick action was used. Again, store it for processing.
        shortcutItemToProcess = shortcutItem
        logger.debug("[AppDelegate] shortcutItemToProcess=\(String(describing: shortcutItemToProcess))")
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
        
        logger.debug("[AppDelegate] application started - env:\(self.env), baseUrl:\(self.env.baseUrl), notifOptions:\(String(describing: launchOptions))")
        
//        Promise<Void>() { (resolve, reject) in
//
//        }
        
//        getDeliveredNotifications(completionHandler:) provides you with an array of UNNotification objects in the completion handler. This array will contain all the notifications delivered for your app which are still visible in the user's Notification Centre.
//        removeDeliveredNotifications(withIdentifiers:) removes all delivered notifications with identifiers
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.registerForPushNotifications()
        }
        
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            shortcutItemToProcess = shortcutItem
            logger.debug("[AppDelegate] shortcutItemToProcess=\(String(describing: shortcutItemToProcess))")
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            shortcutItemToProcess = shortcutItem
        }
        
        let sceneConfiguration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = CustomSceneDelegate.self
        
        return sceneConfiguration
    }

}

var shortcutItemToProcess: UIApplicationShortcutItem?

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        shortcutItemToProcess = shortcutItem
        logger.debug("[AppDelegate] windowScene=\(shortcutItem)")
    }
}
