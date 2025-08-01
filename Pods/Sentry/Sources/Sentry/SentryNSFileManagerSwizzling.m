#import "SentryNSFileManagerSwizzling.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import "SentrySwizzle.h"
#import "SentryTraceOrigin.h"
#import <objc/runtime.h>

@interface SentryNSFileManagerSwizzling ()

@property (nonatomic, strong) SentryFileIOTracker *tracker;

@end

@implementation SentryNSFileManagerSwizzling

+ (SentryNSFileManagerSwizzling *)shared
{
    static SentryNSFileManagerSwizzling *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startWithOptions:(SentryOptions *)options tracker:(SentryFileIOTracker *)tracker
{
    self.tracker = tracker;

    if (!options.enableSwizzling) {
        SENTRY_LOG_DEBUG(
            @"Auto-tracking of NSFileManager is disabled because enableSwizzling is false");
        return;
    }

    if (!options.experimental.enableFileManagerSwizzling) {
        SENTRY_LOG_DEBUG(@"Auto-tracking of NSFileManager is disabled because "
                         @"enableFileManagerSwizzling is false");
        return;
    }

    [SentryNSFileManagerSwizzling swizzle];
}

- (void)stop
{
    [SentryNSFileManagerSwizzling unswizzle];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
+ (void)swizzle
{
    // Before iOS 18.0, macOS 15.0 and tvOS 18.0 the NSFileManager used NSData.writeToFile
    // internally, which was tracked using swizzling of NSData. This behaviour changed, therefore
    // the file manager needs to swizzled for later versions.
    //
    // Ref: https://github.com/swiftlang/swift-foundation/pull/410
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        SEL createFileAtPathContentsAttributes
            = NSSelectorFromString(@"createFileAtPath:contents:attributes:");
        SentrySwizzleInstanceMethod(NSFileManager.class, createFileAtPathContentsAttributes,
            SentrySWReturnType(BOOL),
            SentrySWArguments(
                NSString * path, NSData * data, NSDictionary<NSFileAttributeKey, id> * attributes),
            SentrySWReplacement({
                return [SentryNSFileManagerSwizzling.shared.tracker
                    measureNSFileManagerCreateFileAtPath:path
                                                    data:data
                                              attributes:attributes
                                                  origin:SentryTraceOriginAutoNSData
                                                  method:^BOOL(NSString *path, NSData *data,
                                                      NSDictionary<NSFileAttributeKey, id>
                                                          *attributes) {
                                                      return SentrySWCallOriginal(
                                                          path, data, attributes);
                                                  }];
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses,
            (void *)createFileAtPathContentsAttributes);
    }
}

+ (void)unswizzle
{
#if SENTRY_TEST || SENTRY_TEST_CI
    // Unswizzling is only supported in test targets as it is considered unsafe for production.
    if (@available(iOS 18, macOS 15, tvOS 18, *)) {
        SEL createFileAtPathContentsAttributes
            = NSSelectorFromString(@"createFileAtPath:contents:attributes:");
        SentryUnswizzleInstanceMethod(NSFileManager.class, createFileAtPathContentsAttributes,
            (void *)createFileAtPathContentsAttributes);
    }
#endif // SENTRY_TEST || SENTRY_TEST_CI
}
#pragma clang diagnostic pop
@end
