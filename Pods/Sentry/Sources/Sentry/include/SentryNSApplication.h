#import "SentryApplication.h"
#import "SentryDefines.h"

#if TARGET_OS_OSX

NS_ASSUME_NONNULL_BEGIN

/**
 * A helper tool to retrieve informations from the application instance.
 */
@interface SentryNSApplication : NSObject <SentryApplication>

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX
