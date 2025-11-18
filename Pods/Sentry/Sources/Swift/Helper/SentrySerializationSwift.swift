@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentrySerializationSwift: NSObject {
    @objc(sessionWithData:) public static func session(with data: Data) -> SentrySession? {
        do {
            guard let sessionDictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let session = SentrySession(jsonObject: sessionDictionary) else {
                SentrySDKLog.error("Failed to initialize session from dictionary. Dropping it.")
                return nil
            }

            guard let releaseName = session.releaseName, !releaseName.isEmpty else {
                SentrySDKLog.error("Deserialized session doesn't contain a release name. Dropping it.")
                return nil
            }
            return session
        } catch {
            SentrySDKLog.error("Failed to deserialize session data \(error)")
            return nil
        }
    }

    @objc(appStateWithData:) public static func appState(with data: Data) -> SentryAppState? {
      do {
          guard let appStateDictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
              return nil
          }
          return SentryAppState(jsonObject: appStateDictionary)
      } catch {
        SentrySDKLog.error("Failed to deserialize app state data \(error)")
        return nil
      }
    }
    
    @objc(dataWithJSONObject:) public static func data(withJSONObject jsonObject: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(jsonObject) else {
            SentrySDKLog.error("Dictionary is not a valid JSON object.")
            return nil
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: jsonObject)
        } catch {
            SentrySDKLog.error("Internal error while serializing JSON: \(error)")
        }
        return nil
    }
    
    @objc(dataWithEnvelope:) public static func data(with envelope: SentryEnvelope) -> Data? {
        var envelopeData = Data()
        var serializedData: [String: Any] = [:]
        if let eventId = envelope.header.eventId {
            serializedData["event_id"] = eventId.sentryIdString
        }
        
        if let sdkInfo = envelope.header.sdkInfo {
            serializedData["sdk"] = sdkInfo.serialize()
        }
        
        if let traceContext = envelope.header.traceContext {
            serializedData["trace"] = traceContext.serialize()
        }
        
        if let sentAt = envelope.header.sentAt {
            serializedData["sent_at"] = sentry_toIso8601String(sentAt)
        }
        guard let header = SentrySerializationSwift.data(withJSONObject: serializedData) else {
            SentrySDKLog.error("Envelope header cannot be converted to JSON.")
            return nil
        }
        envelopeData.append(header)
        let newLineData = Data("\n".utf8)
        for i in 0..<envelope.items.count {
            envelopeData.append(newLineData)
            let serializedItemHeaderData = envelope.items[i].header.serialize()
            guard let itemHeader = SentrySerializationSwift.data(withJSONObject: serializedItemHeaderData) else {
                SentrySDKLog.error("Envelope item header cannot be converted to JSON.")
                return nil
            }
            envelopeData.append(itemHeader)
            envelopeData.append(newLineData)
            if let itemData = envelope.items[i].data {
                envelopeData.append(itemData)
            }
        }
        
        return envelopeData
    }
    
    @objc(dataWithSession:) public static func data(with session: SentrySession) -> Data? {
        data(withJSONObject: session.serialize())
    }
    
    //swiftlint:disable cyclomatic_complexity function_body_length
    @objc(envelopeWithData:) public static func envelope(with data: Data) -> SentryEnvelope? {
        let newline = UInt8(ascii: "\n")
        var envelopeHeader: SentryEnvelopeHeader?
        let bytes = [UInt8](data)
        var envelopeHeaderIndex: Int = 0
        
        for i in 0..<data.count {
            if bytes[i] == newline {
                envelopeHeaderIndex = i
                // Envelope header end
                let headerData = data.subdata(in: 0..<i)
                #if DEBUG
                  if let headerString = String(data: headerData, encoding: .utf8) {
                    SentrySDKLog.debug("Header \(headerString)")
                  }
                #endif
                do {
                    let headerDictionary = try JSONSerialization.jsonObject(with: headerData) as? [String: Any]
                    var eventId: SentryId?
                    if let eventIdAsString = headerDictionary?["event_id"] as? String {
                        eventId = SentryId(uuidString: eventIdAsString)
                    }
                    
                    var sdkInfo: SentrySdkInfo?
                    if let sdkDict = headerDictionary?["sdk"] as? [String: Any] {
                        sdkInfo = SentrySdkInfo(dict: sdkDict)
                    }

                    var traceContext: TraceContext?
                    if let traceDict = headerDictionary?["trace"] as? [String: Any] {
                        traceContext = TraceContext(dict: traceDict)
                    }
                    
                    envelopeHeader = SentryEnvelopeHeader(id: eventId,
                                                      sdkInfo: sdkInfo,
                                                      traceContext: traceContext)

                    if let sentAtStr = headerDictionary?["sent_at"] as? String {
                        envelopeHeader?.sentAt = sentry_fromIso8601String(sentAtStr)
                    }
                    break
                } catch {
                    SentrySDKLog.error("Failed to parse envelope header \(error)")
                    break
                }
            }
        }
        
        guard let envelopeHeaderUnwrapped = envelopeHeader else {
            SentrySDKLog.error("Invalid envelope. No header found.")
            return nil
        }

        if envelopeHeaderIndex == 0 {
            SentrySDKLog.error("EnvelopeHeader was parsed, its index is expected.")
            return nil
        }
        
        // Parse items
        var itemHeaderStart = envelopeHeaderIndex + 1
        var items: [SentryEnvelopeItem] = []
        let endOfEnvelope = data.count - 1

        var i = itemHeaderStart
        while i <= endOfEnvelope {
            defer {
                i += 1
            }
            if bytes[i] == newline || i == endOfEnvelope {
                let itemHeaderData = (data as NSData).subdata(with: NSRange(location: itemHeaderStart, length: i - itemHeaderStart))

#if DEBUG
                if let itemHeaderString = String(data: itemHeaderData, encoding: .utf8) {
                    SentrySDKLog.debug("Item Header \(itemHeaderString)")
                }
#endif

                do {
                    let headerDictionary = try JSONSerialization.jsonObject(with: itemHeaderData) as? [String: Any]

                    guard let type = headerDictionary?["type"] as? String else {
                        SentrySDKLog.error("Envelope item type is required.")
                        break
                    }

                    let bodyLength = (headerDictionary?["length"] as? NSNumber)?.uintValue ?? 0

                    if i == endOfEnvelope && bodyLength != 0 {
                        SentrySDKLog.error("Envelope item has no data but header indicates its length is \(bodyLength).")
                        break
                    }

                    let filename = headerDictionary?["filename"] as? String
                    let contentType = headerDictionary?["content_type"] as? String
                    let attachmentType = headerDictionary?["attachment_type"] as? String
                    let itemCount = headerDictionary?["item_count"] as? NSNumber

                    let itemHeader: SentryEnvelopeItemHeader
                    if let filename = filename {
                        itemHeader = SentryEnvelopeAttachmentHeader(
                            type: type,
                            length: bodyLength,
                            filename: filename,
                            contentType: contentType,
                            attachmentType: typeForSentryAttachmentName(attachmentType)
                        )
                    } else if let itemCount = itemCount {
                        itemHeader = SentryEnvelopeItemHeader(
                            type: type,
                            length: bodyLength,
                            contentType: contentType,
                            itemCount: itemCount
                        )
                    } else {
                        itemHeader = SentryEnvelopeItemHeader(type: type, length: bodyLength)
                    }

                    if i == endOfEnvelope {
                        i += 1 // 0-byte attachment
                    }

                    if bodyLength > 0 && data.count < (i + 1 + Int(bodyLength)) {
                        SentrySDKLog.error(
                            "Envelope is corrupted or has invalid data. Trying to read \(bodyLength) bytes by skipping \(i + 1) from a buffer of \(data.count) bytes."
                        )
                        return nil
                    }

                    let itemBody = (data as NSData).subdata(with: NSRange(location: i + 1, length: Int(bodyLength)))
                    let envelopeItem = SentryEnvelopeItem(header: itemHeader, data: itemBody)
                    items.append(envelopeItem)

                    i = i + 1 + Int(bodyLength)
                    itemHeaderStart = i
                } catch {
                    SentrySDKLog.error("Failed to parse envelope item header \(error)")
                    return nil
                }
            }
        }

        if items.isEmpty {
            SentrySDKLog.error("Envelope has no items.")
            return nil
        }

        return SentryEnvelope(header: envelopeHeaderUnwrapped, items: items)
    }
    //swiftlint:enable cyclomatic_complexity function_body_length
}
