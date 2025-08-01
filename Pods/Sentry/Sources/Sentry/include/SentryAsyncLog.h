#ifndef SentryAsyncLog_h
#define SentryAsyncLog_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Wrapper for initializing async-safe logging functionality.
 * This is used for crash-safe logging that can write to a file even during crashes.
 */
@interface SentryAsyncLogWrapper : NSObject

/**
 * Initializes the async log file in the Sentry cache directory.
 * This method sets up async-safe logging that can be used during crash scenarios.
 */
+ (void)initializeAsyncLogFile;

@end

NS_ASSUME_NONNULL_END

#endif // SentryAsyncLog_h