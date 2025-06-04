#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryNSProcessInfoWrapper;
@class SentryThreadInspector;

@interface SentryFileIOTracker : NSObject
SENTRY_NO_INIT

/**
 * Convenience accessor to the shared instance of the tracker in the dependency container.
 *
 * @note Can be used from Swift without import the entire dependency container.
 * @note If the SentrySDK is not enabled this will return nil.
 *
 * @return The shared instance of the tracker.
 */
+ (instancetype _Nullable)sharedInstance;

- (instancetype)initWithThreadInspector:(SentryThreadInspector *)threadInspector
                     processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper;

- (void)enable;

- (void)disable;

/**
 * Measure NSData 'writeToFile:atomicall:' method.
 */
- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
           atomically:(BOOL)useAuxiliaryFile
               origin:(NSString *)origin
               method:(BOOL (^)(NSString *, BOOL))method;

/**
 * Measure NSData 'writeToFile:options:error:' method.
 */
- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
              options:(NSDataWritingOptions)writeOptionsMask
               origin:(NSString *)origin
                error:(NSError **)error
               method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method;

/**
 * Measure NSData 'initWithContentsOfFile:' method.
 */
- (nullable NSData *)measureNSDataFromFile:(NSString *)path
                                    origin:(NSString *)origin
                                    method:(NSData *_Nullable (^)(NSString *))method;

/**
 * Measure NSData 'initWithContentsOfFile:options:error:' method.
 */
- (nullable NSData *)measureNSDataFromFile:(NSString *)path
                                   options:(NSDataReadingOptions)readOptionsMask
                                    origin:(NSString *)origin
                                     error:(NSError **)error
                                    method:(NSData *_Nullable (^)(
                                               NSString *, NSDataReadingOptions, NSError **))method;

/**
 * Measure NSData 'initWithContentsOfURL:options:error:' method.
 */
- (nullable NSData *)measureNSDataFromURL:(NSURL *)url
                                  options:(NSDataReadingOptions)readOptionsMask
                                   origin:(NSString *)origin
                                    error:(NSError **)error
                                   method:(NSData *_Nullable (^)(
                                              NSURL *, NSDataReadingOptions, NSError **))method;

/**
 * Measure NSFileManager 'createFileAtPath:contents:attributes::' method.
 */
- (BOOL)measureNSFileManagerCreateFileAtPath:(NSString *)path
                                        data:(NSData *)data
                                  attributes:(NSDictionary<NSFileAttributeKey, id> *)attributes
                                      origin:(NSString *)origin
                                      method:(BOOL (^)(NSString *, NSData *,
                                                 NSDictionary<NSFileAttributeKey, id> *))method;

// MARK: - Internal Methods available for Swift Extension

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation;

- (nullable id<SentrySpan>)spanForPath:(NSString *)path
                                origin:(NSString *)origin
                             operation:(NSString *)operation
                                  size:(NSUInteger)size;

@end

NS_ASSUME_NONNULL_END
