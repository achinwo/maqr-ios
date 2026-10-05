//
//  AppCoordinator.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/10/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import Combine
import MaqrApi
import SwiftUI
import Version
import AlertToast
import struct NetworkImage.NetworkImageLoader
import struct NetworkImage.NetworkImageCache
import PartialSheet

public enum AuthenticationFlow {
    case apple((Bool) -> Void)
}

public enum EditTarget: Equatable {
    case active(String)
    case none
}

public enum ViewMode: Equatable {
    case editing
    case preview
}

public struct ViewModeKey: EnvironmentKey {
    public static var defaultValue: ViewMode = .preview
}

public extension EnvironmentValues {
    
    var viewModeGlobal: ViewMode {
        get { self[ViewModeKey.self] }
        set {
            self[ViewModeKey.self] = newValue
        }
    }
    
}


public class ModalCoordinator {
    
    public typealias CloseCallback = () -> Void
    
    public enum Item {
        case view(AppPreview)
        case mailOptions(MailView.Options)
    }
    
    public struct Modal: Identifiable, Equatable {
        
        public static func == (lhs: ModalCoordinator.Modal, rhs: ModalCoordinator.Modal) -> Bool {
            lhs.id == rhs.id
        }
        
        public let id: UUID = UUID()
        public let item: Item
        public let onClose: () -> Void
    }
    
    private var modal: Modal? = nil {
        didSet {
            self.publisher.send(modal)
        }
    }
    
    public let publisher = PassthroughSubject<Modal?, Never>()
    
    private var pendingCompletions: [(() throws -> Void)] = []

    public func present(onClose: (() -> Void)? = nil, _ content: () -> AppPreview) {
        
        self.modal = .init(item: Item.view(content()), onClose: { [weak self] in
            self?.modal = nil
            onClose?()
            
            guard let self = self, !self.pendingCompletions.isEmpty else { return }
            
            for closure in self.pendingCompletions {
                try? closure()
            }
            
            self.pendingCompletions = []
        })
    }
    
    public func presentMailComposer(_ options: MailView.Options, onClose: (() -> Void)? = nil) {
        
        self.modal = .init(item: Item.mailOptions(options), onClose: {
            self.modal = nil
            onClose?()
        })
    }
    
    public func close(_ completion: (() -> Void)? = nil) {
        
        self.publisher.send(nil)
        
        guard let completion = completion, self.modal != nil else {
            print("[CLOSE] modal is nil")
            self.modal?.onClose()
            return
        }
        
        print("[CLOSE] modal is NOT nil")
        self.pendingCompletions.append(completion)
    }
    
}

// MARK: - AppCoordinator
public final class AppCoordinator: ObservableObject {
    
    @Published public var currentLocation: AppLocation = .unset
    
    public var api: MaqrApi!
    public lazy var serverLogDestination: ServerDestination = {
        return ServerDestination(url: api.baseUrlHttp, urlSession: api.urlSession)
    }()
    
    private var cancellableSet: Set<AnyCancellable> = []
    
    lazy var imageLoader: NetworkImageLoader = {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 100 * 1024 * 1024
        
        let configuration = api.urlSession.configuration
        
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        configuration.httpAdditionalHeaders = ["Accept": "image/*"]
        
        guard api.env == .production else {
            return NetworkImageLoader(urlSession: URLSession(configuration: configuration, delegate: MaqrApi.sharedUrlSessionDelegate, delegateQueue: .current), imageCache: NetworkImageCache())
        }
        
        return NetworkImageLoader(urlSession: URLSession(configuration: configuration), imageCache: NetworkImageCache())
    }()
    
    @Published public var serverInfo: ServerInfo? = nil
    @Published public var isSharePresented = false
    @Published public var namespace: Namespace.ID? = nil
    @Published public var keyboardHeight: CGFloat = 0
    @Published public var apnToken: String? = nil
    @Published public var currentEditTarget: EditTarget? = nil
    
    public let signoutSubject = PassthroughSubject<Auth, Never>()
    public let globalToastInfo = PassthroughSubject<(alert: AlertToast, onDismiss: (Bool) -> Void), Never>()
    
    public let requestedSignIn = PassthroughSubject<AuthenticationFlow, Never>()
    public let requestedNotificationPermission = PassthroughSubject<Date, Never>()
    
    public let purchaseNotificationSubject = PassthroughSubject<String?, Never>()
    
    public let storeKitHelper: StoreKitHelper
    public typealias ErrorInfo = (error: Error, file: String, function: String, line: Int)
    
    public let internalErrorSubject = PassthroughSubject<ErrorInfo, Never>()
    
    public let modal = ModalCoordinator() //PassthroughSubject<AppPreview?, Never>()
    public let globalPreviewSubject = PassthroughSubject<AppPreview?, Never>()
    
    public let globalAlertSubject = PassthroughSubject<Alert, Never>()
    
    public let authSubject = PassthroughSubject<Auth?, Never>()
    
    public let authsSubject = CurrentValueSubject<[Auth], Never>([])
    
    @Published public var connectionStateSubject: CurrentValueSubject<(state: ConnectionState, changedAt: Date?), Never> = CurrentValueSubject((.stopped, nil))
    
    @Published public var activeSessionToken: String? = nil {
        didSet {
            self.authSubject.send(activeAuth)
        }
    }
    
    public var appViewScrollPosition = PassthroughSubject<ScrollPosition, Never>()
    
    public var isPaymentEnabled: Bool {
        serverInfo?.feature.paymentsEnabled == true
    }
    
    public func globalErrorHandler(file: String = #file, function: String = #function, line: Int = #line) -> (Error) -> Void {
        return { (error: Error) -> Void in
            DispatchQueue.main.async() {
                self.internalErrorSubject.send((error, file, function, line))
            }
        }
    }
    
    public func withAlert(_ title: String, message: String? = nil, destructive: Bool = false, dismissLabel: String? = nil, label: String? = nil,
                          dismissAction: (() -> Void)? = nil, action: @escaping () -> Void = {}) {
        
        var messageTxt: Text? = nil
        
        if let msg = message {
            messageTxt = Text(msg)
        }
        
        let cancelButton: Alert.Button
        let onDismiss = { () -> Void in
            dismissAction?()
            logger.info("[\(Self.self)#\(#function)] dismissed alert: \"\(title)\"")
        }
        
        if let dismissLabel = dismissLabel {
            cancelButton = .cancel(Text(dismissLabel), action: onDismiss)
        } else {
            cancelButton = .cancel(onDismiss)
        }
        
        guard let label = label else {
            self.globalAlertSubject.send(Alert(title: Text(title),
                                                 message: messageTxt,
                                                 dismissButton: cancelButton))
            return
        }
        
        let primaryButton: Alert.Button = destructive ? .destructive(Text(label), action: action) : .default(Text(label), action: action)
        
        let alert: Alert = Alert(title: Text(title),
                                 message: messageTxt,
                                 primaryButton: primaryButton,
                                 secondaryButton: cancelButton)
        
        self.globalAlertSubject.send(alert)
    }
    
    public func withAlert(_ title: String, message: String? = nil, destructive: Bool = false, dismissLabel: String? = nil, label: String? = nil, action: @escaping () -> Void = {}) {
        self.withAlert(title, message: message, destructive: destructive, dismissLabel: dismissLabel, label: label, dismissAction: nil, action: action)
    }
    
    public func withAlert(_ title: String, message: String? = nil, dismissLabel: String, action: @escaping () -> Void) {
        self.withAlert(title, message: message, dismissLabel: dismissLabel, label: nil, dismissAction: action)
    }
    
    public var activeAuth: Auth? {
        return self.authsSubject.value.first() { $0.session.token == activeSessionToken }
    }
    
    public static var version: Version {
        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let version = Version("\(appVersion).\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")") else {
            return Version.init(1, 0, 0)
        }
        
        return version
    }
    
    public init(namespace: Namespace.ID? = nil){
        self.namespace = namespace
        self.storeKitHelper = StoreKitHelper()
        
        let notificationCenter = NotificationCenter.default
        
        #if !os(macOS)
        notificationCenter.publisher(for: .storeKitHelperPurchaseNotification)
            .map(){ notification in
                return notification.object as? String
            }
            .sink(){ identifier in
                self.purchaseNotificationSubject.send(identifier)
            }
            .store(in: &cancellableSet)
        
        notificationCenter.publisher(for: UIWindow.keyboardWillShowNotification)
            .map {
                guard
                    let info = $0.userInfo,
                    let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                else { return 0 }
                
                return keyboardFrame.height
            }
            .assign(to: \.keyboardHeight, on: self)
            .store(in: &cancellableSet)
        
        notificationCenter.publisher(for: UIWindow.keyboardDidHideNotification)
            .map { _ in 0 }
            .assign(to: \.keyboardHeight, on: self)
            .store(in: &cancellableSet)
        #endif
    }
    
    public func dismissKeyboard() {
        #if !os(macOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    public func share(text: String, url: URL, completionHandler: ((Bool) -> Void)? = nil){
        isSharePresented.toggle()
        
        let sharedObjects: [AnyObject] = [text as AnyObject]//, url as AnyObject]
        
        #if os(macOS)
        completionHandler?(false)
        #else
        let av = UIActivityViewController(activityItems: sharedObjects, applicationActivities: [ShareActivity()])
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true) {
            print("[AppCoordinator#share] share view presented")
            completionHandler?(true)
        }
        #endif
    }
    
    public func withImpact(_ impact: FeedbackStyle = .soft, _ action: () -> Void){
        #if os(macOS)
        action()
        #else
        let impactHeavy = UIImpactFeedbackGenerator(style: impact)
        action()
        impactHeavy.impactOccurred()
        #endif
    }
    
    public var isSimulatorOrTestFlight: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        
        let result = path.contains("CoreSimulator") || path.contains("sandboxReceipt")
        return result
    }
    
    public func onConnectionStateChange(_ state: ConnectionState) {
        logger.debug("[\(Self.self)] conection state changed: \(state)")
        self.connectionStateSubject.send((state, Date()))
    }
    
    public struct Modifier: ViewModifier {
        
        let coordinator: AppCoordinator
        
        public init(_ coordinator: AppCoordinator){
            self.coordinator = coordinator
        }
        
        public func body(content: Content) -> some View {
            let view = content.environmentObject(self.coordinator)
            #if os(macOS)
            return view
            #else
            return view.attachPartialSheetToRoot()
            #endif
        }
        
    }
    
}
