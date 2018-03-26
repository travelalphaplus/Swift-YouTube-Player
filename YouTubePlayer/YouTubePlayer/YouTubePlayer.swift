//
//  VideoPlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

import UIKit

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

public protocol YouTubePlayerDelegate: class {
    func playerReady(videoPlayer: YouTubePlayerView)
    func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
    func playerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality)
}

// Make delegate methods optional by providing default implementations
public extension YouTubePlayerDelegate {
    
    func playerReady(videoPlayer: YouTubePlayerView) {}
    func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState) {}
    func playerQualityChanged(videoPlayer: YouTubePlayerView, playbackQuality: YouTubePlaybackQuality) {}
    
}

private extension NSURL {
    func queryStringComponents() -> [String: AnyObject] {
        
        var dict = [String: AnyObject]()
        
        // Check for query string
        if let query = self.query {
            
            // Loop through pairings (separated by &)
            for pair in query.componentsSeparatedByString("&") {
                
                // Pull key, val from from pair parts (separated by =) and set dict[key] = value
                let components = pair.componentsSeparatedByString("=")
                if (components.count > 1) {
                    dict[components[0]] = components[1] as AnyObject?
                }
            }
            
        }
        
        return dict
    }
}

public func videoIDFromYouTubeURL(videoURL: NSURL) -> String? {
    
    let pathComponents = videoURL.pathComponents ?? []
    let host = videoURL.host ?? ""
    
    if pathComponents.count > 1 && host.hasSuffix("youtu.be") {
        return pathComponents[1]
    } else if pathComponents.contains("embed") {
        return pathComponents.last
    }
    return videoURL.queryStringComponents()["v"] as? String
}

/** Embed and control YouTube videos */
public class YouTubePlayerView: UIView, UIWebViewDelegate {
    
    public typealias YouTubePlayerParameters = [String: AnyObject]
    public var baseURL = "about:blank"
    
    var webView: UIWebView!
    
    /** The readiness of the player */
    public var ready = false
    
    /** The current state of the video player */
    public var playerState = YouTubePlayerState.Unstarted
    
    /** The current playback quality of the video player */
    public var playbackQuality = YouTubePlaybackQuality.Small
    
    /** Used to configure the player */
    public var playerVars = YouTubePlayerParameters()
    
    /** Used to respond to player events */
    weak var delegate: YouTubePlayerDelegate?
    
    
    // MARK: Various methods for initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        buildWebView(playerParameters())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildWebView(playerParameters())
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        // Remove web view in case it's within view hierarchy, reset frame, add as subview
        webView.removeFromSuperview()
        webView.frame = bounds
        addSubview(webView)
    }
    
    
    // MARK: Web view initialization
    
    func buildWebView(parameters: [String: AnyObject]) {
        webView = UIWebView()
        webView.opaque = false
        webView.backgroundColor = UIColor.clearColor()
        webView.allowsInlineMediaPlayback = true
        webView.mediaPlaybackRequiresUserAction = false
        webView.delegate = self
        webView.scrollView.scrollEnabled = false
    }
    
    
    // MARK: Load player
    
    public func loadVideoURL(videoURL: NSURL) {
        if let videoID = videoIDFromYouTubeURL(videoURL) {
            loadVideoID(videoID)
        }
    }
    
    public func loadVideoID(videoID: String) {
        var playerParams = playerParameters()
        playerParams["videoId"] = videoID as AnyObject?
        
        loadWebViewWithParameters(playerParams)
    }
    
    public func loadPlaylistID(playlistID: String) {
        // No videoId necessary when listType = playlist, list = [playlist Id]
        playerVars["listType"] = "playlist" as AnyObject?
        playerVars["list"] = playlistID as AnyObject?
        
        loadWebViewWithParameters(playerParameters())
    }
    
    
    // MARK: Player controls
    
    public func mute() {
        evaluatePlayerCommand("mute()")
    }
    
    public func unMute() {
        evaluatePlayerCommand("unMute()")
    }
    
    public func play() {
        evaluatePlayerCommand("playVideo()")
    }
    
    public func pause() {
        evaluatePlayerCommand("pauseVideo()")
    }
    
    public func stop() {
        evaluatePlayerCommand("stopVideo()")
    }
    
    public func clear() {
        evaluatePlayerCommand("clearVideo()")
    }
    
    public func seekTo(seconds: Float, seekAhead: Bool) {
        evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
    }
    
    public func getDuration() -> String? {
        return evaluatePlayerCommand("getDuration()")
    }
    
    public func getCurrentTime() -> String? {
        return evaluatePlayerCommand("getCurrentTime()")
    }
    
    // MARK: Playlist controls
    
    public func previousVideo() {
        evaluatePlayerCommand("previousVideo()")
    }
    
    public func nextVideo() {
        evaluatePlayerCommand("nextVideo()")
    }
    
    func evaluatePlayerCommand(command: String) -> String? {
        let fullCommand = "player." + command + ";"
        return webView.stringByEvaluatingJavaScriptFromString(fullCommand)
    }
    
    
    // MARK: Player setup
    
    func loadWebViewWithParameters(parameters: YouTubePlayerParameters) {
        
        // Get HTML from player file in bundle
        let rawHTMLString = htmlStringWithFilePath(playerHTMLPath())!
        
        // Get JSON serialized parameters string
        let jsonParameters = serializedJSON(parameters as AnyObject)!
        
        // Replace %@ in rawHTMLString with jsonParameters string
        let htmlString = rawHTMLString.stringByReplacingOccurrencesOfString("%@", withString: jsonParameters)
        
        // Load HTML in web view
        webView.loadHTMLString(htmlString, baseURL: NSURL(string: baseURL))
    }
    
    func playerHTMLPath() -> String {
        return NSBundle(forClass: YouTubePlayerView.self).pathForResource("YTPlayer", ofType: "html")!
    }
    
    func htmlStringWithFilePath(path: String) -> String? {
        
        do {
            
            // Get HTML string from path
            let htmlString = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            
            return htmlString as String
            
        } catch _ {
            
            // Error fetching HTML
            printLog("Lookup error: no HTML file found for path")
            
            return nil
        }
    }
    
    
    // MARK: Player parameters and defaults
    
    func playerParameters() -> YouTubePlayerParameters {
        
        return [
            "height": "100%" as AnyObject,
            "width": "100%" as AnyObject,
            "events": playerCallbacks() as AnyObject,
            "playerVars": playerVars as AnyObject
        ]
    }
    
    func playerCallbacks() -> YouTubePlayerParameters {
        return [
            "onReady": "onReady" as AnyObject,
            "onStateChange": "onStateChange" as AnyObject,
            "onPlaybackQualityChange": "onPlaybackQualityChange" as AnyObject,
            "onError": "onPlayerError" as AnyObject
        ]
    }
    
    func serializedJSON(object: AnyObject) -> String? {
        
        do {
            // Serialize to JSON string
            let jsonData = try NSJSONSerialization.dataWithJSONObject(object, options: .PrettyPrinted)
            
            // Succeeded
            return NSString(data: jsonData, encoding: NSUTF8StringEncoding) as String?
            
        } catch let jsonError {
            
            // JSON serialization failed
            print(jsonError)
            printLog("Error parsing JSON")
            
            return nil
        }
    }
    
    
    // MARK: JS Event Handling
    
    func handleJSEvent(eventURL: NSURL) {
        
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
    
    
    // MARK: UIWebViewDelegate
    
    public func webView(webView: UIWebView, shouldStartLoadWith request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        let url = request.URL
        
        // Check if ytplayer event and, if so, pass to handleJSEvent
        if let url = url where url.scheme == "ytplayer" { handleJSEvent(url) }
        
        return true
    }
}

private func printLog(strings: CustomStringConvertible...) {
    let toPrint = ["[YouTubePlayer]"] + strings
    print(toPrint, separator: " ", terminator: "\n")
}
