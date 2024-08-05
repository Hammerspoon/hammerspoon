import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@objc
protocol SentrySessionReplayDelegate: NSObjectProtocol {
    func sessionReplayIsFullSession() -> Bool
    func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL)
    func sessionReplayStarted(replayId: SentryId)
    func breadcrumbsForSessionReplay() -> [Breadcrumb]
    func currentScreenNameForSessionReplay() -> String?
}

@objcMembers
class SentrySessionReplay: NSObject {
    private(set) var isRunning = false
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
    
    private let replayOptions: SentryReplayOptions
    private let replayMaker: SentryReplayVideoMaker
    private let displayLink: SentryDisplayLinkWrapper
    private let dateProvider: SentryCurrentDateProvider
    private let touchTracker: SentryTouchTracker?
    private let lock = NSLock()
    
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
         displayLinkWrapper: SentryDisplayLinkWrapper) {

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

    func start(rootView: UIView, fullSession: Bool) {
        guard !isRunning else { return }
        
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        displayLink.link(withTarget: self, selector: #selector(newFrame(_:)))
        isRunning = true
        lock.unlock()
        
        self.rootView = rootView
        lastScreenShot = dateProvider.date()
        videoSegmentStart = nil
        currentSegmentId = 0
        sessionReplayId = SentryId()
        replayMaker.videoWidth = Int(Float(rootView.frame.size.width) * replayOptions.sizeScale)
        replayMaker.videoHeight = Int(Float(rootView.frame.size.height) * replayOptions.sizeScale)
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

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }
        
        displayLink.invalidate()
        isRunning = false
        prepareSegmentUntil(date: dateProvider.date())
    }

    func resume() {
        guard !reachedMaximumDuration else { return }

        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return }
        
        videoSegmentStart = nil
        displayLink.link(withTarget: self, selector: #selector(newFrame(_:)))
        isRunning = true
    }

    deinit {
        displayLink.invalidate()
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

        guard delegate?.sessionReplayIsFullSession() == true else {
            return false
        }

        startFullReplay()

        guard let finalPath = urlToCache?.appendingPathComponent("replay.mp4") else {
            print("[SentrySessionReplay:\(#line)] Could not create replay video path")
            return false
        }
        let replayStart = dateProvider.date().addingTimeInterval(-replayOptions.errorReplayDuration - (Double(replayOptions.frameRate) / 2.0))

        createAndCapture(videoUrl: finalPath, startedAt: replayStart)

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
        guard let lastScreenShot = lastScreenShot, isRunning else { return }

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
                print("[SentrySessionReplay:\(#line)] Can't create session replay segment folder. Error: \(error.localizedDescription)")
                return
            }
        }

        pathToSegment = pathToSegment.appendingPathComponent("\(currentSegmentId).mp4")
        let segmentStart = videoSegmentStart ?? dateProvider.date().addingTimeInterval(-replayOptions.sessionSegmentDuration)

        createAndCapture(videoUrl: pathToSegment, startedAt: segmentStart)
    }

    private func createAndCapture(videoUrl: URL, startedAt: Date) {
        do {
            try replayMaker.createVideoWith(beginning: startedAt, end: dateProvider.date(), outputFileURL: videoUrl) { [weak self] videoInfo, error in
                guard let _self = self else { return }
                if let error = error {
                    print("[SentrySessionReplay:\(#line)] Could not create replay video - \(error.localizedDescription)")
                } else if let videoInfo = videoInfo {
                    _self.newSegmentAvailable(videoInfo: videoInfo)
                }
            }
        } catch {
            print("[SentrySessionReplay:\(#line)] Could not create replay video - \(error.localizedDescription)")
        }
    }

    private func newSegmentAvailable(videoInfo: SentryVideoInfo) {
        guard let sessionReplayId = sessionReplayId else { return }
        captureSegment(segment: currentSegmentId, video: videoInfo, replayId: sessionReplayId, replayType: .session)
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

        let recording = SentryReplayRecording(segmentId: replayEvent.segmentId, size: video.fileSize, start: video.start, duration: video.duration, frameCount: video.frameCount, frameRate: video.frameRate, height: video.height, width: video.width, extraEvents: events)
                
        delegate?.sessionReplayNewSegment(replayEvent: replayEvent, replayRecording: recording, videoUrl: video.path)

        do {
            try FileManager.default.removeItem(at: video.path)
        } catch {
            print("[SentrySessionReplay:\(#line)] Could not delete replay segment from disk: \(error.localizedDescription)")
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

        lock.synchronized {
            guard !processingScreenshot else { return }
            processingScreenshot = true
        }

        let screenName = delegate?.currentScreenNameForSessionReplay()
        
        screenshotProvider.image(view: rootView, options: replayOptions) { [weak self] screenshot in
            self?.newImage(image: screenshot, forScreen: screenName)
        }
    }

    private func newImage(image: UIImage, forScreen screen: String?) {
        processingScreenshot = false
        replayMaker.addFrameAsync(image: image, forScreen: screen)
    }
}

#endif
