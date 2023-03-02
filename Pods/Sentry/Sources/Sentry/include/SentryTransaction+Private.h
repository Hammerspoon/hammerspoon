#import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransaction (Private)

- (void)setMeasurementValue:(id)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
