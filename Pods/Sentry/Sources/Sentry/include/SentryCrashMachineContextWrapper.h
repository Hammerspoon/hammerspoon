#import "SentryCrashMachineContext.h"
#import "SentryCrashThread.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrashMachineContext for testability.
 */
@protocol SentryCrashMachineContextWrapper <NSObject>

- (void)fillContextForCurrentThread:(struct SentryCrashMachineContext *)context;

- (int)getThreadCount:(struct SentryCrashMachineContext *)context;

- (SentryCrashThread)getThread:(struct SentryCrashMachineContext *)context withIndex:(int)index;

- (void)getThreadName:(const SentryCrashThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength;

@end

NS_ASSUME_NONNULL_END
