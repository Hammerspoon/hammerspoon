#import "SentryDefines.h"

@class SentryEvent;

typedef SentryEvent *__nullable (^SentryEventProcessor)(SentryEvent *_Nonnull event);

NS_ASSUME_NONNULL_BEGIN

@interface SentryGlobalEventProcessor : NSObject

@property (nonatomic, strong) NSMutableArray<SentryEventProcessor> *processors;

- (void)addEventProcessor:(SentryEventProcessor)newProcessor;

- (nullable SentryEvent *)reportAll:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
