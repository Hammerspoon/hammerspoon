enum SentryOnDemandReplayError: Error {
    case cantReadVideoSize
    case cantCreatePixelBuffer
    case cantReadImage
    case errorRenderingVideo
    case cantReadVideoStartTime
    case indexOutOfBounds
}
