import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

enum SessionReplayError: Error {
    case cantCreateReplayDirectory
    case noFramesAvailable
}

@objc
protocol SentrySessionReplayDelegate: NSObjectProtocol {
    func sessionReplayShouldCaptureReplayForError() -> Bool
    func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL)
    func sessionReplayStarted(replayId: SentryId)
    func breadcrumbsForSessionReplay() -> [Breadcrumb]
    func currentScreenNameForSessionReplay() -> String?
}

@objcMembers
class SentrySessionReplay: NSObject {
    private(set) var isFullSession = false
    private(set) var sessionReplayId: SentryId?

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
    private let displayLink: SentryDisplayLinkWrapper
    private let dateProvider: SentryCurrentDateProvider
    private let touchTracker: SentryTouchTracker?
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let lock = NSLock()
    
    var isRunning: Bool {
        displayLink.isRunning()
    }
    
    var screenshotProvider: SentryViewScreenshotProvider
    var breadcrumbConverter: SentryReplayBreadcrumbConverter
    
    init(replayOptions: SentryReplayOptions,
         replayFolderPath: URL,
         screenshotProvider: SentryViewScreenshotProvider,
         replayMaker: SentryReplayVideoMaker,
         breadcrumbConverter: SentryReplayBreadcrumbConverter,
         touchTracker: SentryTouchTracker?,
         dateProvider: SentryCurrentDateProvider,
         delegate: SentrySessionReplayDelegate,
         dispatchQueue: SentryDispatchQueueWrapper,
         displayLinkWrapper: SentryDisplayLinkWrapper) {

        self.dispatchQueue = dispatchQueue
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

    func start(rootView: UIView, fullSession: Bool) {
        guard !isRunning else { return }
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
        sessionStart = lastScreenShot
        isFullSession = true
        guard let sessionReplayId = sessionReplayId else { return }
        delegate?.sessionReplayStarted(replayId: sessionReplayId)
    }

    func pause() {
        lock.lock()
        defer { lock.unlock() }
        
        self.isSessionPaused = true
        self.videoSegmentStart = nil
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        displayLink.invalidate()
        if isFullSession {
            prepareSegmentUntil(date: dateProvider.date())
        }
        isSessionPaused = false
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        
        if isSessionPaused {
            isSessionPaused = false
            return
        }
        
        guard !reachedMaximumDuration else { return }
        guard !isRunning else { return }
        
        videoSegmentStart = nil
        displayLink.link(withTarget: self, selector: #selector(newFrame(_:)))
    }

    func captureReplayFor(event: Event) {
        guard isRunning else { return }

        if isFullSession {
            setEventContext(event: event)
            return
        }

        guard (event.error != nil || event.exceptions?.isEmpty == false)
        && captureReplay() else { return }
        
        setEventContext(event: event)
    }

    @discardableResult
    func captureReplay() -> Bool {
        guard isRunning else { return false }
        guard !isFullSession else { return true }

        guard delegate?.sessionReplayShouldCaptureReplayForError() == true else {
            return false
        }

        startFullReplay()
        let replayStart = dateProvider.date().addingTimeInterval(-replayOptions.errorReplayDuration - (Double(replayOptions.frameRate) / 2.0))

        createAndCapture(startedAt: replayStart, replayType: .buffer)
        return true
    }

    private func setEventContext(event: Event) {
        guard let sessionReplayId = sessionReplayId, event.type != "replay_video" else { return }

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
            reachedMaximumDuration = true
            stop()
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
        guard var pathToSegment = urlToCache?.appendingPathComponent("segments") else { return }
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: pathToSegment.path) {
            do {
                try fileManager.createDirectory(atPath: pathToSegment.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SentryLog.debug("Can't create session replay segment folder. Error: \(error.localizedDescription)")
                return
            }
        }

        pathToSegment = pathToSegment.appendingPathComponent("\(currentSegmentId).mp4")
        let segmentStart = videoSegmentStart ?? dateProvider.date().addingTimeInterval(-replayOptions.sessionSegmentDuration)

        createAndCapture(startedAt: segmentStart, replayType: .session)
    }

    private func createAndCapture(startedAt: Date, replayType: SentryReplayType) {
        //Creating a video is heavy and blocks the thread
        //Since this function is always called in the main thread
        //we dispatch it to a background thread.
        dispatchQueue.dispatchAsync {
            do {
                let videos = try self.replayMaker.createVideoWith(beginning: startedAt, end: self.dateProvider.date())
                for video in videos {
                    self.newSegmentAvailable(videoInfo: video, replayType: replayType)
                }
            } catch {
                SentryLog.debug("Could not create replay video - \(error.localizedDescription)")
            }
        }
    }

    private func newSegmentAvailable(videoInfo: SentryVideoInfo, replayType: SentryReplayType) {
        guard let sessionReplayId = sessionReplayId else { return }
        captureSegment(segment: currentSegmentId, video: videoInfo, replayId: sessionReplayId, replayType: replayType)
        replayMaker.releaseFramesUntil(videoInfo.end)
        videoSegmentStart = videoInfo.end
        currentSegmentId++
    }
    
    private func captureSegment(segment: Int, video: SentryVideoInfo, replayId: SentryId, replayType: SentryReplayType) {
        let replayEvent = SentryReplayEvent(eventId: replayId, replayStartTimestamp: video.start, replayType: replayType, segmentId: segment)
        
        replayEvent.timestamp = video.end
        replayEvent.urls = video.screens
        
        let breadcrumbs = delegate?.breadcrumbsForSessionReplay() ?? []

        var events = convertBreadcrumbs(breadcrumbs: breadcrumbs, from: video.start, until: video.end)
        if let touchTracker = touchTracker {
            events.append(contentsOf: touchTracker.replayEvents(from: video.start, until: video.end))
            touchTracker.flushFinishedEvents()
        }

        let recording = SentryReplayRecording(segmentId: segment, video: video, extraEvents: events)
                
        delegate?.sessionReplayNewSegment(replayEvent: replayEvent, replayRecording: recording, videoUrl: video.path)

        do {
            try FileManager.default.removeItem(at: video.path)
        } catch {
            SentryLog.debug("Could not delete replay segment from disk: \(error.localizedDescription)")
        }
    }

    private func convertBreadcrumbs(breadcrumbs: [Breadcrumb], from: Date, until: Date) -> [any SentryRRWebEventProtocol] {
        return breadcrumbs.filter {
            guard let time = $0.timestamp, time >= from && time < until else { return false }
            return true
        }
        .compactMap(breadcrumbConverter.convert(from:))
    }
    
    private func takeScreenshot() {
        guard let rootView = rootView, !processingScreenshot else { return }
 
        lock.lock()
        guard !processingScreenshot else {
            lock.unlock()
            return
        }
        processingScreenshot = true
        lock.unlock()

        let screenName = delegate?.currentScreenNameForSessionReplay()
        
        screenshotProvider.image(view: rootView, options: replayOptions) { [weak self] screenshot in
            self?.newImage(image: screenshot, forScreen: screenName)
        }
    }

    private func newImage(image: UIImage, forScreen screen: String?) {
        lock.synchronized {
            processingScreenshot = false
            replayMaker.addFrameAsync(image: image, forScreen: screen)
        }
    }
}

#endif
