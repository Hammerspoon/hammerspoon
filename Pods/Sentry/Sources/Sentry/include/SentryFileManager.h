#import "SentryDataCategory.h"
#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryFileManagerDelegate;

@class SentryAppState;
@class SentryDispatchQueueWrapper;
@class SentryEvent;
@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryFileContents;
@class SentryOptions;
@class SentrySession;

#if SENTRY_TARGET_PROFILING_SUPPORTED
SENTRY_EXTERN NSString *sentryApplicationSupportPath(void);
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

NS_SWIFT_NAME(SentryFileManager)
@interface SentryFileManager : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSString *basePath;
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
 * Only used for testing.
 */
- (nullable NSString *)getEnvelopesPath:(NSString *)filePath;

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

BOOL createDirectoryIfNotExists(NSString *path, NSError **error);
SENTRY_EXTERN NSString *_Nullable sentryApplicationSupportPath(void);

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * @return @c YES if a launch profile config file is present, @c NO otherwise. If a config file is
 * present, this means that a sample decision of @c YES was computed using the resolved traces and
 * profiles sample rates provided in the previous launch's call to @c SentrySDK.startWithOptions .
 * @note This is implemented as a C function instead of an Objective-C method in the interest of
 * fast execution at launch time.
 */
SENTRY_EXTERN BOOL appLaunchProfileConfigFileExists(void);

/**
 * Retrieve the contents of the launch profile config file, which stores the sample rates used to
 * decide whether or not to profile this launch.
 */
SENTRY_EXTERN NSDictionary<NSString *, NSNumber *> *_Nullable appLaunchProfileConfiguration(void);

/**
 * Write a config file that stores the sample rates used to determine whether this launch should
 * have been profiled.
 */
SENTRY_EXTERN void writeAppLaunchProfilingConfigFile(
    NSMutableDictionary<NSString *, NSNumber *> *config);

/**
 * Remove an existing launch profile config file. If this launch was profiled, then a config file is
 * present, and if the following call to @c SentrySDK.startWithOptions determines the next launch
 * should not be profiled, then we must remove the config file, or the next launch would see it and
 * start the profiler.
 */
SENTRY_EXTERN void removeAppLaunchProfilingConfigFile(void);

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

@protocol SentryFileManagerDelegate <NSObject>

- (void)envelopeItemDeleted:(SentryEnvelopeItem *)envelopeItem
               withCategory:(SentryDataCategory)dataCategory;

@end

NS_ASSUME_NONNULL_END
