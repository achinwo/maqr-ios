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


public class WebSocketClient: NSObject {
    
    public typealias MessageCallback = (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    
    var session: URLSession!
    var task: URLSessionWebSocketTask!
    public var onMessage: MessageCallback?
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

    public func send(topic: String, payload: Encodable? = nil, completionHandler: ((Error?) -> Void)?){
        let msg = WebSocketMessage(topic: topic)
        
        let message = URLSessionWebSocketTask.Message.string(msg.jsonString())
        self.task.send(message) { error in
            completionHandler?(error)
        }
    }
    
    public func receive(){
        self.task.receive() { result in
            //print("[result] \(result)")
            
            defer {
                self.onMessage?(result)
            }
            
            if case let Result.failure(error) = result {
                print("[receive] error response aborting...\(error)")
                self.connect()
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
        if task != nil {
            disconnect()
        }
        
        self.task = self.session.webSocketTask(with: url)
        
        if let connectionHandler = connectionHandler {
            self.connectionHandler = connectionHandler
        }
        
        self.task.resume()
    }

    public func disconnect() {
        self.task.cancel(with: .goingAway, reason: "I cancelled".data(using: .utf8))
    }
    
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Connected!")
        self.connected = true
        OperationQueue.main.addOperation(self.receive)
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnected! \(String(data: reason!, encoding: .utf8)!)")
        self.connected = false
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
