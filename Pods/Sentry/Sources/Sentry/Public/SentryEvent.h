#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryThread, SentryException, SentryStacktrace, SentryUser, SentryDebugMeta, SentryContext,
    SentryBreadcrumb, SentryId, SentryMessage, SentryRequest;

NS_SWIFT_NAME(Event)
@interface SentryEvent : NSObject <SentrySerializable>

/**
 * This will be set by the initializer.
 */
@property (nonatomic, strong) SentryId *eventId;

/**
 * Message of the event.
 */
@property (nonatomic, strong) SentryMessage *_Nullable message;

/**
 * The error of the event. This property adds convenience to access the error directly in
 * @c beforeSend. This property is not serialized. Instead when preparing the event the
 * @c SentryClient puts the error and any underlying errors into exceptions.
 */
@property (nonatomic, copy) NSError *_Nullable error;

/**
 * @c NSDate of when the event occurred.
 */
@property (nonatomic, strong) NSDate *_Nullable timestamp;

/**
 * @c NSDate of when the event started, mostly useful if event type transaction.
 */
@property (nonatomic, strong) NSDate *_Nullable startTimestamp;

/**
 * @c SentryLevel of the event.
 */
@property (nonatomic) enum SentryLevel level;

/**
 * This will be used for symbolicating on the server should be "cocoa".
 */
@property (nonatomic, copy) NSString *platform;

/**
 * Define the logger name.
 */
@property (nonatomic, copy) NSString *_Nullable logger;

/**
 * Define the server name.
 */
@property (nonatomic, copy) NSString *_Nullable serverName;

/**
 * @note This property will be filled before the event is sent.
 * @warning This is maintained automatically, and shouldn't normally need to be modified.
 */
@property (nonatomic, copy) NSString *_Nullable releaseName;

/**
 * @note This property will be filled before the event is sent.
 * @warning This is maintained automatically, and shouldn't normally need to be modified.
 */
@property (nonatomic, copy) NSString *_Nullable dist;

/**
 * The environment used for this event.
 */
@property (nonatomic, copy) NSString *_Nullable environment;

/**
 * The name of the transaction which caused this event.
 */
@property (nonatomic, copy) NSString *_Nullable transaction;

/**
 * The type of the event, null, default or transaction.
 */
@property (nonatomic, copy) NSString *_Nullable type;

/**
 * Arbitrary key:value (string:string ) data that will be shown with the event.
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable tags;

/**
 * Arbitrary additional information that will be sent with the event.
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *_Nullable extra;

/**
 * Information about the SDK. For example:
 * @code
 * {
 *  version: "6.0.1",
 *  name: "sentry.cocoa",
 *  integrations: [
 *      "react-native"
 *  ],
 *  features: ["performanceV2"]
 * }
 * @endcode
 * @warning This is automatically maintained and should not normally need to be modified.
 */
@property (nonatomic, strong) NSDictionary<NSString *, id> *_Nullable sdk;

/**
 * Modules of the event.
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *_Nullable modules;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property (nonatomic, strong) NSArray<NSString *> *_Nullable fingerprint;

/**
 * Set the @c SentryUser for the event.
 */
@property (nonatomic, strong) SentryUser *_Nullable user;

/**
 * This object contains meta information.
 * @warning This is maintained automatically, and shouldn't normally need to be modified.
 */
@property (nonatomic, strong)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *_Nullable context;

/**
 * Contains @c SentryThread if a crash occurred or for a user reported exception.
 */
@property (nonatomic, strong) NSArray<SentryThread *> *_Nullable threads;

/**
 * General information about the @c SentryException. Multiple exceptions indicate a chain of
 * exceptions encountered, starting with the oldest at the beginning of the array.
 */
@property (nonatomic, strong) NSArray<SentryException *> *_Nullable exceptions;

/**
 * Separate @c SentryStacktrace that can be sent with the event, besides threads.
 */
@property (nonatomic, strong) SentryStacktrace *_Nullable stacktrace;

/**
 * Containing images loaded during runtime.
 */
@property (nonatomic, strong) NSArray<SentryDebugMeta *> *_Nullable debugMeta;

/**
 * This contains all breadcrumbs available at the time when the event
 * occurred/will be sent.
 */
@property (nonatomic, strong) NSArray<SentryBreadcrumb *> *_Nullable breadcrumbs;

/**
 * Set the HTTP request information.
 */
@property (nonatomic, strong, nullable) SentryRequest *request;

/**
 * Init an @c SentryEvent will set all needed fields by default.
 */
- (instancetype)init;

/**
 * Init a @c SentryEvent with a @c SentryLevelError and set all needed fields by default.
 */
- (instancetype)initWithLevel:(enum SentryLevel)level NS_DESIGNATED_INITIALIZER;

/**
 * Initializes a @c SentryEvent with an @c NSError and sets the level to @c SentryLevelError.
 * @param error The error of the event.
 */
- (instancetype)initWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
