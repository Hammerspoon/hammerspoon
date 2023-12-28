#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryStacktrace, SentryMechanism;

NS_SWIFT_NAME(Exception)
@interface SentryException : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * The name of the exception
 */
@property (nonatomic, copy) NSString *value;

/**
 * Type of the exception
 */
@property (nonatomic, copy) NSString *type;

/**
 * Additional information about the exception
 */
@property (nonatomic, strong) SentryMechanism *_Nullable mechanism;

/**
 * Can be set to define the module
 */
@property (nonatomic, copy) NSString *_Nullable module;

/**
 * An optional value which refers to a thread in @c SentryEvent.threads
 */
@property (nonatomic, copy) NSNumber *_Nullable threadId;

/**
 * Stacktrace containing frames of this exception.
 */
@property (nonatomic, strong) SentryStacktrace *_Nullable stacktrace;

/**
 * Initialize an SentryException with value and type
 * @param value String
 * @param type String
 * @return SentryException
 */
- (instancetype)initWithValue:(NSString *)value type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
