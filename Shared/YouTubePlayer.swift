//
//  YouTubePlayer.swift
//  Joli
//
//  Created by Anthony Chinwo on 31/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//
//
//  VideoPlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

import UIKit
import WebKit
import SwiftUI

public enum YouTubePlayerState: String {
    case Unstarted = "-1"
    case Ended = "0"
    case Playing = "1"
    case Paused = "2"
    case Buffering = "3"
    case Queued = "4"
}

public enum YouTubePlayerEvents: String {
    case YouTubeIframeAPIReady = "onYouTubeIframeAPIReady"
    case Ready = "onReady"
    case StateChange = "onStateChange"
    case PlaybackQualityChange = "onPlaybackQualityChange"
}

public enum YouTubePlaybackQuality: String {
    case Small = "small"
    case Medium = "medium"
    case Large = "large"
    case HD720 = "hd720"
    case HD1080 = "hd1080"
    case HighResolution = "highres"
}

public protocol YouTubePlayerDelegate: AnyObject {
    func playerReady(_ videoPlayer: YouTubePlayerView)
    func playerStateChanged(_ videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
    func playerQualityChanged(_ videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
}

// Make delegate methods optional by providing default implementations
public extension YouTubePlayerDelegate {
    
    func playerReady(_ videoPlayer: YouTubePlayerView) {}
    func playerStateChanged(_ videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState) {}
    func playerQualityChanged(_ videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality) {}
    
}

private extension URL {
    func queryStringComponents() -> [String: AnyObject] {
        
        var dict = [String: AnyObject]()
        
        // Check for query string
        if let query = self.query {
            
            // Loop through pairings (separated by &)
            for pair in query.components(separatedBy: "&") {
                
                // Pull key, val from from pair parts (separated by =) and set dict[key] = value
                let components = pair.components(separatedBy: "=")
                if (components.count > 1) {
                    dict[components[0]] = components[1] as AnyObject?
                }
            }
            
        }
        
        return dict
    }
}

public func videoIDFromYouTubeURL(_ videoURL: URL) -> String? {
    if videoURL.pathComponents.count > 1 && (videoURL.host?.hasSuffix("youtu.be"))! {
        return videoURL.pathComponents[1]
    } else if videoURL.pathComponents.contains("embed") {
        return videoURL.pathComponents.last
    }
    let url = videoURL.queryStringComponents()["v"] as? String
    
    print("Video: \(url)")
    return url
}

/** Embed and control YouTube videos */
open class YouTubePlayerView: UIView, WKNavigationDelegate {
    
    public typealias YouTubePlayerParameters = [String: AnyObject]
    public var baseURL = "about:blank"
    
    fileprivate var webView: WKWebView!
    
    /** The readiness of the player */
    fileprivate(set) open var ready = false
    
    /** The current state of the video player */
    fileprivate(set) open var playerState = YouTubePlayerState.Unstarted
    
    /** The current playback quality of the video player */
    fileprivate(set) open var playbackQuality = YouTubePlaybackQuality.Small
    
    /** Used to configure the player */
    open var playerVars = YouTubePlayerParameters()
    
    /** Used to respond to player events */
    open weak var delegate: YouTubePlayerDelegate?
    
    
    // MARK: Various methods for initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        buildWebView(playerParameters())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildWebView(playerParameters())
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        print("[YouTubePlayerView#layoutSubviews] before bounds=\(bounds)")
        // Remove web view in case it's within view hierarchy, reset frame, add as subview
        webView.removeFromSuperview()
        webView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height:  UIScreen.main.bounds.width / 1.2)
        print("[YouTubePlayerView#layoutSubviews] after bounds=\(bounds)")
        addSubview(webView)
    }
    
    
    // MARK: Web view initialization
    
    fileprivate func buildWebView(_ parameters: [String: AnyObject]) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaPlaybackRequiresUserAction = false
        configuration.preferences.javaScriptEnabled = true
        
        webView = WKWebView(frame: frame, configuration: configuration)
        print("Webview frame: \(frame)")
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
    }
    
    
    // MARK: Load player
    
    open func loadVideoURL(_ videoURL: URL) {
        if let videoID = videoIDFromYouTubeURL(videoURL) {
            loadVideoID(videoID)
        }
    }
    
    open func loadVideoID(_ videoID: String) {
        var playerParams = playerParameters()
        playerParams["videoId"] = videoID as AnyObject?
        
        loadWebViewWithParameters(playerParams)
    }
    
    open func loadPlaylistID(_ playlistID: String) {
        // No videoId necessary when listType = playlist, list = [playlist Id]
        playerVars["listType"] = "playlist" as AnyObject?
        playerVars["list"] = playlistID as AnyObject?
        
        loadWebViewWithParameters(playerParameters())
    }
    
    
    // MARK: Player controls
    
    open func mute() {
        evaluatePlayerCommand("mute()")
    }
    
    open func unMute() {
        evaluatePlayerCommand("unMute()")
    }
    
    open func play() {
        evaluatePlayerCommand("playVideo()")
    }
    
    open func pause() {
        evaluatePlayerCommand("pauseVideo()")
    }
    
    open func stop() {
        evaluatePlayerCommand("stopVideo()")
    }
    
    open func clear() {
        evaluatePlayerCommand("clearVideo()")
    }
    
    open func seekTo(_ seconds: Float, seekAhead: Bool) {
        evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
    }
    
    open func getDuration(completion: ((Double?) -> Void)? = nil) {
        evaluatePlayerCommand("getDuration()") { (result) in
            completion?(result as? Double)
        }
    }
    
    open func getCurrentTime(completion: ((Double?) -> Void)? = nil) {
        evaluatePlayerCommand("getCurrentTime()") { (result) in
            completion?(result as? Double)
        }
    }
    
    // MARK: Playlist controls
    
    open func previousVideo() {
        evaluatePlayerCommand("previousVideo()")
    }
    
    open func nextVideo() {
        evaluatePlayerCommand("nextVideo()")
    }
    
    fileprivate func evaluatePlayerCommand(_ command: String, completion: ((Any?) -> Void)? = nil) {
        let fullCommand = "player." + command + ";"
        webView.evaluateJavaScript(fullCommand) { (result, error) in
            if let error = error, (error as NSError).code != 5 { // NOTE: ignore :Void return
                print(error)
                printLog("Error executing javascript")
                completion?(nil)
            }
            
            completion?(result)
        }
    }
    
    
    // MARK: Player setup
    
    fileprivate func loadWebViewWithParameters(_ parameters: YouTubePlayerParameters) {
        
        // Get HTML from player file in bundle
        let rawHTMLString = htmlStringWithFilePath(playerHTMLPath())!
        
        // Get JSON serialized parameters string
        let jsonParameters = serializedJSON(parameters as AnyObject)!
        
        // Replace %@ in rawHTMLString with jsonParameters string
        let htmlString = rawHTMLString.replacingOccurrences(of: "%@", with: jsonParameters)
        print("JOSN: \(jsonParameters)")
        
        // Load HTML in web view
        webView.loadHTMLString(htmlString, baseURL: URL(string: baseURL))
    }
    
    fileprivate func playerHTMLPath() -> String {
        return Bundle(for: YouTubePlayerView.self).path(forResource: "YTPlayer", ofType: "html")!
    }
    
    fileprivate func htmlStringWithFilePath(_ path: String) -> String? {
        
        do {
            
            // Get HTML string from path
            let htmlString = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
            
            return htmlString as String
            
        } catch _ {
            
            // Error fetching HTML
            printLog("Lookup error: no HTML file found for path")
            
            return nil
        }
    }
    
    
    // MARK: Player parameters and defaults
    
    fileprivate func playerParameters() -> YouTubePlayerParameters {
        
        return [
            "height": "100%" as AnyObject,
            "width": "100%" as AnyObject,
            "events": playerCallbacks() as AnyObject,
            "playerVars": playerVars as AnyObject
        ]
    }
    
    fileprivate func playerCallbacks() -> YouTubePlayerParameters {
        return [
            "onReady": "onReady" as AnyObject,
            "onStateChange": "onStateChange" as AnyObject,
            "onPlaybackQualityChange": "onPlaybackQualityChange" as AnyObject,
            "onError": "onPlayerError" as AnyObject
        ]
    }
    
    fileprivate func serializedJSON(_ object: AnyObject) -> String? {
        
        do {
            // Serialize to JSON string
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: JSONSerialization.WritingOptions.prettyPrinted)
            
            // Succeeded
            return NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue) as String?
            
        } catch let jsonError {
            
            // JSON serialization failed
            print(jsonError)
            printLog("Error parsing JSON")
            
            return nil
        }
    }
    
    
    // MARK: JS Event Handling
    
    fileprivate func handleJSEvent(_ eventURL: URL) {
        
        // Grab the last component of the queryString as string
        let data: String? = eventURL.queryStringComponents()["data"] as? String
        
        if let host = eventURL.host, let event = YouTubePlayerEvents(rawValue: host) {
            
            // Check event type and handle accordingly
            switch event {
                case .YouTubeIframeAPIReady:
                    ready = true
                    break
                    
                case .Ready:
                    delegate?.playerReady(self)
                    
                    break
                    
                case .StateChange:
                    if let newState = YouTubePlayerState(rawValue: data!) {
                        playerState = newState
                        delegate?.playerStateChanged(self, playerState: newState)
                    }
                    
                    break
                    
                case .PlaybackQualityChange:
                    if let newQuality = YouTubePlaybackQuality(rawValue: data!) {
                        playbackQuality = newQuality
                        delegate?.playerQualityChanged(self, playbackQuality: newQuality)
                    }
                    
                    break
            }
        }
    }
    
    
    // MARK: WKNavigationDelegate
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var action: WKNavigationActionPolicy?
        defer {
            decisionHandler(action ?? .allow)
        }
        
        guard let url = navigationAction.request.url else { return }
        
        if url.scheme == "ytplayer" {
            handleJSEvent(url)
            action = .cancel
        }
    }
}

private func printLog(_ strings: CustomStringConvertible...) {
    let toPrint = ["[YouTubePlayer]"] + strings
    print(toPrint, separator: " ", terminator: "\n")
}

// MARK : - SwiftUI Youtube Player

enum playerCommandToExecute {
    case loadNewVideo
    case play
    case pause
    case forward
    case backward
    case stop
    case idle
}

// 2
class YouTubeControlState: ObservableObject {
    
    // 3
    @Published var videoID: String? // = "qRC4Vk6kisY"
    {
        // 4
        didSet {
            self.executeCommand = .loadNewVideo
        }
    }
    
    public init(_ videoId: String? = nil){
        self._videoID = Published(initialValue: videoId)
    }
    
    // 5
    @Published var videoState: playerCommandToExecute = .loadNewVideo
    
    // 6
    @Published var executeCommand: playerCommandToExecute = .idle
    
    // 7
    func playPauseButtonTapped() {
        if videoState == .play {
            pauseVideo()
        } else if videoState == .pause {
            playVideo()
        } else {
            print("Unknown player state, attempting playing")
            playVideo()
        }
    }
    
    // 8
    func playVideo() {
        executeCommand = .play
    }
    
    func pauseVideo() {
        executeCommand = .pause
    }
    
    func forward() {
        executeCommand = .forward
    }
    
    func backward() {
        executeCommand = .backward
    }
}

final class YouTubeView: UIViewRepresentable {
    
    typealias UIViewType = YouTubePlayerView
    
    let playerState: YouTubeControlState
    @Binding var frame: CGSize
    
    init(playerState: YouTubeControlState, frame: Binding<CGSize>) {
        self.playerState = playerState
        self._frame = frame
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(playerState: playerState)
    }
    
    func makeUIView(context: Context) -> UIViewType {
        let playerVars = [
            "controls": "1",
            "playsinline": "1",
            "autohide": "0",
            "autoplay": "0",
            "fs": "1",
            "rel": "0",
            "loop": "1",
            "enablejsapi": "1",
            "modestbranding": "1"
        ]
        
        let ytVideo = YouTubePlayerView()
        
        ytVideo.playerVars = playerVars as YouTubePlayerView.YouTubePlayerParameters
        ytVideo.delegate = context.coordinator
        print("[Youtube] made UI")
        return ytVideo
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
        guard let videoID = playerState.videoID else {
            print("[Youtube] updateUIView no video")
            return
        }
        
        print("[Youtube] updateUIView: \(playerState.executeCommand) - \(uiView.frame) - \(frame)")
        
        if !(playerState.executeCommand == .idle) && uiView.ready {
            switch playerState.executeCommand {
                case .loadNewVideo:
                    playerState.executeCommand = .idle
                    uiView.loadVideoID(videoID)
                case .play:
                    playerState.executeCommand = .idle
                    uiView.play()
                case .pause:
                    playerState.executeCommand = .idle
                    uiView.pause()
                case .forward:
                    playerState.executeCommand = .idle
                    uiView.getCurrentTime { (time) in
                        guard let time = time else {return}
                        uiView.seekTo(Float(time) + 10, seekAhead: true)
                    }
                case .backward:
                    playerState.executeCommand = .idle
                    uiView.getCurrentTime { (time) in
                        guard let time = time else {return}
                        uiView.seekTo(Float(time) - 10, seekAhead: true)
                    }
                default:
                    playerState.executeCommand = .idle
                    print("\(playerState.executeCommand) not yet implemented")
            }
        } else if !uiView.ready {
            uiView.loadVideoID(videoID)
        }
        
    }
    
    class Coordinator: YouTubePlayerDelegate {
        @ObservedObject var playerState: YouTubeControlState
        
        init(playerState: YouTubeControlState) {
            self.playerState = playerState
        }
        
        func playerReady(_ videoPlayer: YouTubePlayerView) {
            videoPlayer.play()
            playerState.videoState = .play
        }
        
        func playerStateChanged(_ videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState) {
            
            switch playerState {
                case .Playing:
                    self.playerState.videoState = .play
                case .Paused, .Buffering, .Unstarted:
                    self.playerState.videoState = .pause
                case .Ended:
                    self.playerState.videoState = .stop
                    //self.playerState.videoID = loadNextVideo()
                default:
                    print("\(playerState) not implemented")
            }
        }
    }
}
