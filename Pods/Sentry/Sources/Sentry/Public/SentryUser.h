#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#if !SDK_V9
#    import SENTRY_HEADER(SentrySerializable)
#endif // !SDK_V9

NS_ASSUME_NONNULL_BEGIN

@class SentryGeo;

NS_SWIFT_NAME(User)
@interface SentryUser : NSObject
#if SDK_V9
                        <NSCopying>
#else
                        <SentrySerializable, NSCopying>
#endif // SDK_V9

/**
 * Optional: Id of the user
 */
@property (atomic, copy) NSString *_Nullable userId;

/**
 * Optional: Email of the user
 */
@property (atomic, copy) NSString *_Nullable email;

/**
 * Optional: Username
 */
@property (atomic, copy) NSString *_Nullable username;

/**
 * Optional: IP Address
 */
@property (atomic, copy) NSString *_Nullable ipAddress;

#if !SDK_V9
/**
 * The user segment, for apps that divide users in user segments.
 * @deprecated This field will be removed in the next major version.
 */
@property (atomic, copy) NSString *_Nullable segment DEPRECATED_MSG_ATTRIBUTE(
    "This field is deprecated and will be removed in the next major update.");
#endif // !SDK_V9

/**
 * Optional: Human readable name
 */
@property (atomic, copy) NSString *_Nullable name;

/**
 * Optional: Geo location of user
 */
@property (nullable, nonatomic, strong) SentryGeo *geo;

/**
 * Optional: Additional data
 */
@property (atomic, strong) NSDictionary<NSString *, id> *_Nullable data;

/**
 * Initializes a SentryUser with the id
 * @param userId NSString
 * @return SentryUser
 */
- (instancetype)initWithUserId:(NSString *)userId;

- (instancetype)init;

- (BOOL)isEqual:(id _Nullable)other;

- (BOOL)isEqualToUser:(SentryUser *)user;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
