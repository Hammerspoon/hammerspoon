#if __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <Foundation/Foundation.h>

//! Project version number for Sentry.
FOUNDATION_EXPORT double SentryVersionNumber;

//! Project version string for Sentry.
FOUNDATION_EXPORT const unsigned char SentryVersionString[];

#    import <SentryWithoutUIKit/Sentry.h>
#    import <SentryWithoutUIKit/SentryAttachment.h>
#    import <SentryWithoutUIKit/SentryBreadcrumb.h>
#    import <SentryWithoutUIKit/SentryClient.h>
#    import <SentryWithoutUIKit/SentryCrashExceptionApplication.h>
#    import <SentryWithoutUIKit/SentryDebugImageProvider.h>
#    import <SentryWithoutUIKit/SentryDebugMeta.h>
#    import <SentryWithoutUIKit/SentryDefines.h>
#    import <SentryWithoutUIKit/SentryDsn.h>
#    import <SentryWithoutUIKit/SentryEnvelopeItemHeader.h>
#    import <SentryWithoutUIKit/SentryError.h>
#    import <SentryWithoutUIKit/SentryEvent.h>
#    import <SentryWithoutUIKit/SentryException.h>
#    import <SentryWithoutUIKit/SentryFrame.h>
#    import <SentryWithoutUIKit/SentryGeo.h>
#    import <SentryWithoutUIKit/SentryHttpStatusCodeRange.h>
#    import <SentryWithoutUIKit/SentryHub.h>
#    import <SentryWithoutUIKit/SentryMeasurementUnit.h>
#    import <SentryWithoutUIKit/SentryMechanism.h>
#    import <SentryWithoutUIKit/SentryMechanismMeta.h>
#    import <SentryWithoutUIKit/SentryMessage.h>
#    import <SentryWithoutUIKit/SentryNSError.h>
#    import <SentryWithoutUIKit/SentryOptions.h>
#    import <SentryWithoutUIKit/SentryRequest.h>
#    import <SentryWithoutUIKit/SentrySDK.h>
#    import <SentryWithoutUIKit/SentrySampleDecision.h>
#    import <SentryWithoutUIKit/SentrySamplingContext.h>
#    import <SentryWithoutUIKit/SentryScope.h>
#    import <SentryWithoutUIKit/SentrySerializable.h>
#    import <SentryWithoutUIKit/SentrySpanContext.h>
#    import <SentryWithoutUIKit/SentrySpanId.h>
#    import <SentryWithoutUIKit/SentrySpanProtocol.h>
#    import <SentryWithoutUIKit/SentrySpanStatus.h>
#    import <SentryWithoutUIKit/SentryStacktrace.h>
#    import <SentryWithoutUIKit/SentryThread.h>
#    import <SentryWithoutUIKit/SentryTraceHeader.h>
#    import <SentryWithoutUIKit/SentryTransactionContext.h>
#    import <SentryWithoutUIKit/SentryUser.h>
#    import <SentryWithoutUIKit/SentryUserFeedback.h>
#endif // __has_include(<SentryWithoutUIKit/Sentry.h>)
