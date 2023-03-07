#import "SentryDefines.h"
#import "SentryMeasurementUnit.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryMeasurementValue : NSObject <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithValue:(NSNumber *)value;

- (instancetype)initWithValue:(NSNumber *)value unit:(SentryMeasurementUnit *)unit;

@property (nonatomic, copy, readonly) NSNumber *value;
@property (nullable, readonly, copy) SentryMeasurementUnit *unit;

@end

NS_ASSUME_NONNULL_END
