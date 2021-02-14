#import "SentryDefines.h"

@class SentryEvent;

typedef SentryEvent *__nullable (^SentryEventProcessor)(SentryEvent *_Nonnull event);

NS_ASSUME_NONNULL_BEGIN

@interface SentryGlobalEventProcessor : NSObject
SENTRY_NO_INIT

@property (nonatomic, strong) NSMutableArray<SentryEventProcessor> *processors;

+ (instancetype)shared;

- (void)addEventProcessor:(SentryEventProcessor)newProcessor;

@end

NS_ASSUME_NONNULL_END
