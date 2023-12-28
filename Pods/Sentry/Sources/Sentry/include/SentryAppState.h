#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryAppState : NSObject <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithReleaseName:(NSString *)releaseName
                          osVersion:(NSString *)osVersion
                           vendorId:(NSString *)vendorId
                        isDebugging:(BOOL)isDebugging
                systemBootTimestamp:(NSDate *)systemBootTimestamp;

/**
 * Initializes @c SentryAppState from a JSON object.
 * @param jsonObject The @c jsonObject containing the session.
 * @return The @c SentrySession or @c nil if @c jsonObject contains an error.
 */
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

@property (readonly, nonatomic, copy) NSString *releaseName;

@property (readonly, nonatomic, copy) NSString *osVersion;

@property (readonly, nonatomic, copy) NSString *vendorId;

@property (readonly, nonatomic, assign) BOOL isDebugging;

/**
 * The boot time of the system rounded down to seconds. As the precision of the serialization is
 * only milliseconds and a precision of seconds is enough we round down to seconds. With this we
 * avoid getting different dates before and after serialization.
 */
@property (readonly, nonatomic, copy) NSDate *systemBootTimestamp;

@property (nonatomic, assign) BOOL isActive;

@property (nonatomic, assign) BOOL wasTerminated;

@property (nonatomic, assign) BOOL isANROngoing;

@property (nonatomic, assign) BOOL isSDKRunning;

@end

NS_ASSUME_NONNULL_END
