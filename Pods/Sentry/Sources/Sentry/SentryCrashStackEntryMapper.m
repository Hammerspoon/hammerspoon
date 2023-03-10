#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryHexAddressFormatter.h"
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

    NSNumber *symbolAddress = @(stackEntry.symbolAddress);
    frame.symbolAddress = sentry_formatHexAddress(symbolAddress);

    NSNumber *instructionAddress = @(stackEntry.address);
    frame.instructionAddress = sentry_formatHexAddress(instructionAddress);

    NSNumber *imageAddress = @(stackEntry.imageAddress);
    frame.imageAddress = sentry_formatHexAddress(imageAddress);

    if (stackEntry.symbolName != NULL) {
        frame.function = [NSString stringWithCString:stackEntry.symbolName
                                            encoding:NSUTF8StringEncoding];
    }

    if (stackEntry.imageName != NULL) {
        NSString *imageName = [NSString stringWithCString:stackEntry.imageName
                                                 encoding:NSUTF8StringEncoding];
        frame.package = imageName;
        frame.inApp = @([self.inAppLogic isInApp:imageName]);
    }

    return frame;
}

- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
{
    return [self sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry];
}

@end

NS_ASSUME_NONNULL_END
