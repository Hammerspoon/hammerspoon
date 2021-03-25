#import <Foundation/Foundation.h>

#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"
#import "SentrySession.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryEvent, SentryOptions, SentryEnvelope, SentryFileContents, SentryAppState;

NS_SWIFT_NAME(SentryFileManager)
@interface SentryFileManager : NSObject
SENTRY_NO_INIT

- (nullable instancetype)initWithOptions:(SentryOptions *)options
                  andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                                   error:(NSError **)error NS_DESIGNATED_INITIALIZER;

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

- (void)deleteAllEnvelopes;

- (void)deleteAllFolders;

/**
 * Get all envelopes sorted ascending by the timeIntervalSince1970 the envelope was stored and if
 * two envelopes are stored at the same time sorted by the order they were stored.
 */
- (NSArray<SentryFileContents *> *)getAllEnvelopes;

/**
 * Gets the oldest stored envelope. For the order see getAllEnvelopes.
 *
 * @return SentryFileContens if there is an envelope and nil if there are no envelopes.
 */
- (SentryFileContents *_Nullable)getOldestEnvelope;

- (BOOL)removeFileAtPath:(NSString *)path;

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path;

- (void)storeAppState:(SentryAppState *)appState;
- (SentryAppState *_Nullable)readAppState;
- (void)deleteAppState;

@end

NS_ASSUME_NONNULL_END
