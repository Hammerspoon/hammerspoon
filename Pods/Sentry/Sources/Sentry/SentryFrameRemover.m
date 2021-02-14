#import "SentryFrameRemover.h"
#import "SentryFrame.h"
#import <Foundation/Foundation.h>

@implementation SentryFrameRemover

- (NSArray<SentryFrame *> *)removeNonSdkFrames:(NSArray<SentryFrame *> *)frames
{
    // When including Sentry via the Swift Package Manager the package is the same as the
    // application that includes Sentry. Therefore removing frames with a package containing
    // "sentry" doesn't work. We could instead look into the function name, but then we risk
    // removing functions that are not from this SDK and contain "sentry", which would lead to a
    // loss of frames on the stacktrace. Therefore we don't remove any frames.
    NSUInteger indexOfFirstNonSentryFrame = [frames indexOfObjectPassingTest:^BOOL(
        SentryFrame *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        return ![[obj.package lowercaseString] containsString:@"sentry"];
    }];

    if (indexOfFirstNonSentryFrame == NSNotFound) {
        return frames;
    } else {
        return [frames subarrayWithRange:NSMakeRange(indexOfFirstNonSentryFrame,
                                             frames.count - indexOfFirstNonSentryFrame)];
    }
}

@end
