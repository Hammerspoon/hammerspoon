#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
static NSString *const SENTRY_FILE_WRITE_OPERATION = @"file.write";

static NSString *const SENTRY_FILE_READ_OPERATION = @"file.read";

@class SentryThreadInspector, SentryNSProcessInfoWrapper;

@interface SentryNSDataTracker : NSObject
SENTRY_NO_INIT

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
               method:(BOOL (^)(NSString *, BOOL))method;

/**
 * Measure NSData 'writeToFile:options:error:' method.
 */
- (BOOL)measureNSData:(NSData *)data
          writeToFile:(NSString *)path
              options:(NSDataWritingOptions)writeOptionsMask
                error:(NSError **)error
               method:(BOOL (^)(NSString *, NSDataWritingOptions, NSError **))method;

/**
 * Measure NSData 'initWithContentsOfFile:' method.
 */
- (nullable NSData *)measureNSDataFromFile:(NSString *)path
                                    method:(NSData *_Nullable (^)(NSString *))method;

/**
 * Measure NSData 'initWithContentsOfFile:options:error:' method.
 */
- (nullable NSData *)measureNSDataFromFile:(NSString *)path
                                   options:(NSDataReadingOptions)readOptionsMask
                                     error:(NSError **)error
                                    method:(NSData *_Nullable (^)(
                                               NSString *, NSDataReadingOptions, NSError **))method;

/**
 * Measure NSData 'initWithContentsOfURL:options:error:' method.
 */
- (nullable NSData *)measureNSDataFromURL:(NSURL *)url
                                  options:(NSDataReadingOptions)readOptionsMask
                                    error:(NSError **)error
                                   method:(NSData *_Nullable (^)(
                                              NSURL *, NSDataReadingOptions, NSError **))method;
@end

NS_ASSUME_NONNULL_END
