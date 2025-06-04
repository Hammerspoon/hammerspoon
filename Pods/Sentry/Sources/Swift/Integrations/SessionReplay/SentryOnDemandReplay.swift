// swiftlint:disable file_length type_body_length
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import UIKit

// swiftlint:disable type_body_length
@objcMembers
class SentryOnDemandReplay: NSObject, SentryReplayVideoMaker {
        
    private let _outputPath: String
    private var _totalFrames = 0
    private let processingQueue: SentryDispatchQueueWrapper
    private let assetWorkerQueue: SentryDispatchQueueWrapper
    private var _frames = [SentryReplayFrame]()

    #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
    //This is exposed only for tests, no need to make it thread safe.
    var frames: [SentryReplayFrame] {
        get { _frames }
        set { _frames = newValue }
    }
    #endif // SENTRY_TEST || SENTRY_TEST_CI || DEBUG
    var videoScale: Float = 1
    var bitRate = 20_000
    var frameRate = 1
    var cacheMaxSize = UInt.max
        
    init(
        outputPath: String,
        processingQueue: SentryDispatchQueueWrapper,
        assetWorkerQueue: SentryDispatchQueueWrapper
    ) {
        assert(processingQueue != assetWorkerQueue, "Processing and asset worker queue must not be the same.")
        self._outputPath = outputPath
        self.processingQueue = processingQueue
        self.assetWorkerQueue = assetWorkerQueue
    }
        
    convenience init(
        withContentFrom outputPath: String,
        processingQueue: SentryDispatchQueueWrapper,
        assetWorkerQueue: SentryDispatchQueueWrapper
    ) {
        self.init(
            outputPath: outputPath,
            processingQueue: processingQueue,
            assetWorkerQueue: assetWorkerQueue
        )
        loadFrames(fromPath: outputPath)
    }

    /// Loads the frames from the given path.
    ///
    /// - Parameter path: The path to the directory containing the frames.
    private func loadFrames(fromPath path: String) {
        SentryLog.debug("[Session Replay] Loading frames from path: \(path)")
        do {
            let content = try FileManager.default.contentsOfDirectory(atPath: path)
            _frames = content.compactMap { frameFilePath -> SentryReplayFrame? in
                guard frameFilePath.hasSuffix(".png") else { return nil }
                guard let time = Double(frameFilePath.dropLast(4)) else { return nil }
                let timestamp = Date(timeIntervalSinceReferenceDate: time)
                return SentryReplayFrame(imagePath: "\(path)/\(frameFilePath)", time: timestamp, screenName: nil)
            }.sorted { $0.time < $1.time }
            SentryLog.debug("[Session Replay] Loaded \(content.count) files into \(_frames.count) frames from path: \(path)")
        } catch {
            SentryLog.error("[Session Replay] Could not list frames from replay, reason: \(error.localizedDescription)")
        }
    }

    @objc func addFrameAsync(timestamp: Date, image: UIImage, forScreen screen: String?) {
        SentryLog.debug("[Session Replay] Adding frame async for screen: \(screen ?? "nil") at timestamp: \(timestamp)")
        // Dispatch the frame addition to a background queue to avoid blocking the main queue.
        // This must be on the processing queue to avoid deadlocks.
        processingQueue.dispatchAsync {
            self.addFrame(timestamp: timestamp, image: image, forScreen: screen)
        }
    }
    
    private func addFrame(timestamp: Date, image: UIImage, forScreen screen: String?) {
        SentryLog.debug("[Session Replay] Adding frame to replay, screen: \(screen ?? "nil") at timestamp: \(timestamp)")
        guard let data = rescaleImage(image)?.pngData() else {
            SentryLog.error("[Session Replay] Could not rescale image, dropping frame")
            return
        }

        let imagePath = (_outputPath as NSString).appendingPathComponent("\(timestamp.timeIntervalSinceReferenceDate).png")
        do {
            let url = URL(fileURLWithPath: imagePath)
            SentryLog.debug("[Session Replay] Saving frame to file URL: \(url)")
            try data.write(to: url)
        } catch {
            SentryLog.error("[Session Replay] Could not save replay frame, reason: \(error)")
            return
        }
        _frames.append(SentryReplayFrame(imagePath: imagePath, time: timestamp, screenName: screen))

        // Remove the oldest frames if the cache size exceeds the maximum size.
        while _frames.count > cacheMaxSize {
            let first = _frames.removeFirst()
            let url = URL(fileURLWithPath: first.imagePath)
            SentryLog.debug("[Session Replay] Removing oldest frame at file URL: \(url.path)")
            try? FileManager.default.removeItem(at: url)
        }
        _totalFrames += 1
        SentryLog.debug("[Session Replay] Added frame, total frames counter: \(_totalFrames), current frames count: \(_frames.count)")
    }
    
    private func rescaleImage(_ originalImage: UIImage) -> UIImage? {
        SentryLog.debug("[Session Replay] Rescaling image with scale: \(originalImage.scale)")
        guard originalImage.scale > 1 else { 
            SentryLog.debug("[Session Replay] Image is already at the correct scale, returning original image")
            return originalImage
        }
        
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func releaseFramesUntil(_ date: Date) {
        processingQueue.dispatchAsync {
            SentryLog.debug("[Session Replay] Releasing frames until date: \(date)")
            while let first = self._frames.first, first.time < date {
                self._frames.removeFirst()
                let fileUrl = URL(fileURLWithPath: first.imagePath)
                do {
                    try FileManager.default.removeItem(at: fileUrl)
                    SentryLog.debug("[Session Replay] Removed frame at url: \(fileUrl.path)")
                } catch {
                    SentryLog.error("[Session Replay] Failed to remove frame at: \(fileUrl.path), reason: \(error), ignoring error")
                }
            }
            SentryLog.debug("[Session Replay] Frames released, remaining frames count: \(self._frames.count)")
        }
    }
        
    var oldestFrameDate: Date? {
        return _frames.first?.time
    }

    func createVideoInBackgroundWith(beginning: Date, end: Date, completion: @escaping ([SentryVideoInfo]) -> Void) {
        // Note: In Swift it is best practice to use `Result<Value, Error>` instead of `(Value?, Error?)`
        //       Due to interoperability with Objective-C and @objc, we can not use Result for the completion callback.
        SentryLog.debug("[Session Replay] Creating video in background with beginning: \(beginning), end: \(end)")
        processingQueue.dispatchAsync {
            let videos = self.createVideoWith(beginning: beginning, end: end)
            SentryLog.debug("[Session Replay] Finished creating video in background with \(videos.count) segments")
            completion(videos)
        }
    }

    func createVideoWith(beginning: Date, end: Date) -> [SentryVideoInfo] {
        SentryLog.debug("[Session Replay] Creating video with beginning: \(beginning), end: \(end)")
        // Note: In previous implementations this method was wrapped by a sync call to the processing queue.
        // As this method is already called from the processing queue, we must remove the sync call.
        let videoFrames = self._frames.filter { $0.time >= beginning && $0.time <= end }
        var frameCount = 0

        var videos = [SentryVideoInfo]()

        while frameCount < videoFrames.count {
            let frame = videoFrames[frameCount]
            let outputFileURL = URL(fileURLWithPath: _outputPath)
                .appendingPathComponent("\(frame.time.timeIntervalSinceReferenceDate)")
                .appendingPathExtension("mp4")

            let group = DispatchGroup()
            var currentError: Error?

            group.enter()
            self.renderVideo(with: videoFrames, from: frameCount, at: outputFileURL) { result in
                switch result {
                case .success(let videoResult):
                    // Set the frame count/offset to the new index that is returned by the completion block.
                    // This is important to avoid processing the same frame multiple times.
                    frameCount = videoResult.finalFrameIndex
                    SentryLog.debug("[Session Replay] Finished rendering video, frame count moved to: \(frameCount)")

                    // Append the video info to the videos array.
                    // In case no video info is returned, skip the segment.
                    if let videoInfo = videoResult.info {
                        videos.append(videoInfo)
                    }
                case .failure(let error):
                    SentryLog.error("[Session Replay] Failed to render video with error: \(error)")
                    currentError = error
                }
                group.leave()
            }

            // Calling group.wait will block the `processingQueue` until the video rendering completes or a timeout occurs.
            // It is imporant that the renderVideo completion block signals the group.
            // The queue used by render video must have a higher priority than the processing queue to reduce thread inversion.
            // Otherwise, it could lead to queue starvation and a deadlock/timeout.
            guard group.wait(timeout: .now() + 10) == .success else {
                SentryLog.error("[Session Replay] Timeout while waiting for video rendering to finish, returning \(videos.count) videos")
                return videos
            }

            // If there was an error, log it and exit the loop.
            if let error = currentError {
                // Until v8.50.2 the error was propagated to the completion block, discarding any generated video.
                // Instead this will "silently" fail by only logging the error and returning the successfully generated videos.
                SentryLog.error("[Session Replay] Error while rendering video: \(error), returning \(videos.count) videos")
                return videos
            }

            SentryLog.debug("[Session Replay] Finished rendering video, frame count moved to: \(frameCount)")
        }

        SentryLog.debug("[Session Replay] Finished creating video with \(videos.count) segments")
        return videos
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func renderVideo(with videoFrames: [SentryReplayFrame], from: Int, at outputFileURL: URL, completion: @escaping (Result<SentryRenderVideoResult, Error>) -> Void) {
        SentryLog.debug("[Session Replay] Rendering video with \(videoFrames.count) frames, from index: \(from), to output url: \(outputFileURL)")
        guard from < videoFrames.count else {
            SentryLog.error("[Session Replay] Failed to render video, reason: index out of bounds")
            return completion(.success(SentryRenderVideoResult(
                info: nil,
                finalFrameIndex: from
            )))
        }
        guard let image = UIImage(contentsOfFile: videoFrames[from].imagePath) else {
            SentryLog.error("[Session Replay] Failed to render video, reason: can't read image at path: \(videoFrames[from].imagePath)")
            return completion(.success(SentryRenderVideoResult(
                info: nil,
                finalFrameIndex: from
            )))
        }
        
        let videoWidth = image.size.width * CGFloat(videoScale)
        let videoHeight = image.size.height * CGFloat(videoScale)
        let pixelSize = CGSize(width: videoWidth, height: videoHeight)

        SentryLog.debug("[Session Replay] Creating video writer with output file URL: \(outputFileURL)")
        let videoWriter: AVAssetWriter
        do {
            videoWriter = try AVAssetWriter(url: outputFileURL, fileType: .mp4)
        } catch {
            SentryLog.error("[Session Replay] Failed to create video writer, reason: \(error)")
            return completion(.failure(error))
        }

        SentryLog.debug("[Session Replay] Creating pixel buffer based video writer input")
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: createVideoSettings(width: videoWidth, height: videoHeight))
        guard let currentPixelBuffer = SentryPixelBuffer(size: pixelSize, videoWriterInput: videoWriterInput) else {
            SentryLog.error("[Session Replay] Failed to render video, reason: pixel buffer creation failed")
            return completion(.failure(SentryOnDemandReplayError.cantCreatePixelBuffer))
        }
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)

        var lastImageSize: CGSize = image.size
        var usedFrames = [SentryReplayFrame]()
        var frameIndex = from

        // Convenience wrapper to handle the completion callback to return the video info and the final frame index
        // It is not possible to use an inout frame index here, because the closure is escaping and the frameIndex variable is captured.
        let deferredCompletionCallback: (Result<SentryVideoInfo?, Error>) -> Void = { result in
            switch result {
            case .success(let videoResult):
                completion(.success(SentryRenderVideoResult(
                    info: videoResult,
                    finalFrameIndex: frameIndex
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
        // Append frames to the video writer input in a pull-style manner when the input is ready to receive more media data.
        //
        // Inside the callback:
        // 1. We append media data until `isReadyForMoreMediaData` becomes false
        // 2. Or until there's no more media data to process (then we mark input as finished)
        // 3. If we don't mark the input as finished, the callback will be invoked again
        //    when the input is ready for more data
        //
        // By setting the queue to the asset worker queue, we ensure that the callback is invoked on the asset worker queue.
        // This is important to avoid a deadlock, as this method is called on the processing queue.
        videoWriterInput.requestMediaDataWhenReady(on: assetWorkerQueue.queue) { [weak self] in
            SentryLog.debug("[Session Replay] Video writer input is ready, status: \(videoWriter.status)")
            guard let strongSelf = self else {
                SentryLog.warning("[Session Replay] On-demand replay is deallocated, completing writing session without output video info")
                return deferredCompletionCallback(.success(nil))
            }
            guard videoWriter.status == .writing else {
                SentryLog.error("[Session Replay] Video writer is not writing anymore, cancelling the writing session, reason: \(videoWriter.error?.localizedDescription ?? "Unknown error")")
                videoWriter.cancelWriting()
                return deferredCompletionCallback(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            }
            guard frameIndex < videoFrames.count else {
                SentryLog.debug("[Session Replay] No more frames available to process, finishing the video")
                return strongSelf.finishVideo(
                    outputFileURL: outputFileURL,
                    usedFrames: usedFrames,
                    videoHeight: Int(videoHeight),
                    videoWidth: Int(videoWidth),
                    videoWriter: videoWriter,
                    onCompletion: deferredCompletionCallback
                )
            }

            let frame = videoFrames[frameIndex]
            if let image = UIImage(contentsOfFile: frame.imagePath) {
                SentryLog.debug("[Session Replay] Image at index \(frameIndex) is ready, size: \(image.size)")
                guard lastImageSize == image.size else {
                    SentryLog.debug("[Session Replay] Image size has changed, finishing video")
                    return strongSelf.finishVideo(
                        outputFileURL: outputFileURL,
                        usedFrames: usedFrames,
                        videoHeight: Int(videoHeight),
                        videoWidth: Int(videoWidth),
                        videoWriter: videoWriter,
                        onCompletion: deferredCompletionCallback
                    )
                }
                lastImageSize = image.size

                let presentTime = SentryOnDemandReplay.calculatePresentationTime(
                    forFrameAtIndex: frameIndex,
                    frameRate: strongSelf.frameRate
                ).timeValue
                guard currentPixelBuffer.append(image: image, presentationTime: presentTime) else {
                    SentryLog.error("[Session Replay] Failed to append image to pixel buffer, cancelling the writing session, reason: \(String(describing: videoWriter.error))")
                    videoWriter.cancelWriting()
                    return deferredCompletionCallback(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
                }
                usedFrames.append(frame)
            }

            // Increment the frame index even if the image could not be appended to the pixel buffer.
            // This is important to avoid an infinite loop.
            frameIndex += 1
        }
    }

    // swiftlint:enable function_body_length cyclomatic_complexity
    private func finishVideo(
        outputFileURL: URL,
        usedFrames: [SentryReplayFrame],
        videoHeight: Int,
        videoWidth: Int,
        videoWriter: AVAssetWriter,
        onCompletion completion: @escaping (Result<SentryVideoInfo?, Error>) -> Void
    ) {
        // Note: This method is expected to be called from the asset worker queue and *not* the processing queue.
        SentryLog.info("[Session Replay] Finishing video with output file URL: \(outputFileURL), used frames count: \(usedFrames.count), video height: \(videoHeight), video width: \(videoWidth)")
        videoWriter.inputs.forEach { $0.markAsFinished() }
        videoWriter.finishWriting { [weak self] in
            SentryLog.debug("[Session Replay] Finished video writing, status: \(videoWriter.status)")
            guard let strongSelf = self else {
                SentryLog.warning("[Session Replay] On-demand replay is deallocated, completing writing session without output video info")
                return completion(.success(nil))
            }

            switch videoWriter.status {
            case .writing:
                SentryLog.error("[Session Replay] Finish writing video was called with status writing, this is unexpected! Completing with no video info")
                completion(.success(nil))
            case .cancelled:
                SentryLog.warning("[Session Replay] Finish writing video was cancelled, completing with no video info.")
                completion(.success(nil))
            case .completed:
                SentryLog.debug("[Session Replay] Finish writing video was completed, creating video info from file attributes.")
                do {
                    let result = try strongSelf.getVideoInfo(
                        from: outputFileURL,
                        usedFrames: usedFrames,
                        videoWidth: Int(videoWidth),
                        videoHeight: Int(videoHeight)
                    )
                    completion(.success(result))
                } catch {
                    SentryLog.warning("[Session Replay] Failed to create video info from file attributes, reason: \(error)")
                    completion(.failure(error))
                }
            case .failed:
                SentryLog.warning("[Session Replay] Finish writing video failed, reason: \(String(describing: videoWriter.error))")
                completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            case .unknown:
                SentryLog.warning("[Session Replay] Finish writing video with unknown status, reason: \(String(describing: videoWriter.error))")
                completion(.failure(videoWriter.error ?? SentryOnDemandReplayError.errorRenderingVideo))
            @unknown default:
                SentryLog.warning("[Session Replay] Finish writing video in unknown state, reason: \(String(describing: videoWriter.error))")
                completion(.failure(SentryOnDemandReplayError.errorRenderingVideo))
            }
        }
    }

    fileprivate func getVideoInfo(from outputFileURL: URL, usedFrames: [SentryReplayFrame], videoWidth: Int, videoHeight: Int) throws -> SentryVideoInfo {
        SentryLog.debug("[Session Replay] Getting video info from file: \(outputFileURL.path), width: \(videoWidth), height: \(videoHeight), used frames count: \(usedFrames.count)")
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
        guard let fileSize = fileAttributes[FileAttributeKey.size] as? Int else {
            SentryLog.warning("[Session Replay] Failed to read video size from video file, reason: size attribute not found")
            throw SentryOnDemandReplayError.cantReadVideoSize
        }
        let minFrame = usedFrames.min(by: { $0.time < $1.time })
        guard let start = minFrame?.time else {
            // Note: This code path is currently not reached, because the `getVideoInfo` method is only called after the video is successfully created, therefore at least one frame was used.
            // The compiler still requires us to unwrap the optional value, and we do not permit force-unwrapping.
            SentryLog.warning("[Session Replay] Failed to read video start time from used frames, reason: no frames found")
            throw SentryOnDemandReplayError.cantReadVideoStartTime
        }
        let duration = TimeInterval(usedFrames.count / self.frameRate)
        return SentryVideoInfo(
            path: outputFileURL,
            height: videoHeight,
            width: videoWidth,
            duration: duration,
            frameCount: usedFrames.count,
            frameRate: self.frameRate,
            start: start,
            end: start.addingTimeInterval(duration),
            fileSize: fileSize,
            screens: usedFrames.compactMap({ $0.screenName })
        )
    }

    internal func createVideoSettings(width: CGFloat, height: CGFloat) -> [String: Any] {
        return [
            // The codec type for the video. H.264 (AVC) is the most widely supported codec across platforms,
            // including web browsers, QuickTime, VLC, and mobile devices.
            AVVideoCodecKey: AVVideoCodecType.h264,

            // The dimensions of the video frame in pixels.
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,

            // AVVideoCompressionPropertiesKey contains advanced compression settings.
            AVVideoCompressionPropertiesKey: [
                // Specifies the average bit rate used for encoding. A higher bit rate increases visual quality
                // at the cost of file size. Choose a value appropriate for your resolution (e.g., 1 Mbps for 720p).
                AVVideoAverageBitRateKey: bitRate,

                // Selects the H.264 Main profile with an automatic level.
                // This avoids using the Baseline profile, which lacks key features like CABAC entropy coding
                // and causes issues in decoders like VideoToolbox, especially at non-standard frame rates (1 FPS).
                // The Main profile is well supported by both hardware and software decoders.
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,

                // Prevents the use of B-frames (bidirectional predicted frames).
                // B-frames reference both past and future frames, which can break compatibility
                // with certain hardware decoders and make accurate seeking harder, especially in timelapse videos
                // where each frame is independent and must be decodable on its own.
                AVVideoAllowFrameReorderingKey: false,

                // Sets keyframe interval to one I-frame per video segment.
                // This significantly reduces file size (e.g. from 19KB to 9KB) while maintaining
                // acceptable seeking granularity. With our 1 FPS recording, this means a keyframe
                // will be inserted once every 6 seconds of recorded content, but our video segments
                // will never be longer than 5 seconds, resulting in a maximum of 1 I-frame per video.
                AVVideoMaxKeyFrameIntervalKey: 6 // 5 + 1 interval for optimal compression
            ] as [String: Any],

            // Explicitly sets the video color space to ITU-R BT.709 (the standard for HD video).
            // This improves color accuracy and ensures consistent rendering across platforms and browsers,
            // especially when the source content is rendered using UIKit/AppKit (e.g., UIColor, UIImage, UIView).
            // Without these, decoders may guess or default to BT.601, resulting in incorrect gamma or saturation.
            AVVideoColorPropertiesKey: [
                // Specifies the color primaries — i.e., the chromaticities of red, green, and blue.
                // BT.709 is the standard for HD content and matches sRGB color primaries,
                // ensuring accurate color reproduction when rendered on most displays.
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,

                // Defines the transfer function (optical-electrical transfer function).
                // BT.709 matches sRGB gamma (~2.2) and ensures that brightness/contrast levels
                // look correct on most screens and in browsers using HTML5 <video>.
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,

                // Specifies how YUV components are encoded from RGB.
                // BT.709 YCbCr matrix ensures correct conversion and consistent luminance/chrominance scaling.
                // Without this, colors might appear washed out or overly saturated.
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ] as [String: Any]
        ]
    }

    /// Calculates the presentation time for a frame at a given index and frame rate.
    ///
    /// The return value is an `NSValue` containing a `CMTime` object representing the calculated presentation time.
    /// The `CMTime` must be wrapped as this class is exposed to Objective-C via `Sentry-Swift.h`, and Objective-C does not support `CMTime`
    /// as a return value.
    ///
    /// - Parameters:
    ///   - index: Index of the frame, counted from 0.
    ///   - frameRate: Number of frames per second.
    /// - Returns: `NSValue` containing the `CMTime` representing the calculated presentation time. Can be accessed using the `timeValue` property.
    internal static func calculatePresentationTime(forFrameAtIndex index: Int, frameRate: Int) -> NSValue {
        // Generate the presentation time for the current frame using integer math.
        // This avoids floating-point rounding issues and ensures frame-accurate timing,
        // which is critical for AVAssetWriter at low frame rates like 1 FPS.
        // By defining timePerFrame as (1 / frameRate) and multiplying it by the frame index,
        // we guarantee consistent spacing between frames and precise control over the timeline.
        let timePerFrame = CMTimeMake(value: 1, timescale: Int32(frameRate))
        let presentTime = CMTimeMultiply(timePerFrame, multiplier: Int32(index))

        return NSValue(time: presentTime)
    }
}
// swiftlint:enable type_body_length

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit)
// swiftlint:enable file_length type_body_length
