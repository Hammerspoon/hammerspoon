#import "SentryStacktraceBuilder.h"
#import "SentryCrashDynamicLinker.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_SelfThread.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryFrame.h"
#import "SentryHexAddressFormatter.h"
#import "SentryStacktrace.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryStacktraceBuilder

- (SentryStacktrace *)buildStacktraceForCurrentThreadSkippingFrames:(NSInteger)framesToSkip
{
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray new];

    SentryCrashStackCursor stackCursor;
    // Always skip the first entry so we remove the current function from the stacktrace
    sentrycrashsc_initSelfThread(&stackCursor, (int)framesToSkip + 1);

    while (stackCursor.advanceCursor(&stackCursor)) {
        if (stackCursor.symbolicate(&stackCursor)) {
            SentryFrame *frame = [SentryCrashStackEntryMapper mapStackEntryWithCursor:stackCursor];
            [frames addObject:frame];
        }
    }

    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<SentryFrame *> *framesReversed = [[frames reverseObjectEnumerator] allObjects];

    SentryStacktrace *stacktrace = [[SentryStacktrace alloc] initWithFrames:framesReversed
                                                                  registers:@{}];

    return stacktrace;
}

@end

NS_ASSUME_NONNULL_END
