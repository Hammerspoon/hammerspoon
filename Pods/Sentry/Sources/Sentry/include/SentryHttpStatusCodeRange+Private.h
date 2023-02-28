#import "SentryDefines.h"
#import "SentryHttpStatusCodeRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHttpStatusCodeRange (Private)

- (BOOL)isInRange:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
