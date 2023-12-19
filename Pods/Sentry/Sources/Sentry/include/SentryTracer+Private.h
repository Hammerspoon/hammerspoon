#import "SentryTracer.h"

@interface
SentryTracer ()

@property (nonatomic, strong) SentryHub *hub;

/**
 * We need an immutable identifier to e.g. track concurrent tracers against a static profiler where
 * we can use the same ID as a key in the concurrent bookkeeping. @c SentryTracer.traceId can be
 * changed by consumers so is unfit for this purpose.
 */
@property (nonatomic, strong, readonly) SentryId *internalID;

@end
