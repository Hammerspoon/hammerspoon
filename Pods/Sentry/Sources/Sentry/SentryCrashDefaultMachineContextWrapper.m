#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashDynamicLinker.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashMachineContextWrapper.h"
#import "SentryCrashStackCursor.h"
#import "SentryCrashStackCursor_SelfThread.h"
#import "SentryCrashThread.h"
#import "SentryFrame.h"
#import "SentryHexAddressFormatter.h"
#import "SentryStacktrace.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThread.h"
#import <Foundation/Foundation.h>
#include <execinfo.h>
#include <pthread.h>

NS_ASSUME_NONNULL_BEGIN

SentryCrashThread mainThreadID;

@implementation SentryCrashDefaultMachineContextWrapper

+ (void)load
{
    mainThreadID = pthread_mach_thread_np(pthread_self());
}

- (void)fillContextForCurrentThread:(struct SentryCrashMachineContext *)context
{
    sentrycrashmc_getContextForThread(sentrycrashthread_self(), context, true);
}

- (int)getThreadCount:(struct SentryCrashMachineContext *)context
{
    return sentrycrashmc_getThreadCount(context);
}

- (SentryCrashThread)getThread:(struct SentryCrashMachineContext *)context withIndex:(int)index
{
    SentryCrashThread thread = sentrycrashmc_getThreadAtIndex(context, index);
    return thread;
}

- (void)getThreadName:(const SentryCrashThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength;
{
    sentrycrashthread_getThreadName(thread, buffer, bufLength);
}

- (BOOL)isMainThread:(SentryCrashThread)thread
{
    return thread == mainThreadID;
}

@end

NS_ASSUME_NONNULL_END
