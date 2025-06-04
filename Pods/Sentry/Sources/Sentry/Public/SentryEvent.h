#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentrySerializable)

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;
@class SentryContext;
@class SentryDebugMeta;
@class SentryException;
@class SentryId;
@class SentryMessage;
@class SentryRequest;
@class SentryStacktrace;
@class SentryThread;
@class SentryUser;

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

/**
 * Subclass of SentryEvent so we can add the Decodable implementation via a Swift extension. We need
 * this due to our mixed use of public Swift and ObjC classes. We could avoid this class by
 * converting SentryReplayEvent back to ObjC, but we rather accept this tradeoff as we want to
 * convert all public classes to Swift in the future. This class needs to be public as we can't add
 * the Decodable extension implementation to a class that is not public.
 *
 * @note: We can’t add the extension for Decodable directly on SentryEvent, because we get an error
 * in SentryReplayEvent: 'required' initializer 'init(from:)' must be provided by subclass of
 * 'Event' Once we add the initializer with required convenience public init(from decoder: any
 * Decoder) throws { fatalError("init(from:) has not been implemented")
 * }
 * we get the error initializer 'init(from:)' is declared in extension of 'Event' and cannot be
 * overridden. Therefore, we add the Decodable implementation not on the Event, but to a subclass of
 * the event.
 */
@interface SentryEventDecodable : SentryEvent

@end

NS_ASSUME_NONNULL_END
