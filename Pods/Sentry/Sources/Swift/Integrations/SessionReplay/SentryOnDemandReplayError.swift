enum SentryOnDemandReplayError: Error {
    case cantReadVideoSize
    case cantCreatePixelBuffer
    case errorRenderingVideo
    case cantReadVideoStartTime
}
