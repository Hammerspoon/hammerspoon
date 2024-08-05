@_implementationOnly import _SentryPrivate
import Foundation

@objc class SentryMetricsClient: NSObject {
    
    /// Exposing envelopes to Swift code is challenging because the
    /// SentryEnvelope.h is part of the podspec SentryHybridPublic, which causes
    /// problems. As the envelope logic is simple, we keep it in ObjC and do the
    /// rest in Swift.
    private let client: SentryStatsdClient
    
    @objc init(client: SentryStatsdClient) {
        self.client = client
    }
    
    func capture(flushableBuckets: [BucketTimestamp: [Metric]]) {        
        client.captureStatsdEncodedData(encodeToStatsd(flushableBuckets: flushableBuckets))
    }
}
