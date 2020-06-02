#import <Foundation/Foundation.h>

#import "SentryEvent.h"
#import "SentrySession.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeHeader : NSObject
SENTRY_NO_INIT

// id can be null if no event in the envelope or attachment related to event
- (instancetype)initWithId:(NSString *_Nullable) eventId NS_DESIGNATED_INITIALIZER;

/**
 * The event identifier, if available.
 * An event id exist if the envelope contains an event of items within it are related.
 * i.e Attachments
 */
@property(nonatomic, readonly, copy) NSString *_Nullable eventId;

@end

@interface SentryEnvelopeItemHeader : NSObject
SENTRY_NO_INIT

- (instancetype)initWithType:(NSString *)type
                length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

/**
 * The type of the envelope item.
 */
@property(nonatomic, readonly, copy) NSString *type;
@property(nonatomic, readonly) NSUInteger length;

@end

@interface SentryEnvelopeItem : NSObject
SENTRY_NO_INIT

- (instancetype)initWithEvent:(SentryEvent *)event;
- (instancetype)initWithSession:(SentrySession *)session;
- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header
                data:(NSData *)data NS_DESIGNATED_INITIALIZER;

/**
 * The envelope item header.
 */
@property(nonatomic, readonly, strong) SentryEnvelopeItemHeader *header;

/**
 * The envelope payload.
 */
@property(nonatomic, readonly, strong) NSData *data;

@end

@interface SentryEnvelope : NSObject
SENTRY_NO_INIT

// If no event, or no data related to event, id will be null
- (instancetype)initWithId:(NSString *_Nullable)id
                singleItem:(SentryEnvelopeItem *)item;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                    singleItem:(SentryEnvelopeItem *)item;

// If no event, or no data related to event, id will be null
- (instancetype)initWithId:(NSString *_Nullable)id
                     items:(NSArray<SentryEnvelopeItem *> *)items;

/**
 * Initializes a SentryEnvelope with a single session.
 * @param session to init the envelope with.
 * @return an initialized SentryEnvelope
 */
- (instancetype)initWithSession:(SentrySession *)session;

/**
 * Initializes a SentryEnvelope with a list of sessions.
 * Can be used when an operations that starts a session closes an ongoing session
 * @param sessions to init the envelope with.
 * @return an initialized SentryEnvelope
 */
- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items NS_DESIGNATED_INITIALIZER;

// Convenience init for a single event
- (instancetype)initWithEvent:(SentryEvent *)event;

/**
 * The envelope header.
 */
@property(nonatomic, readonly, strong) SentryEnvelopeHeader *header;

/**
 * The envelope items.
 */
@property(nonatomic, readonly, strong) NSArray<SentryEnvelopeItem *> *items;

@end

NS_ASSUME_NONNULL_END
