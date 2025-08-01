@_implementationOnly import _SentryPrivate

@objc
enum SentryScopeField: UInt, CaseIterable {
    case context
    case user
    case dist
    case environment
    case tags
    case extras
    case fingerprint
    
    var name: String {
        switch self {
        case .context:
            return "context"
        case .user:
            return "user"
        case .dist:
            return "dist"
        case .environment:
            return "environment"
        case .tags:
            return "tags"
        case .extras:
            return "extras"
        case .fingerprint:
            return "fingerprint"
        }
    }
}

@objc
@_spi(Private) public class SentryScopePersistentStore: NSObject {
    private let fileManager: SentryFileManagerProtocol
    
    @objc
    public init?(fileManager: SentryFileManagerProtocol?) {
        guard let fileManager else { return nil }
        
        self.fileManager = fileManager
    }
    
    // MARK: - General
    
    @objc
    public func moveAllCurrentStateToPreviousState() {
        // Make sure we execute all cases
        for field in SentryScopeField.allCases {
            moveCurrentFileToPreviousFile(field: field)
        }
    }
    
    func deleteAllCurrentState() {
        // Make sure we execute all cases
        for field in SentryScopeField.allCases {
            deleteCurrentFieldOnDisk(field: field)
        }
    }
    
    func deleteCurrentFieldOnDisk(field: SentryScopeField) {
        let path = currentFileURLFor(field: field).path
        SentrySDKLog.debug("Deleting context file at path: \(path)")
        fileManager.removeFile(atPath: path)
    }
    
    // Only used for testing
    func deleteAllPreviousState() {
        // Make sure we execute all cases
        for field in SentryScopeField.allCases {
            deletePreviousFieldOnDisk(field: field)
        }
    }
    
    // MARK: - Context
    
    @objc
    public func readPreviousContextFromDisk() -> [String: [String: Any]]? {
        readFieldFromDisk(field: .context) { data in
            decodeContext(from: data)
        }
    }
    
    func writeContextToDisk(context: [String: [String: Any]]) {
        writeFieldToDisk(field: .context, data: encode(context: context))
    }
    
    // MARK: - User
    @objc
    public func readPreviousUserFromDisk() -> User? {
        readFieldFromDisk(field: .user) { data in
            decodeUser(from: data)
        }
    }
    
    func writeUserToDisk(user: User) {
        writeFieldToDisk(field: .user, data: encode(user: user))
    }
    
    // MARK: - Dist
    @objc
    public func readPreviousDistFromDisk() -> String? {
        readFieldFromDisk(field: .dist) { data in
            decodeString(from: data)
        }
    }
    
    func writeDistToDisk(dist: String) {
        writeFieldToDisk(field: .dist, data: encode(string: dist))
    }
    
    // MARK: - User
    @objc
    public func readPreviousEnvironmentFromDisk() -> String? {
        readFieldFromDisk(field: .environment) { data in
            decodeString(from: data)
        }
    }
    
    func writeEnvironmentToDisk(environment: String) {
        writeFieldToDisk(field: .environment, data: encode(string: environment))
    }
    
    // MARK: - Tags
    @objc
    public func readPreviousTagsFromDisk() -> [String: String]? {
        readFieldFromDisk(field: .tags) { data in
            decodeTags(from: data)
        }
    }
    
    func writeTagsToDisk(tags: [String: String]) {
        writeFieldToDisk(field: .tags, data: encode(tags: tags))
    }
    
    // MARK: - Extras
    @objc
    public func readPreviousExtrasFromDisk() -> [String: Any]? {
        readFieldFromDisk(field: .extras) { data in
            decodeExtras(from: data)
        }
    }
    
    func writeExtrasToDisk(extras: [String: Any]) {
        writeFieldToDisk(field: .extras, data: encode(extras: extras))
    }
    
    // MARK: - Fingerprint
    @objc
    public func readPreviousFingerprintFromDisk() -> [String]? {
        readFieldFromDisk(field: .fingerprint) { data in
            decodeFingerprint(from: data)
        }
    }
    
    func writeFingerprintToDisk(fingerprint: [String]) {
        writeFieldToDisk(field: .fingerprint, data: encode(fingerprint: fingerprint))
    }
    
    // MARK: - Private Functions
    
    private func moveCurrentFileToPreviousFile(field: SentryScopeField) {
        SentrySDKLog.debug("Moving \(field.name) file to previous \(field.name) file")
        self.fileManager.moveState(currentFileURLFor(field: field).path, toPreviousState: previousFileURLFor(field: field).path)
    }
    
    private func deletePreviousFieldOnDisk(field: SentryScopeField) {
        let path = previousFileURLFor(field: field).path
        SentrySDKLog.debug("Deleting context file at path: \(path)")
        fileManager.removeFile(atPath: path)
    }
    
    private func writeFieldToDisk(field: SentryScopeField, data: Data?) {
        let path = currentFileURLFor(field: field).path
        SentrySDKLog.debug("Writing \(field.name) to disk at path: \(path)")
        guard let data = data else {
            return
        }
        fileManager.write(data, toPath: path)
    }
    
    private func readFieldFromDisk<T>(field: SentryScopeField, decode: (Data) -> T?) -> T? {
        let path = previousFileURLFor(field: field).path
        SentrySDKLog.debug("Reading previous \(field.name) file at path: \(path)")
        do {
            let data = try fileManager.readData(fromPath: path)
            return decode(data)
        } catch {
            SentrySDKLog.error("Failed to read previous \(field.name) file at path: \(path), reason: \(error)")
            return nil
        }
    }
    
    // MARK: - File Helpers
    
    /**
     * Path to a state file holding the latest data observed from the scope.
     *
     * This path is used to keep a persistent copy of the scope on disk, to be available after
     * restart of the app.
     */
    func currentFileURLFor(field: SentryScopeField) -> URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("\(field.name).state")
    }
    
    /**
     * Path to the previous state file holding the latest data observed from the scope.
     *
     * This file is overwritten at SDK start and kept as a copy of the last data file until the next
     * SDK start.
     */
    func previousFileURLFor(field: SentryScopeField) -> URL {
        return fileManager.getSentryPathAsURL().appendingPathComponent("previous.\(field.name).state")
    }
}
