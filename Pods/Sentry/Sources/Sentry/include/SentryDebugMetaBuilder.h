#import "SentryCrashBinaryImageProvider.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugMetaBuilder : NSObject
SENTRY_NO_INIT

- (id)initWithBinaryImageProvider:(id<SentryCrashBinaryImageProvider>)binaryImageProvider;

- (NSArray<SentryDebugMeta *> *)buildDebugMeta;

@end

NS_ASSUME_NONNULL_END
