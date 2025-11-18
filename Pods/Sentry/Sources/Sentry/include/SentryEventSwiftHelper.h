#import <Foundation/Foundation.h>

@class SentryEvent;

NS_ASSUME_NONNULL_BEGIN

@interface SentryEventSwiftHelper : NSObject

+ (void)setEventIdString:(NSString *)idString event:(SentryEvent *)event;

+ (NSString *)getEventIdString:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
