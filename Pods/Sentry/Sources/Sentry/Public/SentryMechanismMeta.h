#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <Foundation/Foundation.h>

@class SentryNSError;

NS_ASSUME_NONNULL_BEGIN

/**
 * The mechanism metadata usually carries error codes reported by the runtime or operating system,
 * along with a platform-dependent interpretation of these codes.
 *
 * See https://develop.sentry.dev/sdk/event-payloads/exception/#meta-information.
 */
NS_SWIFT_NAME(MechanismMeta)
@interface SentryMechanismMeta : NSObject <SentrySerializable>

- (instancetype)init;

/**
 * Information on the POSIX signal. On Apple systems, signals also carry a code in addition to the
 * signal number describing the signal in more detail. On Linux, this code does not exist.
 */
@property (nullable, nonatomic, strong) NSDictionary<NSString *, id> *signal;

/**
 * A Mach Exception on Apple systems comprising a code triple and optional descriptions.
 */
@property (nullable, nonatomic, strong) NSDictionary<NSString *, id> *machException;

/**
 * Sentry uses the NSErrors domain and code for grouping. Only domain and code are serialized.
 */
@property (nullable, nonatomic, strong) SentryNSError *error;

@end

NS_ASSUME_NONNULL_END
