#import "PrivatesHeader.h"

#if COCOAPODS
@class SentrySdkInfo, SentryTraceContext;
#else
#    import "SentrySdkInfo.h"
#    import "SentryTraceContext.h"

#endif

@class SentryEvent;
@class SentrySession;
@class SentryId;
@class SentryUserFeedback;
@class SentryAttachment;
@class SentryEnvelopeItemHeader;

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeHeader : NSObject
SENTRY_NO_INIT

/**
 * Initializes an @c SentryEnvelopeHeader object with the specified eventId.
 * @note Sets the @c sdkInfo from @c SentryMeta.
 * @param eventId The identifier of the event. Can be nil if no event in the envelope or attachment
 * related to event.
 */
- (instancetype)initWithId:(SentryId *_Nullable)eventId;

/**
 * Initializes a @c SentryEnvelopeHeader object with the specified @c eventId and @c traceContext.
 * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
 * attachment related to event.
 * @param traceContext Current trace state.
 */
- (instancetype)initWithId:(nullable SentryId *)eventId
              traceContext:(nullable SentryTraceContext *)traceContext;

/**
 * Initializes a @c SentryEnvelopeHeader object with the specified @c eventId, @c skdInfo and
 * @c traceContext. It is recommended to use @c initWithId:traceContext: because it sets the
 * @c sdkInfo for you.
 * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
 * attachment related to event.
 * @param sdkInfo Describes the Sentry SDK. Can be @c nil for backwards compatibility. New
 * instances should always provide a version.
 * @param traceContext Current trace state.
 */
- (instancetype)initWithId:(nullable SentryId *)eventId
                   sdkInfo:(nullable SentrySdkInfo *)sdkInfo
              traceContext:(nullable SentryTraceContext *)traceContext NS_DESIGNATED_INITIALIZER;

/**
 * The event identifier, if available.
 * An event id exist if the envelope contains an event of items within it are related. i.e
 * Attachments
 */
@property (nullable, nonatomic, readonly, copy) SentryId *eventId;

@property (nullable, nonatomic, readonly, copy) SentrySdkInfo *sdkInfo;

@property (nullable, nonatomic, readonly, copy) SentryTraceContext *traceContext;

/**
 * The timestamp when the event was sent from the SDK as string in RFC 3339 format. Used
 * for clock drift correction of the event timestamp. The time zone must be UTC.
 *
 * The timestamp should be generated as close as possible to the transmision of the event,
 * so that the delay between sending the envelope and receiving it on the server-side is
 * minimized.
 */
@property (nullable, nonatomic, copy) NSDate *sentAt;

+ (instancetype)empty;

@end

@interface SentryEnvelopeItem : NSObject
SENTRY_NO_INIT

- (instancetype)initWithEvent:(SentryEvent *)event;
- (instancetype)initWithSession:(SentrySession *)session;
- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback;
- (_Nullable instancetype)initWithAttachment:(SentryAttachment *)attachment
                           maxAttachmentSize:(NSUInteger)maxAttachmentSize;
- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header
                          data:(NSData *)data NS_DESIGNATED_INITIALIZER;

/**
 * The envelope item header.
 */
@property (nonatomic, readonly, strong) SentryEnvelopeItemHeader *header;

/**
 * The envelope payload.
 */
@property (nonatomic, readonly, strong) NSData *data;

@end

@interface SentryEnvelope : NSObject
SENTRY_NO_INIT

// If no event, or no data related to event, id will be null
- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item;

// If no event, or no data related to event, id will be null
- (instancetype)initWithId:(SentryId *_Nullable)id items:(NSArray<SentryEnvelopeItem *> *)items;

/**
 * Initializes a @c SentryEnvelope with a single session.
 * @param session to init the envelope with.
 */
- (instancetype)initWithSession:(SentrySession *)session;

/**
 * Initializes a @c SentryEnvelope with a list of sessions.
 * Can be used when an operation that starts a session closes an ongoing session.
 * @param sessions to init the envelope with.
 */
- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items NS_DESIGNATED_INITIALIZER;

/**
 * Convenience init for a single event.
 */
- (instancetype)initWithEvent:(SentryEvent *)event;

- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback;

/**
 * The envelope header.
 */
@property (nonatomic, readonly, strong) SentryEnvelopeHeader *header;

/**
 * The envelope items.
 */
@property (nonatomic, readonly, strong) NSArray<SentryEnvelopeItem *> *items;

@end

NS_ASSUME_NONNULL_END
