#import "SentryDefines.h"
#import <Foundation/Foundation.h>

// Span operations are short string identifiers that categorize the type of operation a span is
// measuring.
//
// They follow a hierarchical dot notation format (e.g., `ui.load.initial_display`) to group related
// operations. These identifiers help organize and analyze performance data across different types
// of operations.
//
// - Note: See [Sentry SDK development
// documentation](https://develop.sentry.dev/sdk/telemetry/traces/span-operations/) for more
// information.
// - Remark: These constants were originally implemented as a Swift-like enum with associated String
// values, but due to potential Swift-to-Objective-C interoperability issues (see
// [GH-4887](https://github.com/getsentry/sentry-cocoa/issues/4887)), they were moved from Swift to
// Objective-C.
//
// - Note: The following constants are defined as `extern` with an `.m` implementation file, as we
// did face compliation errors in tests and sample apps not being able to import the constants, i.e.
// `Undefined symbol: _SentrySpanOperationUiLoad`. We might want to revisit this in the future.

SENTRY_EXTERN NSString *const SentrySpanOperationAppLifecycle;

SENTRY_EXTERN NSString *const SentrySpanOperationCoredataFetchOperation;
SENTRY_EXTERN NSString *const SentrySpanOperationCoredataSaveOperation;

SENTRY_EXTERN NSString *const SentrySpanOperationFileRead;
SENTRY_EXTERN NSString *const SentrySpanOperationFileWrite;
SENTRY_EXTERN NSString *const SentrySpanOperationFileCopy;
SENTRY_EXTERN NSString *const SentrySpanOperationFileRename;
SENTRY_EXTERN NSString *const SentrySpanOperationFileDelete;

SENTRY_EXTERN NSString *const SentrySpanOperationNetworkRequestOperation;

SENTRY_EXTERN NSString *const SentrySpanOperationUiAction;
SENTRY_EXTERN NSString *const SentrySpanOperationUiActionClick;

SENTRY_EXTERN NSString *const SentrySpanOperationUiLoad;

SENTRY_EXTERN NSString *const SentrySpanOperationUiLoadInitialDisplay;
SENTRY_EXTERN NSString *const SentrySpanOperationUiLoadFullDisplay;
