#import "SentryProfilerState.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryBacktrace.hpp"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryFormatter.h"
#    import "SentryProfileTimeseries.h"
#    import "SentrySample.h"
#    import "SentrySwift.h"
#    import <mach/mach_types.h>
#    import <mach/port.h>
#    import <mutex>

#    if defined(DEBUG)
#        include <execinfo.h>
#    endif

using namespace sentry::profiling;

NSString *
parseBacktraceSymbolsFunctionName(const char *symbol)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression
            regularExpressionWithPattern:@"\\d+\\s+\\S+\\s+0[xX][0-9a-fA-F]+\\s+(.+)\\s+\\+\\s+\\d+"
                                 options:0
                                   error:nil];
    });
    const auto symbolNSStr = [NSString stringWithUTF8String:symbol];
    const auto match = [regex firstMatchInString:symbolNSStr
                                         options:0
                                           range:NSMakeRange(0, [symbolNSStr length])];
    if (match == nil) {
        return symbolNSStr;
    }
    return [symbolNSStr substringWithRange:[match rangeAtIndex:1]];
}

@implementation SentryProfilerMutableState

- (instancetype)init
{
    if (self = [super init]) {
        _samples = [NSMutableArray<SentrySample *> array];
        _stacks = [NSMutableArray<NSArray<NSNumber *> *> array];
        _frames = [NSMutableArray<NSDictionary<NSString *, id> *> array];
        _threadMetadata = [NSMutableDictionary<NSString *, NSMutableDictionary *> dictionary];
        _frameIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
        _stackIndexLookup = [NSMutableDictionary<NSString *, NSNumber *> dictionary];
    }
    return self;
}

@end

@implementation SentryProfilerState {
    SentryProfilerMutableState *_mutableState;
    std::mutex _lock;
    thread_t _mainThreadID;
}

- (instancetype)init
{
    if (self = [super init]) {
        _mutableState = [[SentryProfilerMutableState alloc] init];
        _mainThreadID = 0;
        [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper
            dispatchAsyncOnMainQueue:^{ [self cacheMainThreadID]; }];
    }
    return self;
}

- (void)mutate:(void (^)(SentryProfilerMutableState *))block
{
    NSParameterAssert(block);
    std::lock_guard<std::mutex> l(_lock);
    block(_mutableState);
}

- (void)clear
{
    std::lock_guard<std::mutex> l(_lock);
    _mutableState = [[SentryProfilerMutableState alloc] init];
}

- (void)cacheMainThreadID
{
    std::lock_guard<std::mutex> l(_lock);
    NSAssert([NSThread isMainThread], @"Must be called on main thread");
    const auto currentThread = pthread_mach_thread_np(pthread_self());
    if (MACH_PORT_VALID(currentThread)) {
        _mainThreadID = currentThread;
    }
}

- (void)appendBacktrace:(const Backtrace &)backtrace
{
    [self mutate:^(SentryProfilerMutableState *state) {
        const auto threadID = sentry_stringForUInt64(backtrace.threadMetadata.threadID);

        NSMutableDictionary<NSString *, id> *metadata = state.threadMetadata[threadID];
        if (metadata == nil) {
            metadata = [NSMutableDictionary<NSString *, id> dictionary];
            state.threadMetadata[threadID] = metadata;
        }
        if (metadata[@"name"] == nil) {
            if (!backtrace.threadMetadata.name.empty()) {
                metadata[@"name"] =
                    [NSString stringWithUTF8String:backtrace.threadMetadata.name.c_str()];
            } else if (self->_mainThreadID != 0
                && backtrace.threadMetadata.threadID == self->_mainThreadID) {
                metadata[@"name"] = @"main";
            }
        }
        if (backtrace.threadMetadata.priority != -1 && metadata[@"priority"] == nil) {
            metadata[@"priority"] = @(backtrace.threadMetadata.priority);
        }
#    if defined(DEBUG)
        const auto symbols
            = backtrace_symbols(reinterpret_cast<void *const *>(backtrace.addresses.data()),
                static_cast<int>(backtrace.addresses.size()));
#    endif

        const auto stack = [NSMutableArray<NSNumber *> array];
        for (std::vector<uintptr_t>::size_type backtraceAddressIdx = 0;
             backtraceAddressIdx < backtrace.addresses.size(); backtraceAddressIdx++) {
            const auto instructionAddress
                = sentry_formatHexAddressUInt64(backtrace.addresses[backtraceAddressIdx]);
            const auto frameIndex = state.frameIndexLookup[instructionAddress];
            if (frameIndex == nil) {
                const auto frame = [NSMutableDictionary<NSString *, id> dictionary];
                frame[@"instruction_addr"] = instructionAddress;
#    if defined(DEBUG)
                frame[@"function"]
                    = parseBacktraceSymbolsFunctionName(symbols[backtraceAddressIdx]);
#    endif
                const auto newFrameIndex = @(state.frames.count);
                [stack addObject:newFrameIndex];
                state.frameIndexLookup[instructionAddress] = newFrameIndex;
                [state.frames addObject:frame];
            } else {
                [stack addObject:frameIndex];
            }
        }
#    if defined(DEBUG)
        free(symbols);
#    endif

        const auto sample = [[SentrySample alloc] init];
        sample.absoluteTimestamp = backtrace.absoluteTimestamp;
        sample.absoluteNSDateInterval
            = SentryDependencyContainer.sharedInstance.dateProvider.date.timeIntervalSince1970;
        sample.threadID = backtrace.threadMetadata.threadID;

        const auto stackKey = [stack componentsJoinedByString:@"|"];
        const auto stackIndex = state.stackIndexLookup[stackKey];
        if (stackIndex) {
            sample.stackIndex = stackIndex;
        } else {
            const auto nextStackIndex = @(state.stacks.count);
            sample.stackIndex = nextStackIndex;
            state.stackIndexLookup[stackKey] = nextStackIndex;
            [state.stacks addObject:stack];
        }

        [state.samples addObject:sample];
    }];
}

- (NSDictionary<NSString *, id> *)copyProfilingData
{
    std::lock_guard<std::mutex> l(_lock);

    NSMutableArray<SentrySample *> *const samples = [_mutableState.samples copy];
    NSMutableArray<NSArray<NSNumber *> *> *const stacks = [_mutableState.stacks copy];
    NSMutableArray<NSDictionary<NSString *, id> *> *const frames = [_mutableState.frames copy];

    // thread metadata contains a mutable substructure, so it's not enough to perform a copy of
    // the top-level dictionary, we need to go deeper to copy the mutable subdictionaries
    const auto threadMetadata = [NSMutableDictionary<NSString *, NSDictionary *> dictionary];
    [_mutableState.threadMetadata enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key,
        NSDictionary *_Nonnull obj, BOOL *_Nonnull stop) { threadMetadata[key] = [obj copy]; }];

    return @{
        @"profile" : @ {
            @"samples" : samples,
            @"stacks" : stacks,
            @"frames" : frames,
            @"thread_metadata" : threadMetadata,
        }
    };
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
