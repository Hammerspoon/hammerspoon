#import <SentryOptions.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOptions (Private)

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultTracesSampleRate;

- (BOOL)isValidSampleRate:(NSNumber *)sampleRate;

- (BOOL)isValidTracesSampleRate:(NSNumber *)tracesSampleRate;

@end

NS_ASSUME_NONNULL_END
