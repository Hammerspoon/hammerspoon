#import "SentryDefines.h"
#import "SentrySerializable.h"

@class SentryUser, SentrySession, SentryOptions, SentryBreadcrumb;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Scope)
@interface SentryScope : NSObject <SentrySerializable>

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (instancetype)initWithScope:(SentryScope *)scope;

/**
 * Set global user -> thus will be sent with every event
 */
- (void)setUser:(SentryUser *_Nullable)user;

/**
 * Set a global tag. Tags are searchable key/value string pairs attached to
 * every event.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

/**
 * Remove the tag for the specified key.
 */
- (void)removeTagForKey:(NSString *)key NS_SWIFT_NAME(removeTag(key:));

/**
 * Set global tags. Tags are searchable key/value string pairs attached to every
 * event.
 */
- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags;

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras;

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setExtraValue:(id _Nullable)value
               forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Remove the extra for the specified key.
 */
- (void)removeExtraForKey:(NSString *)key NS_SWIFT_NAME(removeExtra(key:));

/**
 * Set dist in the scope
 */
- (void)setDist:(NSString *_Nullable)dist;

/**
 * Set environment in the scope
 */
- (void)setEnvironment:(NSString *_Nullable)environment;

/**
 * Sets the fingerprint in the scope
 */
- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint;

/**
 * Sets the level in the scope
 */
- (void)setLevel:(enum SentryLevel)level;

/**
 * Add a breadcrumb to the scope
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Clears all breadcrumbs in the scope
 */
- (void)clearBreadcrumbs;

/**
 * Serializes the Scope to JSON
 */
- (NSDictionary<NSString *, id> *)serialize;

/**
 * Adds the Scope to the event
 */
- (SentryEvent *__nullable)applyToEvent:(SentryEvent *)event
                          maxBreadcrumb:(NSUInteger)maxBreadcrumbs;

- (void)applyToSession:(SentrySession *)session;

/**
 * Sets context values which will overwrite SentryEvent.context when event is
 * "enrichted" with scope before sending event.
 */
- (void)setContextValue:(NSDictionary<NSString *, id> *)value
                 forKey:(NSString *)key NS_SWIFT_NAME(setContext(value:key:));

/**
 * Remove the context for the specified key.
 */
- (void)removeContextForKey:(NSString *)key NS_SWIFT_NAME(removeContext(key:));

/**
 * Clears the current Scope
 */
- (void)clear;

- (BOOL)isEqual:(id _Nullable)other;

- (BOOL)isEqualToScope:(SentryScope *)scope;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
