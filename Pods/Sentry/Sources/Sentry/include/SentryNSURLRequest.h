#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn;
@class SentryEvent;

@interface SentryNSURLRequest : NSMutableURLRequest

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn
                                         andEvent:(SentryEvent *)event
                                 didFailWithError:(NSError *_Nullable *_Nullable)error;

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn
                                          andData:(NSData *)data
                                 didFailWithError:(NSError *_Nullable *_Nullable)error;

- (_Nullable instancetype)initEnvelopeRequestWithDsn:(SentryDsn *)dsn
                                             andData:(NSData *)data
                                    didFailWithError:(NSError *_Nullable *_Nullable)error;

- (instancetype)initEnvelopeRequestWithURL:(NSURL *)url
                                   andData:(NSData *)data
                                authHeader:(nullable NSString *)authHeader
                          didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
