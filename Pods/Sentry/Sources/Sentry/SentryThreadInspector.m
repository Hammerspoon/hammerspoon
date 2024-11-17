#import "SentryThreadInspector.h"
#import "SentryBinaryImageCache.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashStackCursor.h"
#include "SentryCrashStackCursor_MachineContext.h"
#import "SentryCrashStackEntryMapper.h"
#include "SentryCrashSymbolicator.h"
#import "SentryFrame.h"
#import "SentryInAppLogic.h"
#import "SentryOptions.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"
#include <pthread.h>

@interface
SentryThreadInspector ()

@property (nonatomic, strong) SentryStacktraceBuilder *stacktraceBuilder;
@property (nonatomic, strong) id<SentryCrashMachineContextWrapper> machineContextWrapper;
@property (nonatomic, assign) BOOL symbolicate;

@end

typedef struct {
    SentryCrashThread thread;
    SentryCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH];
    int stackLength;
} SentryThreadInfo;

// We need a C function to retrieve information from the stack trace in order to avoid
// calling into not async-signal-safe code while there are suspended threads.
unsigned int
getStackEntriesFromThread(SentryCrashThread thread, struct SentryCrashMachineContext *context,
    SentryCrashStackEntry *buffer, unsigned int maxEntries, bool symbolicate)
{
    sentrycrashmc_getContextForThread(thread, context, NO);
    SentryCrashStackCursor stackCursor;

    sentrycrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);

    unsigned int entries = 0;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (entries == maxEntries)
            break;
        if (symbolicate == false || stackCursor.symbolicate(&stackCursor)) {
            buffer[entries] = stackCursor.stackEntry;
            entries++;
        }
    }

    return entries;
}

@implementation SentryThreadInspector

- (id)initWithStacktraceBuilder:(SentryStacktraceBuilder *)stacktraceBuilder
       andMachineContextWrapper:(id<SentryCrashMachineContextWrapper>)machineContextWrapper
                    symbolicate:(BOOL)symbolicate
{
    if (self = [super init]) {
        self.stacktraceBuilder = stacktraceBuilder;
        self.machineContextWrapper = machineContextWrapper;
        self.symbolicate = symbolicate;
    }
    return self;
}

- (instancetype)initWithOptions:(SentryOptions *)options
{
    SentryInAppLogic *inAppLogic =
        [[SentryInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                          inAppExcludes:options.inAppExcludes];
    SentryCrashStackEntryMapper *crashStackEntryMapper =
        [[SentryCrashStackEntryMapper alloc] initWithInAppLogic:inAppLogic];
    SentryStacktraceBuilder *stacktraceBuilder =
        [[SentryStacktraceBuilder alloc] initWithCrashStackEntryMapper:crashStackEntryMapper];
    stacktraceBuilder.symbolicate = options.debug;

    id<SentryCrashMachineContextWrapper> machineContextWrapper =
        [[SentryCrashDefaultMachineContextWrapper alloc] init];
    return [self initWithStacktraceBuilder:stacktraceBuilder
                  andMachineContextWrapper:machineContextWrapper
                               symbolicate:options.debug];
}

- (SentryStacktrace *)stacktraceForCurrentThreadAsyncUnsafe
{
    return [self.stacktraceBuilder buildStacktraceForCurrentThreadAsyncUnsafe];
}

- (NSArray<SentryThread *> *)getCurrentThreads
{
    NSMutableArray<SentryThread *> *threads = [NSMutableArray new];

    SentryCrashMC_NEW_CONTEXT(context);
    SentryCrashThread currentThread = sentrycrashthread_self();

    [self.machineContextWrapper fillContextForCurrentThread:context];
    int threadCount = [self.machineContextWrapper getThreadCount:context];

    for (int i = 0; i < threadCount; i++) {
        SentryCrashThread thread = [self.machineContextWrapper getThread:context withIndex:i];
        SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@(i)];

        sentryThread.isMain =
            [NSNumber numberWithBool:[self.machineContextWrapper isMainThread:thread]];
        sentryThread.name = [self getThreadName:thread];

        sentryThread.crashed = @NO;
        bool isCurrent = thread == currentThread;
        sentryThread.current = @(isCurrent);

        if (isCurrent) {
            sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForCurrentThread];
        }

        // We need to make sure the main thread is always the first thread in the result
        if ([self.machineContextWrapper isMainThread:thread])
            [threads insertObject:sentryThread atIndex:0];
        else
            [threads addObject:sentryThread];
    }

    return threads;
}

/**
 * We are not sharing code with 'getCurrentThreads' because both methods use different approaches.
 * This method retrieves thread information from the suspend method
 * while the other retrieves information from the machine context.
 * Having both approaches in the same method can lead to inconsistency between the number of
 * threads, and while there is suspended threads we can't call into obj-c, so the previous approach
 * wont work for retrieving stacktrace information for every thread.
 */
- (NSArray<SentryThread *> *)getCurrentThreadsWithStackTrace
{
    NSMutableArray<SentryThread *> *threads = [NSMutableArray new];

    @synchronized(self) {
        SentryCrashMC_NEW_CONTEXT(context);
        SentryCrashThread currentThread = sentrycrashthread_self();

        thread_act_array_t suspendedThreads = NULL;
        mach_msg_type_number_t numSuspendedThreads = 0;

        bool symbolicate = self.symbolicate;

        // SentryThreadInspector is crashing when there is too many threads.
        // We add a limit of 70 threads because in test with up to 100 threads it seems fine.
        // We are giving it an extra safety margin.
        sentrycrashmc_suspendEnvironment_upToMaxSupportedThreads(
            &suspendedThreads, &numSuspendedThreads, 70);
        // DANGER: Do not try to allocate memory in the heap or call Objective-C code in this
        // section Doing so when the threads are suspended may lead to deadlocks or crashes.

        // If no threads was suspended we don't need to do anything.
        // This may happen if there is more than max amount of threads (70).
        if (numSuspendedThreads == 0) {
            return threads;
        }

        SentryThreadInfo threadsInfos[numSuspendedThreads];

        for (int i = 0; i < numSuspendedThreads; i++) {
            if (suspendedThreads[i] != currentThread) {
                int numberOfEntries = getStackEntriesFromThread(suspendedThreads[i], context,
                    threadsInfos[i].stackEntries, MAX_STACKTRACE_LENGTH, symbolicate);
                threadsInfos[i].stackLength = numberOfEntries;
            } else {
                // We can't use 'getStackEntriesFromThread' to retrieve stack frames from the
                // current thread. We are using the stackTraceBuilder to retrieve this information
                // later.
                threadsInfos[i].stackLength = 0;
            }
            threadsInfos[i].thread = suspendedThreads[i];
        }

        sentrycrashmc_resumeEnvironment(suspendedThreads, numSuspendedThreads);
        // DANGER END: You may call Objective-C code again or allocate memory.

        for (int i = 0; i < numSuspendedThreads; i++) {
            SentryThread *sentryThread = [[SentryThread alloc] initWithThreadId:@(i)];

            sentryThread.isMain = [NSNumber numberWithBool:i == 0];
            sentryThread.name = [self getThreadName:threadsInfos[i].thread];

            sentryThread.crashed = @NO;
            bool isCurrent = threadsInfos[i].thread == currentThread;
            sentryThread.current = @(isCurrent);

            if (isCurrent) {
                sentryThread.stacktrace = [self.stacktraceBuilder buildStacktraceForCurrentThread];
            } else {
                sentryThread.stacktrace = [self.stacktraceBuilder
                    buildStackTraceFromStackEntries:threadsInfos[i].stackEntries
                                             amount:threadsInfos[i].stackLength];
            }

            // We need to make sure the main thread is always the first thread in the result
            if ([self.machineContextWrapper isMainThread:threadsInfos[i].thread])
                [threads insertObject:sentryThread atIndex:0];
            else
                [threads addObject:sentryThread];
        }
    }

    return threads;
}

- (nullable NSString *)getThreadName:(SentryCrashThread)thread
{
    int bufferLength = 128;
    char buffer[bufferLength];
    char *const pBuffer = buffer;

    BOOL didGetThreadNameSucceed = [self.machineContextWrapper getThreadName:thread
                                                                   andBuffer:pBuffer
                                                                andBufLength:bufferLength];

    if (didGetThreadNameSucceed == YES) {
        NSString *threadName = [NSString stringWithCString:pBuffer encoding:NSUTF8StringEncoding];
        if (threadName.length > 0) {
            return threadName;
        }
    }

    return nil;
}

@end
