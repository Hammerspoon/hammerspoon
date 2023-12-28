#import "SentryNSDataSwizzling.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashMachineContextWrapper.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryDependencyContainer.h"
#import "SentryInAppLogic.h"
#import "SentryNSDataTracker.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryOptions+Private.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySwizzle.h"
#import "SentryThreadInspector.h"
#import <SentryLog.h>
#import <objc/runtime.h>

@interface
SentryNSDataSwizzling ()

@property (nonatomic, strong) SentryNSDataTracker *dataTracker;

@end

@implementation SentryNSDataSwizzling

+ (SentryNSDataSwizzling *)shared
{
    static SentryNSDataSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithOptions:(SentryOptions *)options
{
    self.dataTracker = [[SentryNSDataTracker alloc]
        initWithThreadInspector:[[SentryThreadInspector alloc] initWithOptions:options]
             processInfoWrapper:[SentryDependencyContainer.sharedInstance processInfoWrapper]];
    [self.dataTracker enable];
    [SentryNSDataSwizzling swizzleNSData];
}

- (void)stop
{
    [self.dataTracker disable];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzleNSData
{
    SEL writeToFileAtomicallySelector = NSSelectorFromString(@"writeToFile:atomically:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileAtomicallySelector,
        SentrySWReturnType(BOOL), SentrySWArguments(NSString * path, BOOL useAuxiliaryFile),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.dataTracker
                measureNSData:self
                  writeToFile:path
                   atomically:useAuxiliaryFile
                       method:^BOOL(NSString *_Nonnull filePath, BOOL isAtomically) {
                           return SentrySWCallOriginal(filePath, isAtomically);
                       }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeToFileAtomicallySelector);

    SEL writeToFileOptionsErrorSelector = NSSelectorFromString(@"writeToFile:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, writeToFileOptionsErrorSelector,
        SentrySWReturnType(BOOL),
        SentrySWArguments(NSString * path, NSDataWritingOptions writeOptionsMask, NSError * *error),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.dataTracker
                measureNSData:self
                  writeToFile:path
                      options:writeOptionsMask
                        error:error
                       method:^BOOL(
                           NSString *filePath, NSDataWritingOptions options, NSError **outError) {
                           return SentrySWCallOriginal(filePath, options, outError);
                       }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)writeToFileOptionsErrorSelector);

    SEL initWithContentOfFileOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfFile:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentOfFileOptionsErrorSelector,
        SentrySWReturnType(NSData *),
        SentrySWArguments(NSString * path, NSDataReadingOptions options, NSError * *error),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.dataTracker
                measureNSDataFromFile:path
                              options:options
                                error:error
                               method:^NSData *(NSString *filePath, NSDataReadingOptions options,
                                   NSError **outError) {
                                   return SentrySWCallOriginal(filePath, options, outError);
                               }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses,
        (void *)initWithContentOfFileOptionsErrorSelector);

    SEL initWithContentsOfFileSelector = NSSelectorFromString(@"initWithContentsOfFile:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentsOfFileSelector,
        SentrySWReturnType(NSData *), SentrySWArguments(NSString * path), SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.dataTracker
                measureNSDataFromFile:path
                               method:^NSData *(
                                   NSString *filePath) { return SentrySWCallOriginal(filePath); }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)initWithContentsOfFileSelector);

    SEL initWithContentsOfURLOptionsErrorSelector
        = NSSelectorFromString(@"initWithContentsOfURL:options:error:");
    SentrySwizzleInstanceMethod(NSData.class, initWithContentsOfURLOptionsErrorSelector,
        SentrySWReturnType(NSData *),
        SentrySWArguments(NSURL * url, NSDataReadingOptions options, NSError * *error),
        SentrySWReplacement({
            return [SentryNSDataSwizzling.shared.dataTracker
                measureNSDataFromURL:url
                             options:options
                               error:error
                              method:^NSData *(NSURL *fileUrl, NSDataReadingOptions options,
                                  NSError **outError) {
                                  return SentrySWCallOriginal(fileUrl, options, outError);
                              }];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses,
        (void *)initWithContentsOfURLOptionsErrorSelector);
}
#pragma clang diagnostic pop
@end
