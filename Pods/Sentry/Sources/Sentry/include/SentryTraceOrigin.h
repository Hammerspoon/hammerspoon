#import "SentryDefines.h"
#import <Foundation/Foundation.h>

// Trace origin indicates what created a trace or a span.
//
// The origin is of type string and consists of four parts:
// `<type>.<category>.<integration-name>.<integration-part>`.
//
// Only the first is mandatory. The parts build upon each other, meaning it is forbidden to skip one
// part. For example, you may send parts one and two but aren't allowed to send parts one and three
// without part two.
//
// - Note: See [Sentry SDK development
// documentation](https://develop.sentry.dev/sdk/telemetry/traces/trace-origin/) for more
// information.
// - Remark: Since Objective-C does not have enums with associated string values like Swift, this is
// implemented as an `NSString` constant list.
//
// - Note: The following constants are defined as `extern` with an `.m` implementation file, as we
// did face compliation errors in tests and sample apps not being able to import the constants, i.e.
// `Undefined symbol: _SentrySpanOperationUiLoad`. We might want to revisit this in the future.

SENTRY_EXTERN NSString *const SentryTraceOriginAutoAppStart;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoAppStartProfile;

SENTRY_EXTERN NSString *const SentryTraceOriginAutoDBCoreData;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoHttpNSURLSession;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoNSData;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoUiEventTracker;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoUITimeToDisplay;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoUIViewController;

SENTRY_EXTERN NSString *const SentryTraceOriginManual;
SENTRY_EXTERN NSString *const SentryTraceOriginManualFileData;
SENTRY_EXTERN NSString *const SentryTraceOriginManualUITimeToDisplay;
