@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryEnvelopeItem: NSObject {
    
    // MARK: - Properties
    
    /**
     * The envelope item header.
     */
    @objc public let header: SentryEnvelopeItemHeader
    
    /**
     * The envelope payload.
     */
    @objc public let data: Data?
    
    // MARK: - Initializers
    
    /**
     * Designated initializer for creating an envelope item with a header and data.
     */
    @objc public init(header: SentryEnvelopeItemHeader, data: Data?) {
        self.header = header
        self.data = data
    }
    
    /**
     * Initializes an envelope item with an event.
     */
    @objc public convenience init(event: Event) {
        var json = SentrySerializationSwift.data(withJSONObject: event.serialize())
        if json == nil {
            // We don't know what caused the serialization to fail.
            let errorEvent = Event()
            SentryLevelBridge.setBreadcrumbLevelOn(errorEvent, level: SentryLevel.warning.rawValue)
            
            // Add some context to the event. We can only set simple properties otherwise we
            // risk that the conversion fails again.
            let message = "JSON conversion error for event with message: '\(event.message?.description ?? "")'"
            errorEvent.message = SentryMessage(formatted: message)
            errorEvent.releaseName = event.releaseName
            errorEvent.environment = event.environment
            errorEvent.platform = event.platform
            errorEvent.timestamp = event.timestamp
            
            // We accept the risk that this simple serialization fails. Therefore we ignore the
            // error on purpose.
            json = SentrySerializationSwift.data(withJSONObject: errorEvent.serialize())
        }
            
            // event.type can be nil and the server infers error if there's a stack trace, otherwise
            // default. In any case in the envelope type it should be event. Except for transactions
        let envelopeType = event.type == SentryEnvelopeItemTypes.transaction ? SentryEnvelopeItemTypes.transaction : (event.type == SentryEnvelopeItemTypes.feedback ? SentryEnvelopeItemTypes.feedback : SentryEnvelopeItemTypes.event)
            
        let itemHeader = SentryEnvelopeItemHeader(type: envelopeType, length: UInt(json?.count ?? 0))
        self.init(header: itemHeader, data: json)
    }
    
    /**
     * Initializes an envelope item with a session.
     */
    @objc public convenience init(session: SentrySession) {
        let json = try? JSONSerialization.data(withJSONObject: session.serialize(), options: [])
        let itemHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.session, length: UInt(json?.count ?? 0))
        self.init(header: itemHeader, data: json)
    }
    
    #if !SDK_V9
    /**
     * @deprecated Building the envelopes for the new @c SentryFeedback type is done directly in @c
     * -[SentryClient @c captureFeedback:withScope:]
     */
    @available(*, deprecated, message: "Building the envelopes for the new SentryFeedback type is done directly in -[SentryClient captureFeedback:withScope:] so there will be no analog to this initializer for SentryFeedback at this time.")
    @objc public convenience init(userFeedback: UserFeedback) {
        do {
            let json = try JSONSerialization.data(withJSONObject: userFeedback.serialize(), options: [])
            let itemHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.userFeedback, length: UInt(json.count))
            self.init(header: itemHeader, data: json)
        } catch {
            SentrySDKLog.error("Couldn't serialize user feedback.")
            let itemHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.userFeedback, length: 0)
            self.init(header: itemHeader, data: Data())
        }
    }
    #endif // !SDK_V9
    
    /**
     * Initializes an envelope item with an attachment.
     * @param attachment The attachment to create the envelope item from.
     * @param maxAttachmentSize The maximum allowed size for the attachment.
     * @return The envelope item or nil if the attachment is too large or cannot be processed.
     */
    @objc public convenience init?(attachment: Attachment, maxAttachmentSize: UInt) {
        var data: Data?
        
        if let attachmentData = attachment.data {
            if attachmentData.count > maxAttachmentSize {
                SentrySDKLog.debug("Dropping attachment with filename '\(attachment.filename)', because the size of the passed data with \(attachmentData.count) bytes is bigger than the maximum allowed attachment size of \(maxAttachmentSize) bytes.")
                return nil
            }
            
            #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
            if ProcessInfo.processInfo.arguments.contains("--io.sentry.other.base64-attachment-data") {
                data = attachmentData.base64EncodedString().data(using: .utf8)
            } else {
                data = attachmentData
            }
            #else
            data = attachmentData
            #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        } else if let attachmentPath = attachment.path {
            do {
                let fileManager = FileManager.default
                let attributes = try fileManager.attributesOfItem(atPath: attachmentPath)
                
                if let fileSize = attributes[.size] as? UInt64, fileSize > maxAttachmentSize {
                    SentrySDKLog.debug("Dropping attachment, because the size of the it located at '\(attachmentPath)' with \(fileSize) bytes is bigger than the maximum allowed attachment size of \(maxAttachmentSize) bytes.")
                    return nil
                }
                
                #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
                if ProcessInfo.processInfo.arguments.contains("--io.sentry.other.base64-attachment-data") {
                    let fileData = fileManager.contents(atPath: attachmentPath)
                    data = fileData?.base64EncodedString().data(using: .utf8)
                } else {
                    data = fileManager.contents(atPath: attachmentPath)
                }
                #else
                data = fileManager.contents(atPath: attachmentPath)
                #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
            } catch {
                SentrySDKLog.error("Couldn't check file size of attachment with path: \(attachmentPath). Error: \(error.localizedDescription)")
                return nil
            }
        }
        
        guard let finalData = data else {
            SentrySDKLog.error("Couldn't init Attachment.")
            return nil
        }
        
        let itemHeader = SentryEnvelopeAttachmentHeader(
            type: SentryEnvelopeItemTypes.attachment,
            length: UInt(finalData.count),
            filename: attachment.filename,
            contentType: attachment.contentType,
            attachmentType: attachment.attachmentType
        )
        
        self.init(header: itemHeader, data: finalData)
    }
    
    // MARK: - Private Initializers
    
    /**
     * Initializes an envelope item with a client report.
     */
    @objc public convenience init(clientReport: SentryClientReport) {
        do {
            let json = try JSONSerialization.data(withJSONObject: clientReport.serialize(), options: [])
            let itemHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.clientReport, length: UInt(json.count))
            self.init(header: itemHeader, data: json)
        } catch {
            SentrySDKLog.error("Couldn't serialize client report.")
            let itemHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.clientReport, length: 0)
            self.init(header: itemHeader, data: Data())
        }
    }
    
    /**
     * Initializes an envelope item with replay event and recording data.
     */
    @objc public convenience init?(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, video: URL) {
        guard let replayEventData = SentrySerializationSwift.data(withJSONObject: replayEvent.serialize()) else {
            SentrySDKLog.error("Could not serialize replay event data for envelope item. Event will be nil.")
            return nil
        }
        
        guard let recording = replayRecording.data() else {
            SentrySDKLog.error("Could not serialize replay recording data for envelope item. Recording will be nil.")
            return nil
        }
        
        let envelopeContentUrl = video.deletingPathExtension().appendingPathExtension("dat")
        
        let pack: [String: SentryStreamable] = [
            "replay_event": replayEventData as NSData,
            "replay_recording": recording as NSData,
            "replay_video": video as NSURL
        ]
        let success = SentryMsgPackSerializer.serializeDictionary(toMessagePack:
            pack,
            intoFile: envelopeContentUrl
        )
        
        guard success else {
            SentrySDKLog.error("Could not create MessagePack for session replay envelope item.")
            return nil
        }
        
        let envelopeItemContent = try? Data(contentsOf: envelopeContentUrl)
        do {
            try FileManager.default.removeItem(at: envelopeContentUrl)
        } catch {
            SentrySDKLog.error("Could not delete temporary replay content from disk: \(error)")
        }
        
        let itemHeader = SentryEnvelopeItemHeader(type: SentryEnvelopeItemTypes.replayVideo, length: UInt(envelopeItemContent?.count ?? 0))
        self.init(header: itemHeader, data: envelopeItemContent)
    }
}
