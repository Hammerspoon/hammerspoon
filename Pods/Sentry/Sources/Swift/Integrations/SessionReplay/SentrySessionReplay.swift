import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@objc
@_spi(Private) public protocol SentryReplayDisplayLinkWrapper {
    func isRunning() -> Bool
    func invalidate()
    func link(withTarget: Any, selector: Selector)
}

// swiftlint:disable type_body_length
@objcMembers
@_spi(Private) public class SentrySessionReplay: NSObject {
    public private(set) var isFullSession = false
    public private(set) var sessionReplayId: SentryId?

    private var urlToCache: URL?
    private var rootView: UIView?
    private var lastScreenShot: Date?
    private var videoSegmentStart: Date?
    private var sessionStart: Date?
    private var imageCollection: [UIImage] = []
    private weak var delegate: SentrySessionReplayDelegate?
    private var currentSegmentId = 0
    private var processingScreenshot = false
    private var reachedMaximumDuration = false
    private(set) var isSessionPaused = false
    
    private let replayOptions: SentryReplayOptions
    private let replayMaker: SentryReplayVideoMaker
    private let displayLink: SentryReplayDisplayLinkWrapper
    private let dateProvider: SentryCurrentDateProvider
    private let touchTracker: SentryTouchTracker?
    private let lock = NSLock()
    public var replayTags: [String: Any]?
    
    var isRunning: Bool {
        displayLink.isRunning()
    }
    
    public var screenshotProvider: SentryViewScreenshotProvider
    public var breadcrumbConverter: SentryReplayBreadcrumbConverter
    
    public init(
        replayOptions: SentryReplayOptions,
        replayFolderPath: URL,
        screenshotProvider: SentryViewScreenshotProvider,
        replayMaker: SentryReplayVideoMaker,
        breadcrumbConverter: SentryReplayBreadcrumbConverter,
        touchTracker: SentryTouchTracker?,
        dateProvider: SentryCurrentDateProvider,
        delegate: SentrySessionReplayDelegate,
        displayLinkWrapper: SentryReplayDisplayLinkWrapper
    ) {
        self.replayOptions = replayOptions
        self.dateProvider = dateProvider
        self.delegate = delegate
        self.screenshotProvider = screenshotProvider
        self.displayLink = displayLinkWrapper
        self.urlToCache = replayFolderPath
        self.replayMaker = replayMaker
        self.breadcrumbConverter = breadcrumbConverter
        self.touchTracker = touchTracker
    }
    
    deinit { displayLink.invalidate() }

    public func start(rootView: UIView, fullSession: Bool) {
        SentrySDKLog.debug("[Session Replay] Starting session replay with full session: \(fullSession)")
        guard !isRunning else { 
            SentrySDKLog.debug("[Session Replay] Session replay is already running, not starting again")
            return 
        }
        displayLink.link(withTarget: self, selector: #selector(newFrame(_:)))
        self.rootView = rootView
        lastScreenShot = dateProvider.date()
        videoSegmentStart = nil
        currentSegmentId = 0
        sessionReplayId = SentryId()
        imageCollection = []

        if fullSession {
            startFullReplay()
        }
    }

    private func startFullReplay() {
        SentrySDKLog.debug("[Session Replay] Starting full session replay")
        sessionStart = lastScreenShot
        isFullSession = true
        guard let sessionReplayId = sessionReplayId else { return }
        delegate?.sessionReplayStarted(replayId: sessionReplayId)
    }

    public func pauseSessionMode() {
        SentrySDKLog.debug("[Session Replay] Pausing session mode")
        lock.lock()
        defer { lock.unlock() }
        
        self.isSessionPaused = true
        self.videoSegmentStart = nil
    }
    
    public func pause() {
        SentrySDKLog.debug("[Session Replay] Pausing session")
        lock.lock()
        defer { lock.unlock() }
        
        displayLink.invalidate()
        if isFullSession {
            prepareSegmentUntil(date: dateProvider.date())
        }
        isSessionPaused = false
    }

    public func resume() {
        SentrySDKLog.debug("[Session Replay] Resuming session")
        lock.lock()
        defer { lock.unlock() }
        
        if isSessionPaused {
            isSessionPaused = false
            return
        }
        
        guard !reachedMaximumDuration else { 
            SentrySDKLog.warning("[Session Replay] Reached maximum duration, not resuming")
            return 
        }
        guard !isRunning else { 
            SentrySDKLog.debug("[Session Replay] Session is already running, not resuming")
            return 
        }
        
        videoSegmentStart = nil
        displayLink.link(withTarget: self, selector: #selector(newFrame(_:)))
    }

    public func captureReplayFor(event: Event) {
        SentrySDKLog.debug("[Session Replay] Capturing replay for event: \(event)")
        guard isRunning else { 
            SentrySDKLog.debug("[Session Replay] Session replay is not running, not capturing replay")
            return 
        }

        if isFullSession {
            SentrySDKLog.info("[Session Replay] Session replay is in full session mode, setting event context")
            setEventContext(event: event)
            return
        }

        guard (event.error != nil || event.exceptions?.isEmpty == false) && captureReplay() else { 
            SentrySDKLog.debug("[Session Replay] Not capturing replay, reason: event is not an error or exceptions are empty")
            return
        }
        
        setEventContext(event: event)
    }

    @discardableResult
    public func captureReplay() -> Bool {
        guard isRunning else {
            SentrySDKLog.debug("[Session Replay] Session replay is not running, not capturing replay")
            return false 
        }
        guard !isFullSession else { 
            SentrySDKLog.debug("[Session Replay] Session replay is full, not capturing replay")
            return true 
        }

        guard delegate?.sessionReplayShouldCaptureReplayForError() == true else {
            SentrySDKLog.debug("[Session Replay] Not capturing replay, reason: delegate should not capture replay")
            return false
        }

        startFullReplay()
        let replayStart = dateProvider.date().addingTimeInterval(-replayOptions.errorReplayDuration - (Double(replayOptions.frameRate) / 2.0))

        createAndCaptureInBackground(startedAt: replayStart, replayType: .buffer)
        return true
    }

    private func setEventContext(event: Event) {
        SentrySDKLog.debug("[Session Replay] Setting event context")
        guard let sessionReplayId = sessionReplayId, event.type != "replay_video" else { 
            SentrySDKLog.debug("[Session Replay] Not setting event context, reason: session replay id is nil or event type is replay_video")
            return 
        }

        var context = event.context ?? [:]
        context["replay"] = ["replay_id": sessionReplayId.sentryIdString]
        event.context = context

        var tags = ["replayId": sessionReplayId.sentryIdString]
        if let eventTags = event.tags {
            tags.merge(eventTags) { (_, new) in new }
        }
        event.tags = tags
    }

    @objc 
    private func newFrame(_ sender: CADisplayLink) {
        guard let lastScreenShot = lastScreenShot, isRunning &&
                !(isFullSession && isSessionPaused) //If replay is in session mode but it is paused we dont take screenshots
        else { return }

        let now = dateProvider.date()
        
        if let sessionStart = sessionStart, isFullSession && now.timeIntervalSince(sessionStart) > replayOptions.maximumDuration {
            SentrySDKLog.debug("[Session Replay] Reached maximum duration, pausing session")
            reachedMaximumDuration = true
            pause()
            return
        }

        if now.timeIntervalSince(lastScreenShot) >= Double(1 / replayOptions.frameRate) {
            takeScreenshot()
            self.lastScreenShot = now
            
            if videoSegmentStart == nil {
                videoSegmentStart = now
            } else if let videoSegmentStart = videoSegmentStart, isFullSession &&
                        now.timeIntervalSince(videoSegmentStart) >= replayOptions.sessionSegmentDuration {
                prepareSegmentUntil(date: now)
            }
        }
    }

    private func prepareSegmentUntil(date: Date) {
        SentrySDKLog.debug("[Session Replay] Preparing segment until date: \(date)")
        guard var pathToSegment = urlToCache?.appendingPathComponent("segments") else { 
            SentrySDKLog.debug("[Session Replay] Not preparing segment, reason: could not create path to segments folder")
            return 
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: pathToSegment.path) {
            do {
                try fileManager.createDirectory(atPath: pathToSegment.path, withIntermediateDirectories: true, attributes: nil)
                SentrySDKLog.debug("[Session Replay] Created segments folder at path: \(pathToSegment.path)")
            } catch {
                SentrySDKLog.debug("Can't create session replay segment folder. Error: \(error.localizedDescription)")
                return
            }
        }

        pathToSegment = pathToSegment.appendingPathComponent("\(currentSegmentId).mp4")
        let segmentStart = videoSegmentStart ?? dateProvider.date().addingTimeInterval(-replayOptions.sessionSegmentDuration)

        createAndCaptureInBackground(startedAt: segmentStart, replayType: .session)
    }

    private func createAndCaptureInBackground(startedAt: Date, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Creating replay video started at date: \(startedAt), replayType: \(replayType)")
        // Creating a video is computationally expensive, therefore perform it on a background queue.
        self.replayMaker.createVideoInBackgroundWith(beginning: startedAt, end: self.dateProvider.date()) { videos in
            SentrySDKLog.debug("[Session Replay] Created replay video with \(videos.count) segments")
            for video in videos {
                self.processNewlyAvailableSegment(videoInfo: video, replayType: replayType)
            }
            SentrySDKLog.debug("[Session Replay] Finished processing replay video with \(videos.count) segments")
        }
    }

    private func processNewlyAvailableSegment(videoInfo: SentryVideoInfo, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Processing new segment available for replayType: \(replayType), videoInfo: \(videoInfo)")
        guard let sessionReplayId = sessionReplayId else {
            SentrySDKLog.warning("[Session Replay] No session replay ID available, ignoring segment.")
            return
        }
        captureSegment(segment: currentSegmentId, video: videoInfo, replayId: sessionReplayId, replayType: replayType)
        replayMaker.releaseFramesUntil(videoInfo.end)
        videoSegmentStart = videoInfo.end
        currentSegmentId++
        SentrySDKLog.debug("[Session Replay] Processed segment, incrementing currentSegmentId to: \(currentSegmentId)")
    }
    
    private func captureSegment(segment: Int, video: SentryVideoInfo, replayId: SentryId, replayType: SentryReplayType) {
        SentrySDKLog.debug("[Session Replay] Capturing segment: \(segment), replayId: \(replayId), replayType: \(replayType)")
        let replayEvent = SentryReplayEvent(eventId: replayId, replayStartTimestamp: video.start, replayType: replayType, segmentId: segment)
        
        replayEvent.sdk = self.replayOptions.sdkInfo
        replayEvent.timestamp = video.end
        replayEvent.urls = video.screens
        
        let breadcrumbs = delegate?.breadcrumbsForSessionReplay() ?? []

        var events = convertBreadcrumbs(breadcrumbs: breadcrumbs, from: video.start, until: video.end)
        if let touchTracker = touchTracker {
            SentrySDKLog.debug("[Session Replay] Adding touch tracker events")
            events.append(contentsOf: touchTracker.replayEvents(from: videoSegmentStart ?? video.start, until: video.end))
            touchTracker.flushFinishedEvents()
        }
        
        if segment == 0 {
            SentrySDKLog.debug("[Session Replay] Adding options event to segment 0")
            if let customOptions = replayTags {
                events.append(SentryRRWebOptionsEvent(timestamp: video.start, customOptions: customOptions))
            } else {
                events.append(SentryRRWebOptionsEvent(timestamp: video.start, options: self.replayOptions))
            }
        }
        
        let recording = SentryReplayRecording(segmentId: segment, video: video, extraEvents: events)

        delegate?.sessionReplayNewSegment(replayEvent: replayEvent, replayRecording: recording, videoUrl: video.path)

        do {
            try FileManager.default.removeItem(at: video.path)
            SentrySDKLog.debug("[Session Replay] Deleted replay segment from disk")
        } catch {
            SentrySDKLog.debug("[Session Replay] Could not delete replay segment from disk: \(error)")
        }
    }
    
    private func convertBreadcrumbs(breadcrumbs: [Breadcrumb], from: Date, until: Date) -> [any SentryRRWebEventProtocol] {
        SentrySDKLog.debug("[Session Replay] Converting breadcrumbs from: \(from) until: \(until)")
        var filteredResult: [Breadcrumb] = []
        var lastNavigationTime: Date = from.addingTimeInterval(-1)
        
        for breadcrumb in breadcrumbs {
            guard let time = breadcrumb.timestamp, time >= from && time < until else { 
                continue
            }
            
            // If it's a "navigation" breadcrumb, check the timestamp difference from the previous breadcrumb.
            // Skip any breadcrumbs that have occurred within 50ms of the last one,
            // as these represent child view controllers that don’t need their own navigation breadcrumb.
            if breadcrumb.type == "navigation" {
                if time.timeIntervalSince(lastNavigationTime) < 0.05 { continue }
                lastNavigationTime = time
            }
            filteredResult.append(breadcrumb)
        }
        
        return filteredResult.compactMap(breadcrumbConverter.convert(from:))
    }
    
    private func takeScreenshot() {
        guard let rootView = rootView, !processingScreenshot else { 
            SentrySDKLog.debug("[Session Replay] Not taking screenshot, reason: root view is nil or processing screenshot")
            return 
        }
        SentrySDKLog.debug("[Session Replay] Taking screenshot of root view: \(rootView)")
        
        lock.lock()
        guard !processingScreenshot else {
            SentrySDKLog.debug("[Session Replay] Not taking screenshot, reason: processing screenshot")
            lock.unlock()
            return
        }
        processingScreenshot = true
        lock.unlock()
        
        SentrySDKLog.debug("[Session Replay] Getting screenshot from screenshot provider")
        let timestamp = dateProvider.date()
        let screenName = delegate?.currentScreenNameForSessionReplay()
        screenshotProvider.image(view: rootView) { [weak self] screenshot in
            self?.newImage(timestamp: timestamp, maskedViewImage: screenshot, forScreen: screenName)
        }
    }

    private func newImage(timestamp: Date, maskedViewImage: UIImage, forScreen screen: String?) {
        SentrySDKLog.debug("[Session Replay] New frame available, for screen: \(screen ?? "nil")")
        lock.synchronized {
            processingScreenshot = false
            replayMaker.addFrameAsync(timestamp: timestamp, maskedViewImage: maskedViewImage, forScreen: screen)
        }
    }
}
// swiftlint:enable type_body_length

#endif
