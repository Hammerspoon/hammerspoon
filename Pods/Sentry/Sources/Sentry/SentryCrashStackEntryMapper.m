#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryHexAddressFormatter.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryCrashStackEntryMapper

+ (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
{
    SentryFrame *frame = [[SentryFrame alloc] init];

    NSNumber *symbolAddress = @(stackCursor.stackEntry.symbolAddress);
    frame.symbolAddress = sentry_formatHexAddress(symbolAddress);

    NSNumber *instructionAddress = @(stackCursor.stackEntry.address);
    frame.instructionAddress = sentry_formatHexAddress(instructionAddress);

    NSNumber *imageAddress = @(stackCursor.stackEntry.imageAddress);
    frame.imageAddress = sentry_formatHexAddress(imageAddress);

    if (stackCursor.stackEntry.symbolName != NULL) {
        frame.function = [NSString stringWithCString:stackCursor.stackEntry.symbolName
                                            encoding:NSUTF8StringEncoding];
    }

    if (stackCursor.stackEntry.imageName != NULL) {
        NSString *imageName = [NSString stringWithCString:stackCursor.stackEntry.imageName
                                                 encoding:NSUTF8StringEncoding];
        frame.package = imageName;

        BOOL isInApp = [self isInApp:imageName];
        frame.inApp = @(isInApp);
    }

    return frame;
}

+ (BOOL)isInApp:(NSString *)imageName
{
    // We don't want to mark images from Xcode as inApp. As these images are located in
    // "/Applications/Xcode.app/Contents" checking for ".app" would be true. Therefore we need to
    // exclude them. We search for "/Applications/Xcode" and ".app/Contents/" to be more exclusive,
    // but not too strict for future Xcode versions. We also can't use Xcode.app, because this
    // wouldn't work if you have multiple Xcode versions installed. We don't support Xcode being
    // installed in a different location than "/Applications".

    BOOL isNotXcodeSimulatorImage = !([imageName containsString:@"/Applications/Xcode"] &&
        [imageName containsString:@".app/Contents/"]);

    return [imageName containsString:@"/Bundle/Application/"]
        || ([imageName containsString:@".app"] && isNotXcodeSimulatorImage);
}

@end

NS_ASSUME_NONNULL_END
