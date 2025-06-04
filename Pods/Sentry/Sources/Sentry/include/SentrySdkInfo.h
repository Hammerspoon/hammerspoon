#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#if __has_include(<Sentry/SentryInternalSerializable.h>)
#    import <Sentry/SentryInternalSerializable.h>
#else
#    import "SentryInternalSerializable.h"
#endif

#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes the Sentry SDK and its configuration used to capture and transmit an event.
 * @note Both name and version are required.
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@interface SentrySdkInfo : NSObject <SentryInternalSerializable>
SENTRY_NO_INIT

+ (instancetype)global;

/**
 * The name of the SDK. Examples: sentry.cocoa, sentry.cocoa.vapor, ...
 */
@property (nonatomic, readonly, copy) NSString *name;

/**
 * The version of the SDK. It should have the Semantic Versioning format MAJOR.MINOR.PATCH, without
 * any prefix (no v or anything else in front of the major version number). Examples:
 * 0.1.0, 1.0.0, 2.0.0-beta0
 */
@property (nonatomic, readonly, copy) NSString *version;

/**
 * A list of names identifying enabled integrations. The list should
 * have all enabled integrations, including default integrations. Default
 * integrations are included because different SDK releases may contain different
 * default integrations.
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *integrations;

/**
 * A list of feature names identifying enabled SDK features. This list
 * should contain all enabled SDK features. On some SDKs, enabling a feature in the
 * options also adds an integration. We encourage tracking such features with either
 * integrations or features but not both to reduce the payload size.
 */
@property (nonatomic, readonly, copy) NSArray<NSString *> *features;

/**
 * A list of packages that were installed as part of this SDK or the
 * activated integrations. Each package consists of a name in the format
 * source:identifier and version.
 */
@property (nonatomic, readonly, copy) NSArray<NSDictionary<NSString *, NSString *> *> *packages;

- (instancetype)initWithOptions:(SentryOptions *_Nullable)options;

- (instancetype)initWithName:(NSString *)name
                     version:(NSString *)version
                integrations:(NSArray<NSString *> *)integrations
                    features:(NSArray<NSString *> *)features
                    packages:(NSArray<NSDictionary<NSString *, NSString *> *> *)packages
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
