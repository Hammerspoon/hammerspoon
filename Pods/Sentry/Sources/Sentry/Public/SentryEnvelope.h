#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryEvent, SentrySession, SentrySdkInfo, SentryId, SentryUserFeedback, SentryAttachment,
    SentryTransaction, SentryTraceState;

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeHeader : NSObject
SENTRY_NO_INIT

/**
 * Initializes an SentryEnvelopeHeader object with the specified eventId.
 *
 * Sets the sdkInfo from SentryMeta.
 *
 * @param eventId The identifier of the event. Can be nil if no event in the envelope or attachment
 * related to event.
 */
- (instancetype)initWithId:(SentryId *_Nullable)eventId;

/**
 * Initializes an SentryEnvelopeHeader object with the specified eventId and traceState.
 *
 * @param eventId The identifier of the event. Can be nil if no event in the envelope or attachment
 * related to event.
 * @param traceState Current trace state.
 */
- (instancetype)initWithId:(nullable SentryId *)eventId
                traceState:(nullable SentryTraceState *)traceState;

/**
 * Initializes an SentryEnvelopeHeader object with the specified eventId, skdInfo and traceState.
 *
 * It is recommended to use initWithId:traceState: because it sets the sdkInfo for you.
 *
 * @param eventId The identifier of the event. Can be nil if no event in the envelope or attachment
 * related to event.
 * @param sdkInfo sdkInfo Describes the Sentry SDK. Can be nil for backwards compatibility. New
 * instances should always provide a version.
 * @param traceState Current trace state.
 */
- (instancetype)initWithId:(nullable SentryId *)eventId
                   sdkInfo:(nullable SentrySdkInfo *)sdkInfo
                traceState:(nullable SentryTraceState *)traceState NS_DESIGNATED_INITIALIZER;

/**
 * The event identifier, if available.
 * An event id exist if the envelope contains an event of items within it are
 * related. i.e Attachments
 */
@property (nullable, nonatomic, readonly, copy) SentryId *eventId;

@property (nullable, nonatomic, readonly, copy) SentrySdkInfo *sdkInfo;

@property (nullable, nonatomic, readonly, copy) SentryTraceState *traceState;

@end

@interface SentryEnvelopeItemHeader : NSObject
SENTRY_NO_INIT

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                   filenname:(NSString *)filename
                 contentType:(NSString *)contentType;

/**
 * The type of the envelope item.
 */
@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly, copy) NSString *_Nullable filename;
@property (nonatomic, readonly, copy) NSString *_Nullable contentType;

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
 * Initializes a SentryEnvelope with a single session.
 * @param session to init the envelope with.
 * @return an initialized SentryEnvelope
 */
- (instancetype)initWithSession:(SentrySession *)session;

/**
 * Initializes a SentryEnvelope with a list of sessions.
 * Can be used when an operations that starts a session closes an ongoing
 * session
 * @param sessions to init the envelope with.
 * @return an initialized SentryEnvelope
 */
- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items NS_DESIGNATED_INITIALIZER;

// Convenience init for a single event
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
