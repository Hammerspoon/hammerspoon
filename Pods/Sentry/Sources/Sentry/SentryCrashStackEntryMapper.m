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

- (SentryFrame *)mapStackEntryWithCursor:(SentryCrashStackCursor)stackCursor
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
        frame.inApp = @([self.inAppLogic isInApp:imageName]);
    }

    return frame;
}

@end

NS_ASSUME_NONNULL_END
