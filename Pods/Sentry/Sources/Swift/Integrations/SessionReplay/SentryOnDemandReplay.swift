#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import AVFoundation
import CoreGraphics
import Foundation
import UIKit

struct SentryReplayFrame {
    let imagePath: String
    let time: Date
    let screenName: String?
}

private struct VideoFrames {
    let framesPaths: [String]
    let screens: [String]
    let start: Date
    let end: Date
}

enum SentryOnDemandReplayError: Error {
    case cantReadVideoSize
    case assetWriterNotReady
}

@objcMembers
class SentryOnDemandReplay: NSObject, SentryReplayVideoMaker {
    private let _outputPath: String
    private var _currentPixelBuffer: SentryPixelBuffer?
    private var _totalFrames = 0
    private let dateProvider: SentryCurrentDateProvider
    private let workingQueue: SentryDispatchQueueWrapper
    private var _frames = [SentryReplayFrame]()
    
    #if TEST || TESTCI || DEBUG
    //This is exposed only for tests, no need to make it thread safe.
    var frames: [SentryReplayFrame] {
        get { _frames }
        set { _frames = newValue }
    }
    #endif // TEST || TESTCI || DEBUG
    
    var videoWidth = 200
    var videoHeight = 434
    var bitRate = 20_000
    var frameRate = 1
    var cacheMaxSize = UInt.max
    
    convenience init(outputPath: String) {
        self.init(outputPath: outputPath,
                  workingQueue: SentryDispatchQueueWrapper(name: "io.sentry.onDemandReplay", attributes: nil),
                  dateProvider: SentryCurrentDateProvider())
    }
    
    init(outputPath: String, workingQueue: SentryDispatchQueueWrapper, dateProvider: SentryCurrentDateProvider) {
        self._outputPath = outputPath
        self.dateProvider = dateProvider
        self.workingQueue = workingQueue
    }
    
    func addFrameAsync(image: UIImage, forScreen: String?) {
        workingQueue.dispatchAsync({
            self.addFrame(image: image, forScreen: forScreen)
        })
    }
    
    private func addFrame(image: UIImage, forScreen: String?) {
        guard let data = rescaleImage(image)?.pngData() else { return }
        
        let date = dateProvider.date()
        let imagePath = (_outputPath as NSString).appendingPathComponent("\(_totalFrames).png")
        do {
            try data.write(to: URL(fileURLWithPath: imagePath))
        } catch {
            print("[SentryOnDemandReplay] Could not save replay frame. Error: \(error)")
            return
        }
        _frames.append(SentryReplayFrame(imagePath: imagePath, time: date, screenName: forScreen))
        
        while _frames.count > cacheMaxSize {
            let first = _frames.removeFirst()
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
        }
        _totalFrames += 1
    }
    
    private func rescaleImage(_ originalImage: UIImage) -> UIImage? {
        guard originalImage.scale > 1 else { return originalImage }
        
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func releaseFramesUntil(_ date: Date) {
        workingQueue.dispatchAsync ({
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: first.imagePath))
            }
        })
    }
        
    func createVideoWith(beginning: Date, end: Date, outputFileURL: URL, completion: @escaping (SentryVideoInfo?, Error?) -> Void) throws {
        var frameCount = 0
        let videoFrames = filterFrames(beginning: beginning, end: end)
        if videoFrames.framesPaths.isEmpty { return }
        
        let videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mp4)
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: createVideoSettings())
        
        _currentPixelBuffer = SentryPixelBuffer(size: CGSize(width: videoWidth, height: videoHeight), videoWriterInput: videoWriterInput)
        if _currentPixelBuffer == nil { return }
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        videoWriterInput.requestMediaDataWhenReady(on: workingQueue.queue) { [weak self] in
            guard let self = self, videoWriter.status == .writing else {
                videoWriter.cancelWriting()
                completion(nil, SentryOnDemandReplayError.assetWriterNotReady)
                return
            }
            
            if frameCount < videoFrames.framesPaths.count {
                let imagePath = videoFrames.framesPaths[frameCount]
                if let image = UIImage(contentsOfFile: imagePath) {
                    let presentTime = CMTime(seconds: Double(frameCount), preferredTimescale: CMTimeScale(1 / self.frameRate))

                    guard self._currentPixelBuffer?.append(image: image, presentationTime: presentTime) == true 
                    else {
                        completion(nil, videoWriter.error)
                        videoWriterInput.markAsFinished()
                        return
                    }
                }
                frameCount += 1
            } else {
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting {
                    var videoInfo: SentryVideoInfo?
                    if videoWriter.status == .completed {
                        do {
                            let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
                            guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
                                completion(nil, SentryOnDemandReplayError.cantReadVideoSize)
                                return
                            }
                            videoInfo = SentryVideoInfo(path: outputFileURL, height: self.videoHeight, width: self.videoWidth, duration: TimeInterval(videoFrames.framesPaths.count / self.frameRate), frameCount: videoFrames.framesPaths.count, frameRate: self.frameRate, start: videoFrames.start, end: videoFrames.end, fileSize: fileSize, screens: videoFrames.screens)
                        } catch {
                            completion(nil, error)
                        }
                    }
                    completion(videoInfo, videoWriter.error)
                }
            }
        }
    }
    
    private func filterFrames(beginning: Date, end: Date) -> VideoFrames {
        var framesPaths = [String]()
        
        var screens = [String]()
        
        var start = dateProvider.date()
        var actualEnd = start
        workingQueue.dispatchSync({
            for frame in self._frames {
                if frame.time < beginning { continue } else if frame.time > end { break }
                
                if frame.time < start { start = frame.time }
                
                if let screenName = frame.screenName {
                    screens.append(screenName)
                }
                
                actualEnd = frame.time
                framesPaths.append(frame.imagePath)
            }
        })
        return VideoFrames(framesPaths: framesPaths, screens: screens, start: start, end: actualEnd + TimeInterval((1 / Double(frameRate))))
    }
    
    private func createVideoSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ] as [String: Any]
        ]
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
