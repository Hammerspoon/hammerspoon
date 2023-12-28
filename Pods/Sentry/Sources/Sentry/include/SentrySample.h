#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A storage class to hold the data associated with a single profiler sample. */
@interface SentrySample : NSObject
@property (nonatomic, assign) uint64_t absoluteTimestamp;
@property (nonatomic, strong) NSNumber *stackIndex;
@property (nonatomic, assign) uint64_t threadID;
@property (nullable, nonatomic, copy) NSString *queueAddress;
@end

NS_ASSUME_NONNULL_END
