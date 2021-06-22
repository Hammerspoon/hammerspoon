#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryNSError, SentryMechanismMeta;

NS_SWIFT_NAME(Mechanism)
@interface SentryMechanism : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * A unique identifier of this mechanism determining rendering and processing
 * of the mechanism data
 */
@property (nonatomic, copy) NSString *type;

/**
 * Human readable description of the error mechanism and a possible hint on how to solve this error.
 * We can't use description as it overlaps with NSObject.description.
 */
@property (nonatomic, copy) NSString *_Nullable desc;

/**
 * Arbitrary extra data that might help the user understand the error thrown by
 * this mechanism
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *_Nullable data;

/**
 * Flag indicating whether the exception has been handled by the user
 * (e.g. via ``try..catch``)
 */
@property (nonatomic, copy) NSNumber *_Nullable handled;

/**
 * Fully qualified URL to an online help resource, possible
 * interpolated with error parameters
 */
@property (nonatomic, copy) NSString *_Nullable helpLink;

/**
 * Information from the operating system or runtime on the exception
 * mechanism.
 */
@property (nullable, nonatomic, strong) SentryMechanismMeta *meta;

/**
 * Initialize an SentryMechanism with a type
 * @param type String
 * @return SentryMechanism
 */
- (instancetype)initWithType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
