#import <Foundation/Foundation.h>

@class SentryId;
@class SentrySpanId;
@class SentryTraceHeader;

NS_ASSUME_NONNULL_BEGIN

@interface SentryPropagationContext : NSObject

@property (nonatomic, strong) SentryId *traceId;
@property (nonatomic, strong) SentrySpanId *spanId;
@property (nonatomic, readonly) SentryTraceHeader *traceHeader;

- (NSDictionary<NSString *, NSString *> *)traceContextForEvent;

@end

NS_ASSUME_NONNULL_END
