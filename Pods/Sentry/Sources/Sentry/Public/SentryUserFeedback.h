#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryId;

/**
 * Adds additional information about what happened to an event.
 */
NS_SWIFT_NAME(UserFeedback)
@interface SentryUserFeedback : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Initializes SentryUserFeedback and sets the required eventId.
 *
 * @param eventId The eventId of the event to which the user feedback is associated.
 */
- (instancetype)initWithEventId:(SentryId *)eventId;

/**
 * The eventId of the event to which the user feedback is associated.
 */
@property (readonly, nonatomic, strong) SentryId *eventId;

/**
 * The name of the user.
 */
@property (nonatomic, copy) NSString *name;

/**
 * The email of the user.
 */
@property (nonatomic, copy) NSString *email;

/**
 * Comments of the user about what happened.
 */
@property (nonatomic, copy) NSString *comments;

@end

NS_ASSUME_NONNULL_END
