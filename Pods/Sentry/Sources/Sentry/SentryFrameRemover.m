#import "SentryFrameRemover.h"
#import "SentryFrame.h"
#import <Foundation/Foundation.h>

@implementation SentryFrameRemover

+ (NSArray<SentryFrame *> *)removeNonSdkFrames:(NSArray<SentryFrame *> *)frames
{
    NSUInteger indexOfFirstNonSentryFrame = [frames indexOfObjectPassingTest:^BOOL(
        SentryFrame *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSString *package = [obj.package lowercaseString];
        return ![package containsString:@"/sentry.framework/"]
            && ![package containsString:@"/sentryprivate.framework/"];
    }];

    if (indexOfFirstNonSentryFrame == NSNotFound) {
        return frames;
    } else {
        return [frames subarrayWithRange:NSMakeRange(indexOfFirstNonSentryFrame,
                                             frames.count - indexOfFirstNonSentryFrame)];
    }
}

@end
