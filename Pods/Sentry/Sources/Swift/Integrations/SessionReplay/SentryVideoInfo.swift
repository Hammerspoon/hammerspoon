import Foundation

@objcMembers
class SentryVideoInfo: NSObject {
    
    let path: URL
    let height: Int
    let width: Int
    let duration: TimeInterval
    let frameCount: Int
    let frameRate: Int
    let start: Date
    let end: Date
    let fileSize: Int
    let screens: [String]
    
    init(path: URL, height: Int, width: Int, duration: TimeInterval, frameCount: Int, frameRate: Int, start: Date, end: Date, fileSize: Int, screens: [String]) {
        self.height = height
        self.width = width
        self.duration = duration
        self.frameCount = frameCount
        self.frameRate = frameRate
        self.start = start
        self.end = end
        self.path = path
        self.fileSize = fileSize
        self.screens = screens
    }
    
}
