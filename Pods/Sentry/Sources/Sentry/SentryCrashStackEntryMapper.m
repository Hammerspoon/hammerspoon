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
    return [imageName containsString:@"/Bundle/Application/"] || [imageName containsString:@".app"];
}

@end

NS_ASSUME_NONNULL_END
