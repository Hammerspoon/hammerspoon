@_spi(Private) @objc public protocol SentryFileManagerProtocol {
    func moveState(_ stateFilePath: String, toPreviousState previousStateFilePath: String)
    func readData(fromPath path: String) throws -> Data
    @objc(writeData:toPath:)
    @discardableResult func write(_ data: Data, toPath path: String) -> Bool
    func removeFile(atPath path: String)
    func getSentryPathAsURL() -> URL
}
