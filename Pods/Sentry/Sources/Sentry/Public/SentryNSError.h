#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Sentry representation of an NSError to send to Sentry.
 */
@interface SentryNSError : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * The domain of an NSError.
 */
@property (nonatomic, copy) NSString *domain;

/**
 * The error code of an NSError
 */
@property (nonatomic, assign) NSInteger code;

/**
 * Initializes SentryNSError and sets the domain and code.
 *
 * @param domain The domain of an NSError.
 * @param code The error code of an NSError.
 */
- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END
