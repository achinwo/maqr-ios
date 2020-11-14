//
//  Logging.swift
//  JoliPlayground
//
//  Created by Anthony Chinwo on 14/11/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import SwiftyBeaver
import Promises
import Combine
import UIKit
import JoliCore

public extension Array where Element: Persistable {
    
    @discardableResult
    func saveAll(baseUrl: URL, urlSession: URLSession, on: DispatchQueue? = nil) -> Promise<[Element.PersistedType]> {
        guard !isEmpty else {
            return Promise([])
        }
        
        let urlComp = "/api/db/\(Element.PersistedType.className())"
        //"/api/db/\(T.className())", on: DispatchQueue?
        return HttpMethod.Fetch.post(url: urlComp,
                                     dataType: [Element.PersistedType].self,
                                     payload: .jsons(self.map(){ $0.json }),
                                     baseUrl: baseUrl,
                                     urlSession: urlSession,
                                     on: on)
    }
    
}

public class ServerDestination: BaseDestination, ObservableObject {
    
    public var colored: Bool = false {
        didSet {
            if colored {
                // bash font color, first value is intensity, second is color
                // see http://bit.ly/1Otu3Zr & for syntax http://bit.ly/1Tp6Fw9
                // uses the 256-color table from http://bit.ly/1W1qJuH
                levelColor.verbose = "251m"     // silver
                levelColor.debug = "35m"        // green
                levelColor.info = "38m"         // blue
                levelColor.warning = "178m"     // yellow
                levelColor.error = "197m"       // red
            } else {
                levelColor.verbose = ""
                levelColor.debug = ""
                levelColor.info = ""
                levelColor.warning = ""
                levelColor.error = ""
            }
        }
    }
    
    override public var defaultHashValue: Int {return 2}
    let baseUrl: URL
    let urlSession: URLSession
    var bufferedLines: [String] = []
    
    var flushSubject = PassthroughSubject<String, Never>()
    var linePublisherCancel: AnyCancellable? = nil
    
    public init(url: URL, urlSession: URLSession = URLSession.shared) {
        self.baseUrl = url
        self.urlSession = urlSession
        
        super.init()
        
        self.linePublisherCancel = self.flushSubject
            .debounce(for: 2.0, scheduler: DispatchQueue.global(qos: .background))
            .sink(receiveValue: self.flushLines)
    }
    
    public func flushLines(_ line: String? = nil){
        
        guard !self.bufferedLines.isEmpty else {
            return
        }
        
        let lines: [String] = Array(bufferedLines)
        self.bufferedLines = []
        
        let logLines: [LogEntryRecord] = lines.map() { (line: String) -> LogEntryRecord in
            let props: LogEntry.PropertiesDict = [
                LogEntry.CodingKeys.line: line as AnyObject,
                LogEntry.CodingKeys.deviceName: UIDevice.current.name as AnyObject,
                LogEntry.CodingKeys.platform: "ios" as AnyObject,
            ]
            return LogEntryRecord(properties: props)
        }
        
        logLines.saveAll(baseUrl: self.baseUrl, urlSession: self.urlSession)
    }
    
    // append to file. uses full base class functionality
    override public func send(_ level: SwiftyBeaver.Level, msg: String, thread: String,
                              file: String, function: String, line: Int, context: Any? = nil) -> String? {
        let formattedString = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context)
        
        if let str = formattedString {
            _ = writeToEndpoint(str: str)
        }
        return formattedString
    }
    
    /// appends a string as line to a file.
    /// returns boolean about success
    func writeToEndpoint(str: String) -> Promise<String?> {
        self.bufferedLines.append(str)
        self.flushSubject.send(str)
        return Promise(nil) //write(data: data, to: url)
    }
    
}
