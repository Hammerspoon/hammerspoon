@_implementationOnly import _SentryPrivate

/// For proper statistics in release health, we need to make sure we don't send session updates
/// without sending a session init first. In other words, we can't drop a session init. The
/// @c SentryFileManager deletes an envelope once the maximum amount of envelopes is stored. When
/// this happens and the envelope to delete contains a session init we look for the next envelope
/// containing a session update for the same session. If such a session envelope is found we migrate
/// the init flag. If none is found we delete the envelope. We don't migrate other envelope items as
/// events.
@_spi(Private) @objc public final class SentryMigrateSessionInit: NSObject {

    /// Checks if the envelope of the passed file path contains an envelope item with a session init. If
    /// it does it iterates over all envelopes and looks for a session with the same session id. If such
    /// a session is found the init flag is set to @c true, the envelope is updated with keeping other
    /// envelope items and headers, and the updated envelope is stored to the disk keeping its path.
    /// @param envelope The envelope to delete
    /// @param envelopesDirPath The path of the directory where the envelopes are stored.
    /// @param envelopeFilePaths An array containing the file paths of envelopes to check if they contain
    /// a session init.
    /// @return @c true if the function migrated the session init. @c false if not.
    @discardableResult @objc(migrateSessionInit:envelopesDirPath:envelopeFilePaths:) public static func migrateSessionInit(envelope: SentryEnvelope?, envelopesDirPath: String, envelopeFilePaths: [String]) -> Bool {
        guard let envelope else {
            return false
        }
        
        for item in envelope.items {
            if item.header.type == SentryEnvelopeItemTypes.session {
                guard let data = item.data else {
                    SentrySDKLog.warning("Could not migrate session init, because the envelope item has no data.")
                    continue
                }
                if let session = SentrySerializationSwift.session(with: data), session.flagInit?.boolValue == true {
                    let didSetInitFlag = Self.setInitFlagOnNextEnvelopeWithSameSessionId(session: session, envelopesDirPath: envelopesDirPath, envelopeFilePaths: envelopeFilePaths)
                    if didSetInitFlag {
                        return true
                    }
                }
            }
        }

        return false
    }
    
    private static func setInitFlagOnNextEnvelopeWithSameSessionId(session: SentrySession, envelopesDirPath: String, envelopeFilePaths: [String]) -> Bool {
        let fileManager = FileManager.default
        for envelopeFilePath in envelopeFilePaths {
            let envelopePath = (envelopesDirPath as NSString).appendingPathComponent(envelopeFilePath)
            guard let envelopeData = fileManager.contents(atPath: envelopePath) else {
                continue
            }
            
            if let envelope = SentrySerializationSwift.envelope(with: envelopeData) {
                let didSetInitFlag = Self.setInitFlagIfContainsSameSessionId(sessionId: session.sessionId, envelope: envelope, envelopeFilePath: envelopePath)
                if didSetInitFlag {
                    return true
                }
            }
        }
        return false
    }
    
    private static func setInitFlagIfContainsSameSessionId(sessionId: UUID, envelope: SentryEnvelope, envelopeFilePath: String) -> Bool {
        for item in envelope.items {
            if item.header.type == SentryEnvelopeItemTypes.session {
                guard let data = item.data else {
                    SentrySDKLog.warning("Could not migrate session init, because the envelope item has no data.")
                    continue
                }
                if let localSession = SentrySerializationSwift.session(with: data), localSession.sessionId == sessionId {
                    localSession.setFlagInit()
                    Self.storeSessionInit(envelope: envelope, session: localSession, envelopeFilePath: envelopeFilePath)
                    return true
                }
            }
        }
        return false
    }
    
    private static func storeSessionInit(envelope originalEnvelope: SentryEnvelope, session: SentrySession, envelopeFilePath: String) {
        
        let envelopeItemsWithUpdatedSession = Self.replaceSessionEnvelopeItem(session: session, onEnvelope: originalEnvelope)
        let envelopeWithInitFlag = SentryEnvelope(header: originalEnvelope.header, items: envelopeItemsWithUpdatedSession)
        let envelopeWithInitFlagData = SentrySerializationSwift.data(with: envelopeWithInitFlag)
        do {
            try (envelopeWithInitFlagData as? NSData)?.write(toFile: envelopeFilePath, options: .atomic)
        } catch {
            SentrySDKLog.error("Could not migrate session init, because storing the updated envelope failed: \(error)")
        }
    }
    
    private static func replaceSessionEnvelopeItem(session: SentrySession, onEnvelope envelope: SentryEnvelope) -> [SentryEnvelopeItem] {
        var itemsWithoutSession = envelope.items.filter { $0.header.type != SentryEnvelopeItemTypes.session }
        let sessionEnvelopeItem = SentryEnvelopeItem(session: session)
        itemsWithoutSession.append(sessionEnvelopeItem)
        return itemsWithoutSession
    }
    
}
