//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 01/11/2019.
//

import Foundation
import Promises


struct WebSocketMessage: Encodable {
    let topic: String
    let body = ["subject": "PLAYER_STATE_NOW_PLAYING"]
    let headers: HttpMethod.Headers
}

extension WebSocketMessage {
    
    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try! encoder.encode(self)
        
        return  String(data: jsonData, encoding: .utf8)!
    }
    
}

public enum ConnectionState {
    case reconnecting(Int)
    case stopped
}

public enum WebSocketError: Error {
    case sendFailed(String)
}

public class WebSocketClient: HttpsHook {
    
    public enum MessageTopic {
        case topic(String)
        case subscribe(String)
        
        var stringValue: String {
            switch self {
            case .topic(let topicName):
                return "/\(topicName)"
            case .subscribe(let subject):
                return "/subscribe?subject=\(subject)"
            }
        }
    }
    
    public typealias MessageCallback = (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    public typealias ResponseCallback = (Response?, Error?) throws -> Void
    
    public typealias SubscriptionArguments = (callbacks: [ResponseCallback], message: URLSessionWebSocketTask.Message)
    
    var session: URLSession!
    var task: URLSessionWebSocketTask?
    
    public var messageCallbacks: [String: SubscriptionArguments] = [:]
    
    public var connectionState = ConnectionState.stopped
    
    public var connected = false {
        didSet {
            self.connectionHandler?(connected)
        }
    }

    public var  url: URL!
    //var queue: OperationQueue = DispatchQueue.global(qos: .background)
    //public var subjects: Set<String> = []
    
    public init(url: URL, trustedHosts: [String] = []) {
        super.init(trustedHosts: trustedHosts)
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        self.url = url
    }
    
    private func addSubscription(_ subject: String, message: URLSessionWebSocketTask.Message, callback: @escaping ResponseCallback) {
        var sub = self.messageCallbacks[subject] ?? (callbacks: [], message: message)
        sub.callbacks.append(callback)
        
        self.messageCallbacks[subject] = sub
    }
    
    // TODO: handle non-subscription topics
    // MARK: - Send Message
    public func subscribe(_ subject: String, headers: HttpMethod.Headers? = nil, handler: @escaping ResponseCallback) -> Promise<Void> {

        let msg = WebSocketMessage(topic: MessageTopic.subscribe(subject).stringValue, headers: headers ?? [:])
        let message = URLSessionWebSocketTask.Message.string(msg.jsonString())

        self.addSubscription(subject, message: message, callback: handler)
        
        return Promise() { (resolve, reject) in
        
            self.task?.send(message) { error in
                guard let error = error else {
                    resolve(())
                    return
                }
                reject(error)
            }
        }
    }
    
    private func reperformSubscriptions(){
        for (subject, args) in self.messageCallbacks {
            self.task?.send(args.message) { error in
                guard let error = error else {
                    print("[WebSocketClient#reperformSubsciptions] resubscibed \"\(subject)\"")
                    return
                }
                print("[WebSocketClient#reperformSubsciptions] error subscribing \"\(subject)\": \(error)")
            }
        }
    }
    
    private func triggerCallbacks(subject: String, resp: Response?, error: Error?){
        
        guard let sub = self.messageCallbacks[subject] else { return }
        
        for cb in sub.callbacks {
            do {
                try cb(resp, error)
            } catch {
                debugPrint("[WebSocketClient#triggerCallbacks] subject=\(subject), error=\(error)")
            }
        }
    }
    
    private func receive(){
        self.task?.receive() { result in
            
            defer {
                
                if let response = result.successResponse, let subject = response.subject {
                    self.triggerCallbacks(subject: subject, resp: response, error: nil)
                }else{
                    print("[WebSocketClient#receive] Unhandled: \(result)")
                }
                
            }
            
            if case let Result.failure(error) = result {
                print("[receive] error response aborting...\(error)")
                self.scheduleReconnect() // MARK: - Schedule Reconnect
                return
            }
            
            guard self.connected else {
                print("[receive] disconected aborting...")
                return
            }
            
            print("[receive] scheduling next receive cycle...")
            OperationQueue.main.addOperation(self.receive)
        }
    }
    
    public var connectionHandler: ((Bool) -> Void)?
    
    public func connect(connectionHandler: ((Bool) -> Void)? = nil) {
        switch connectionState {
        case .stopped:
            connectionState = .reconnecting(0)
        case .reconnecting(let count) where count > 0:
            return
        default:
            break
        }
        
        startTask(connectionHandler: connectionHandler)
    }
    
    private func startTask(timeout: Double = 10, connectionHandler: ((Bool) -> Void)? = nil){
        
        if let task = self.task {
            task.cancel(with: .goingAway, reason: "Initailizing new connection".data(using: .utf8))
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        self.task = self.session.webSocketTask(with: url)
        
        if let connectionHandler = connectionHandler {
            self.connectionHandler = connectionHandler
        }
        
        self.task!.resume()
    }

    public func disconnect() {
        connectionState = .stopped
        self.task?.cancel(with: .normalClosure, reason: nil)
    }
    
    var taskScheduled = false
    
    private func scheduleReconnect(){
        print("[connectionState] \(connectionState)")
        
        switch connectionState {
        case .reconnecting(let retryCount):
            let nextCount = retryCount + 1
            print("[WebSocketClient] reconnecting: \(nextCount)")
            connectionState = .reconnecting(nextCount)
            
            guard !taskScheduled else {return}
            
            taskScheduled = true
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(retryCount * 5))) {
                //self.cancelTask()
                
                guard self.connected else { return }
                
                self.task?.cancel(with: .noStatusReceived, reason: "attempting reconnect".data(using: .utf8))
                self.startTask(timeout: Double(nextCount * 5))
                self.taskScheduled = false
            }
        default:
            return
        }
    }
    
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?){
        print("Errored!")
        self.connected = false
        scheduleReconnect() // MARK: - Schedule Reconnect
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Connected! - \(String(describing: `protocol`))")
        self.connected = true
        
        switch connectionState {
        case .reconnecting(_):
            connectionState = .reconnecting(0)
        default:
            break
        }
        
        defer {
            self.reperformSubscriptions()
        }
        
        OperationQueue.main.addOperation(self.receive)
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        
        if let reason = reason {
            print("Disconnected! \(closeCode) - \(String(data: reason, encoding: .utf8)!)")

        }else{
            print("Disconnected! \(closeCode)")

        }
        
        self.connected = false
        
        scheduleReconnect() // MARK: - Schedule Reconnect
    }
    
    public struct Response {
        public let topic: String
        public var subject: String?
        public let payload: Json
    }
    
}

public extension Result {
    var success: Success? {
        switch self {
        case .success(let success):
            return success
        default:
            return nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
}

public extension Result where Success == URLSessionWebSocketTask.Message {
    
    var successTuple: (string: String?, data: Data?) {
        switch self {
        case .success(let success):
            switch success {
            case .string(let val):
                return (string: val, data: nil)
            case .data(let data):
                return (string: nil, data: data)
            @unknown default:
                fatalError()
            }
        default:
            return (string: nil, data: nil)
        }
    }
    
    var successString: String? {
        return successTuple.string
    }
    
    var successData: Data? {
        return successTuple.data ?? successString?.data(using: .utf8)
    }
    
    var successJson: Json? {
        guard let data = successData else  { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? Json
    }
    
    var successResponse: WebSocketClient.Response? {
        guard let data = successJson,
            let topicUrl = data["topic"] as? String,
            let url = URLComponents(string: topicUrl),
            let body = data["data"] as? Json
            else { return nil }
        
        var subjectQ = url.queryItems?.first(where: { $0.name == "subject" })
        
        return WebSocketClient.Response(topic: url.path, subject: subjectQ?.value, payload: body)
    }
}
