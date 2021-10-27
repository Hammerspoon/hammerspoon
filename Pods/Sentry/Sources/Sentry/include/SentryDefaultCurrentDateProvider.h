#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(DefaultCurrentDateProvider)
@interface SentryDefaultCurrentDateProvider : NSObject <SentryCurrentDateProvider>
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
