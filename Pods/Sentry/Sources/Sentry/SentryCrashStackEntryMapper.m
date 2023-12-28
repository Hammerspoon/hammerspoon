#import "SentryCrashStackEntryMapper.h"
#import "SentryBinaryImageCache.h"
#import "SentryDependencyContainer.h"
#import "SentryFormatter.h"
#import "SentryFrame.h"
#import "SentryInAppLogic.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCrashStackEntryMapper ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashStackEntryMapper

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
    }
    return self;
}

- (SentryFrame *)sentryCrashStackEntryToSentryFrame:(SentryCrashStackEntry)stackEntry
{
    SentryFrame *frame = [[SentryFrame alloc] init];

    frame.symbolAddress = sentry_formatHexAddressUInt64(stackEntry.symbolAddress);

    frame.instructionAddress = sentry_formatHexAddressUInt64(stackEntry.address);

    if (stackEntry.symbolName != NULL) {
        frame.function = [NSString stringWithCString:stackEntry.symbolName
                                            encoding:NSUTF8StringEncoding];
    }

    // If there is no symbolication, because debug was disabled
    // we get image from the cache.
    if (stackEntry.imageAddress == 0 && stackEntry.imageName == NULL) {
        SentryBinaryImageInfo *info = [SentryDependencyContainer.sharedInstance.binaryImageCache
            imageByAddress:stackEntry.address];

        frame.imageAddress = sentry_formatHexAddressUInt64(info.address);
        frame.package = info.name;
        frame.inApp = @([self.inAppLogic isInApp:info.name]);
    } else {
        frame.imageAddress = sentry_formatHexAddressUInt64(stackEntry.imageAddress);

        if (stackEntry.imageName != NULL) {
            NSString *imageName = [NSString stringWithCString:stackEntry.imageName
                                                     encoding:NSUTF8StringEncoding];
            frame.package = imageName;
            frame.inApp = @([self.inAppLogic isInApp:imageName]);
        }
    }

    return frame;
}

- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
{
    return [self sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry];
}

@end

NS_ASSUME_NONNULL_END
