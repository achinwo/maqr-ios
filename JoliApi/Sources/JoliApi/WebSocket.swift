//
//  File.swift
//  
//
//  Created by Anthony Chinwo on 01/11/2019.
//

import Foundation



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

public class WebSocketClient: HttpsHook {
    
    public typealias MessageCallback = (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    
    var session: URLSession!
    var task: URLSessionWebSocketTask?
    public var onMessage: MessageCallback?
    
    public var connectionState = ConnectionState.stopped
    
    public var connected = false {
        didSet {
            self.connectionHandler?(connected)
        }
    }
    public var  url: URL!
    //var queue: OperationQueue = DispatchQueue.global(qos: .background)
    //public var subjects: Set<String> = []
    
    public init(url: URL, onMessage: MessageCallback? = nil) {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        self.url = url
        self.onMessage = onMessage
    }

    public func send(topic: String, payload: Encodable? = nil, headers: HttpMethod.Headers? = nil, completionHandler: ((Error?) -> Void)?){
        let msg = WebSocketMessage(topic: topic, headers: headers ?? [:])
        
        let message = URLSessionWebSocketTask.Message.string(msg.jsonString())
        self.task?.send(message) { error in
            completionHandler?(error)
        }
    }
    
    public func receive(){
        self.task?.receive() { result in
            //print("[result] \(result)")
            
            defer {
                self.onMessage?(result)
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
    
    var connectionHandler: ((Bool) -> Void)?
    
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
        return successTuple.data
    }
    
}
