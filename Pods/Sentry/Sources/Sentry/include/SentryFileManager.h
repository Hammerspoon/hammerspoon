#import "SentryDataCategory.h"
#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryFileManagerDelegate;

@class SentryAppState;
@class SentryDispatchQueueWrapper;
@class SentryEvent;
@class SentryEnvelope;
@class SentryFileContents;
@class SentryOptions;
@class SentrySession;

NS_SWIFT_NAME(SentryFileManager)
@interface SentryFileManager : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSString *sentryPath;
@property (nonatomic, readonly) NSString *breadcrumbsFilePathOne;
@property (nonatomic, readonly) NSString *breadcrumbsFilePathTwo;
@property (nonatomic, readonly) NSString *previousBreadcrumbsFilePathOne;
@property (nonatomic, readonly) NSString *previousBreadcrumbsFilePathTwo;

- (nullable instancetype)initWithOptions:(SentryOptions *)options error:(NSError **)error;

- (nullable instancetype)initWithOptions:(SentryOptions *)options
                    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                                   error:(NSError **)error NS_DESIGNATED_INITIALIZER;

- (void)setDelegate:(id<SentryFileManagerDelegate>)delegate;

- (NSString *)storeEnvelope:(SentryEnvelope *)envelope;

- (void)storeCurrentSession:(SentrySession *)session;
- (void)storeCrashedSession:(SentrySession *)session;
- (SentrySession *_Nullable)readCurrentSession;
- (SentrySession *_Nullable)readCrashedSession;
- (void)deleteCurrentSession;
- (void)deleteCrashedSession;

- (void)storeTimestampLastInForeground:(NSDate *)timestamp;
- (NSDate *_Nullable)readTimestampLastInForeground;
- (void)deleteTimestampLastInForeground;

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;

/**
 * Only used for teting.
 */
- (void)deleteAllEnvelopes;

- (void)deleteAllFolders;

- (void)deleteOldEnvelopeItems;

/**
 * Get all envelopes sorted ascending by the @c timeIntervalSince1970 the envelope was stored and if
 * two envelopes are stored at the same time sorted by the order they were stored.
 */
- (NSArray<SentryFileContents *> *)getAllEnvelopes;

/**
 * Gets the oldest stored envelope. For the order see @c getAllEnvelopes.
 * @return @c SentryFileContents if there is an envelope and @c nil if there are no envelopes.
 */
- (SentryFileContents *_Nullable)getOldestEnvelope;

- (void)removeFileAtPath:(NSString *)path;

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

- (void)storeAppState:(SentryAppState *)appState;
- (void)moveAppStateToPreviousAppState;
- (SentryAppState *_Nullable)readAppState;
- (SentryAppState *_Nullable)readPreviousAppState;
- (void)deleteAppState;

- (void)moveBreadcrumbsToPreviousBreadcrumbs;
- (NSArray *)readPreviousBreadcrumbs;

- (NSNumber *_Nullable)readTimezoneOffset;
- (void)storeTimezoneOffset:(NSInteger)offset;
- (void)deleteTimezoneOffset;

@end

@protocol SentryFileManagerDelegate <NSObject>

- (void)envelopeItemDeleted:(SentryDataCategory)dataCategory;

@end

NS_ASSUME_NONNULL_END
