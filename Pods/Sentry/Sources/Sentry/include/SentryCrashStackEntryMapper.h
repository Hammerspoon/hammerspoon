#import "SentryCrashDynamicLinker.h"
#import "SentryCrashStackCursor.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryFrame, SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashStackEntryMapper : NSObject
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic;

/**
 * Maps the stackEntry of a SentryCrashStackCursor to SentryFrame.
 * @param stackCursor An with @c SentryCrash initialized @c stackCursor. You can use for example
 * @c sentrycrashsc_initSelfThread.
 */
- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor;

/**
 * Maps a @c SentryCrashStackEntry to @c SentryFrame.
 * @param stackEntry A stack entry retrieved from a thread.
 */
- (SentryFrame *)sentryCrashStackEntryToSentryFrame:(SentryCrashStackEntry)stackEntry;

@end

NS_ASSUME_NONNULL_END
