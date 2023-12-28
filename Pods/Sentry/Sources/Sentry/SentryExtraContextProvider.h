#import <Foundation/Foundation.h>

@class SentryCrashWrapper;
@class SentryNSProcessInfoWrapper;
@class SentryUIDeviceWrapper;

NS_ASSUME_NONNULL_BEGIN

/**
 * Provider of dynamic context data that we need to read at the time of an exception.
 */
@interface SentryExtraContextProvider : NSObject

- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
                  processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper;

- (NSDictionary *)getExtraContext;

@end

NS_ASSUME_NONNULL_END
