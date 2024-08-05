#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryStreamable

- (NSInputStream *)asInputStream;

- (NSInteger)streamSize;

@end

/**
 * This is a partial implementation of the MessagePack format.
 * We only need to concatenate a list of NSData into an envelope item.
 */
@interface SentryMsgPackSerializer : NSObject

+ (BOOL)serializeDictionaryToMessagePack:
            (NSDictionary<NSString *, id<SentryStreamable>> *)dictionary
                                intoFile:(NSURL *)path;

@end

@interface
NSData (inputStreameble) <SentryStreamable>
@end

@interface
NSURL (inputStreameble) <SentryStreamable>
@end

NS_ASSUME_NONNULL_END
