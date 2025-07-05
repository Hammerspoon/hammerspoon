#import <Foundation/Foundation.h>

@class SentryId;
@class SentrySpanId;
@class SentryTraceHeader;

NS_ASSUME_NONNULL_BEGIN

@interface SentryPropagationContext : NSObject

@property (nonatomic, strong, readonly) SentryId *traceId;
@property (nonatomic, strong, readonly) SentrySpanId *spanId;
@property (nonatomic, readonly) SentryTraceHeader *traceHeader;

- (instancetype)initWithTraceId:(SentryId *)traceId spanId:(SentrySpanId *)spanId;

- (NSDictionary<NSString *, NSString *> *)traceContextForEvent;

@end

NS_ASSUME_NONNULL_END
