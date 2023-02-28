#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSTimerWrapper : NSObject

- (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats
                                      block:(void (^)(NSTimer *timer))block;

@end

NS_ASSUME_NONNULL_END
