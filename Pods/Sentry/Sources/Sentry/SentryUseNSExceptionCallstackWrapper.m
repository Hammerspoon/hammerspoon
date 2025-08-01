#import "SentryUseNSExceptionCallstackWrapper.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryCrashSymbolicator.h"
#import "SentryInAppLogic.h"
#import "SentryOptions+Private.h"
#import "SentrySDK+Private.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"

#if TARGET_OS_OSX

@interface SentryUseNSExceptionCallstackWrapper ()

@property (nonatomic, strong) NSArray<NSNumber *> *returnAddressesArray;

@end

@implementation SentryUseNSExceptionCallstackWrapper

- (instancetype)initWithName:(NSExceptionName)aName
                      reason:(NSString *_Nullable)aReason
                    userInfo:(NSDictionary *_Nullable)aUserInfo
    callStackReturnAddresses:(NSArray<NSNumber *> *)callStackReturnAddresses
{
    if (self = [super initWithName:aName reason:aReason userInfo:aUserInfo]) {
        self.returnAddressesArray = callStackReturnAddresses;
    }
    return self;
}

- (NSArray<SentryThread *> *)buildThreads
{
    SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@0];
    sentryThread.name = @"NSException Thread";
    sentryThread.crashed = @YES;
    // This data might not be real, but we cannot collect other threads
    sentryThread.current = @YES;
    sentryThread.isMain = @YES;

    SentryCrashStackEntryMapper *crashStackToEntryMapper = [self buildCrashStackToEntryMapper];
    NSMutableArray<SentryFrame *> *frames = [NSMutableArray array];

    // Iterate over all the addresses, symbolicate and create a SentryFrame
    [self.returnAddressesArray
        enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            SentryCrashStackCursor stackCursor;
            stackCursor.stackEntry.address = [obj unsignedLongValue];
            sentrycrashsymbolicator_symbolicate(&stackCursor);

            [frames addObject:[crashStackToEntryMapper
                                  sentryCrashStackEntryToSentryFrame:stackCursor.stackEntry]];
        }];

    sentryThread.stacktrace = [SentryStacktraceBuilder buildStacktraceFromFrames:frames];

    return @[ sentryThread ];
}

- (SentryCrashStackEntryMapper *)buildCrashStackToEntryMapper
{
    SentryOptions *options = SentrySDK.options;

    SentryInAppLogic *inAppLogic =
        [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                          inAppExcludes:options.inAppExcludes];
    SentryCrashStackEntryMapper *crashStackEntryMapper =
        [[SentryCrashStackEntryMapper alloc] initWithInAppLogic:inAppLogic];

    return crashStackEntryMapper;
}

@end

#endif // TARGET_OS_OSX
