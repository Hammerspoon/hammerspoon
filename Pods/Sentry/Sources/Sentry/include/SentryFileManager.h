#import <Foundation/Foundation.h>

#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"
#import "SentrySession.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryEvent, SentryDsn, SentryEnvelope, SentryFileContents;

NS_SWIFT_NAME(SentryFileManager)
@interface SentryFileManager : NSObject
SENTRY_NO_INIT

- (_Nullable instancetype)initWithDsn:(SentryDsn *)dsn
               andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                     didFailWithError:(NSError **)error NS_DESIGNATED_INITIALIZER;

- (NSString *)storeEvent:(SentryEvent *)event;
- (NSString *)storeEnvelope:(SentryEnvelope *)envelope;

- (void)storeCurrentSession:(SentrySession *)session;
- (SentrySession *_Nullable)readCurrentSession;
- (void)deleteCurrentSession;

- (void)storeTimestampLastInForeground:(NSDate *)timestamp;
- (NSDate *_Nullable)readTimestampLastInForeground;
- (void)deleteTimestampLastInForeground;

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;

- (void)deleteAllStoredEventsAndEnvelopes;

- (void)deleteAllFolders;

/**
 In a previous version of SentryFileManager envelopes were stored in the same
 path as events. Now events and envelopes are stored in two different paths. We
 decided that there is no need for a migration strategy, because in worst case
 only a few envelopes get lost and this is not worth the effort. Since there is
 no migration strategy this method could also return envelopes.
 */
- (NSArray<SentryFileContents *> *)getAllEventsAndMaybeEnvelopes;
- (NSArray<SentryFileContents *> *)getAllEnvelopes;
- (NSArray<SentryFileContents *> *)getAllStoredEventsAndEnvelopes;

- (BOOL)removeFileAtPath:(NSString *)path;

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path;

@property (nonatomic, assign) NSUInteger maxEvents;
@property (nonatomic, assign) NSUInteger maxEnvelopes;

@end

NS_ASSUME_NONNULL_END
