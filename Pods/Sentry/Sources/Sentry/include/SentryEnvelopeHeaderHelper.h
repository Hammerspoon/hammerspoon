@import Foundation;

@class SentryIdWrapper;
@class SentryEvent;

NS_ASSUME_NONNULL_BEGIN

// This class allows creation of SentryEnvelopeHeader from SentryEvent. We can't do
// this in Swift because SentryEvent is written in ObjC but SentryId is in Swift.
// Once SentryEvent gets converted to Swift we wouldn't need this class because we
// could do it directly in Swift.
@interface SentryEnvelopeHeaderHelper : NSObject

+ (SentryIdWrapper *)headerIdFromEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
